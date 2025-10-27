import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_manager.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  final AuthManager _authManager = AuthManager();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  ConfirmationResult? _webConfirmationResult; // 웹 환경용

  @override
  void initState() {
    super.initState();
    // 웹 환경에서 reCAPTCHA 설정
    if (kIsWeb) {
      _setupRecaptcha();
    }
  }

  // 웹용 reCAPTCHA 초기화
  void _setupRecaptcha() {
    try {
      _auth.setSettings(appVerificationDisabledForTesting: false);
      print('✅ reCAPTCHA 설정 완료');
    } catch (e) {
      print('⚠️ reCAPTCHA 설정 오류: $e');
    }
  }

  // SMS 인증번호 발송
  Future<void> _sendVerificationCode() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호를 입력해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firestore에서 해당 전화번호가 등록되어 있는지 먼저 확인
      final normalizedPhone = phone.replaceAll('-', '').replaceAll(' ', '');
      
      final doc = await FirebaseFirestore.instance
          .collection('alumni')
          .doc(normalizedPhone)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('등록되지 않은 전화번호입니다.\n동문회에 등록 후 이용해주세요.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 한국 전화번호 형식으로 변환 (+82)
      String formattedPhone = normalizedPhone;
      if (formattedPhone.startsWith('010')) {
        formattedPhone = '+82${formattedPhone.substring(1)}';
      } else if (!formattedPhone.startsWith('+82')) {
        formattedPhone = '+82$formattedPhone';
      }

      print('📞 전화번호: $formattedPhone');
      print('🌐 플랫폼: ${kIsWeb ? "Web" : "Mobile"}');

      // Firebase Phone Authentication (플랫폼별 처리)
      if (kIsWeb) {
        // 웹 환경: ConfirmationResult 사용
        print('🌐 웹 환경 - reCAPTCHA 사용');
        
        final confirmationResult = await _auth.signInWithPhoneNumber(
          formattedPhone,
          // RecaptchaVerifier는 자동으로 생성됨
        );
        
        print('✅ 웹 - ConfirmationResult 받음');
        
        if (mounted) {
          setState(() {
            _verificationId = 'web_verification'; // 웹에서는 confirmationResult 저장
            _codeSent = true;
            _isLoading = false;
          });
          
          // confirmationResult를 나중에 사용하기 위해 저장
          _webConfirmationResult = confirmationResult;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📱 인증번호가 발송되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 모바일 환경: verifyPhoneNumber 사용
        print('📱 모바일 환경 - SMS 직접 발송');
        
        await _auth.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // 자동 인증 완료 (Android only)
            await _signInWithCredential(credential, normalizedPhone);
          },
          verificationFailed: (FirebaseAuthException e) {
            print('❌ 인증 실패: ${e.code} - ${e.message}');
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('인증번호 발송 실패: ${e.message}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            print('✅ 인증번호 발송됨: $verificationId');
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _codeSent = true;
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📱 인증번호가 발송되었습니다!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            print('⏱️ 자동 인증 시간 초과: $verificationId');
            _verificationId = verificationId;
          },
          timeout: const Duration(seconds: 60),
        );
      }
    } catch (e) {
      print('❌ SMS 발송 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // 인증번호 확인 및 로그인
  Future<void> _verifyCode() async {
    final code = _smsCodeController.text.trim();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증번호를 입력해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 전화번호 정규화
      final normalizedPhone = _phoneController.text.trim().replaceAll('-', '').replaceAll(' ', '');
      
      if (kIsWeb) {
        // 웹 환경: ConfirmationResult 사용
        print('🌐 웹 - 인증번호 확인: $code');
        
        if (_webConfirmationResult == null) {
          throw Exception('먼저 인증번호를 발송해주세요');
        }
        
        final userCredential = await _webConfirmationResult!.confirm(code);
        print('✅ 웹 - 인증 성공!');
        
        // AuthManager에 로그인 상태 저장
        await _authManager.login(normalizedPhone);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 로그인 성공!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
          
          // 홈 화면으로 이동
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
      } else {
        // 모바일 환경: PhoneAuthCredential 사용
        print('📱 모바일 - 인증번호 확인: $code');
        
        if (_verificationId == null) {
          throw Exception('먼저 인증번호를 발송해주세요');
        }
        
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );

        // Firebase 인증 및 로그인
        await _signInWithCredential(credential, normalizedPhone);
      }
    } catch (e) {
      print('❌ 인증번호 확인 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('인증번호가 올바르지 않습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Firebase 인증 완료 후 로그인 처리
  Future<void> _signInWithCredential(PhoneAuthCredential credential, String normalizedPhone) async {
    try {
      // Firebase Authentication
      await _auth.signInWithCredential(credential);
      
      // AuthManager에 로그인 상태 저장
      await _authManager.login(normalizedPhone);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 로그인 성공!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        
        // 홈 화면으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      print('❌ Firebase 로그인 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고/아이콘
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 32),

                // 타이틀
                const Text(
                  '강릉고 총동문회',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '본인 전화번호로 로그인',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 48),

                // 전화번호 입력
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: '전화번호',
                    hintText: '010-1234-5678',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading && !_codeSent,
                ),

                const SizedBox(height: 16),

                // 인증번호 발송 버튼
                if (!_codeSent)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendVerificationCode,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '인증번호 발송',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                // 인증번호 입력 (발송 후)
                if (_codeSent) ...[
                  TextField(
                    controller: _smsCodeController,
                    decoration: InputDecoration(
                      labelText: '인증번호',
                      hintText: '6자리 숫자',
                      prefixIcon: const Icon(Icons.sms),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _verifyCode(),
                  ),

                  const SizedBox(height: 16),

                  // 인증번호 확인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '인증하고 로그인',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 재전송 버튼
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _codeSent = false;
                        _smsCodeController.clear();
                      });
                    },
                    child: const Text('인증번호 재발송'),
                  ),
                ],

                const SizedBox(height: 16),

                // 안내 메시지
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _codeSent
                              ? '📱 문자로 받은 6자리 인증번호를\n입력해주세요.'
                              : '📱 등록된 전화번호로 인증번호를\n발송합니다. (본인 인증)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[900],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 회원가입 안내
                Text(
                  '등록되지 않은 동문이신가요?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '동문회에 문의하여 등록 후 이용해주세요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }
}
