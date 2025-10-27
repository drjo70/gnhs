import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String? get currentPhoneNumber => currentUser?.phoneNumber;
  
  String? _verificationId;
  int? _resendToken;
  
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      if (kDebugMode) {
        debugPrint('🔐 Auth state changed: ${user?.phoneNumber ?? "로그아웃"}');
      }
      notifyListeners();
    });
  }
  
  /// 전화번호로 인증 코드 발송
  Future<bool> sendVerificationCode({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      // 전화번호 형식 정리 (010-1234-5678 -> +82-10-1234-5678)
      String formattedPhone = phoneNumber.trim();
      if (formattedPhone.startsWith('010')) {
        formattedPhone = '+82${formattedPhone.substring(1)}';
      } else if (!formattedPhone.startsWith('+82')) {
        formattedPhone = '+82$formattedPhone';
      }
      
      if (kDebugMode) {
        debugPrint('📱 전화번호 인증 시작: $formattedPhone');
      }
      
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        
        // 자동 인증 성공 (Android only)
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (kDebugMode) {
            debugPrint('✅ 자동 인증 성공');
          }
          await _auth.signInWithCredential(credential);
        },
        
        // 인증 실패
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) {
            debugPrint('❌ 인증 실패: ${e.message}');
          }
          
          String errorMessage = '인증에 실패했습니다.';
          if (e.code == 'invalid-phone-number') {
            errorMessage = '올바르지 않은 전화번호 형식입니다.';
          } else if (e.code == 'too-many-requests') {
            errorMessage = '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
          }
          onError(errorMessage);
        },
        
        // 인증 코드 발송 완료
        codeSent: (String verificationId, int? resendToken) {
          if (kDebugMode) {
            debugPrint('📨 인증 코드 발송 완료');
          }
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        
        // 자동 인증 타임아웃
        codeAutoRetrievalTimeout: (String verificationId) {
          if (kDebugMode) {
            debugPrint('⏱️ 자동 인증 타임아웃');
          }
          _verificationId = verificationId;
        },
        
        // 재전송 토큰 (옵션)
        forceResendingToken: _resendToken,
      );
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 인증 코드 발송 오류: $e');
      }
      onError('인증 코드 발송에 실패했습니다.');
      return false;
    }
  }
  
  /// OTP 코드로 로그인
  Future<bool> verifyOTP({
    required String verificationId,
    required String otp,
    required Function(String) onError,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔐 OTP 인증 시도: $otp');
      }
      
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      await _auth.signInWithCredential(credential);
      
      if (kDebugMode) {
        debugPrint('✅ 로그인 성공: ${currentUser?.phoneNumber}');
      }
      
      return true;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ OTP 인증 실패: ${e.code} - ${e.message}');
      }
      
      String errorMessage = 'OTP 인증에 실패했습니다.';
      if (e.code == 'invalid-verification-code') {
        errorMessage = '올바르지 않은 인증 코드입니다.';
      } else if (e.code == 'session-expired') {
        errorMessage = '인증 시간이 만료되었습니다. 다시 시도해주세요.';
      }
      onError(errorMessage);
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ OTP 인증 오류: $e');
      }
      onError('인증 중 오류가 발생했습니다.');
      return false;
    }
  }
  
  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (kDebugMode) {
        debugPrint('👋 로그아웃 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 로그아웃 오류: $e');
      }
    }
  }
  
  /// 현재 사용자의 전화번호 가져오기 (형식: 01012345678)
  String? getCurrentPhoneFormatted() {
    final phone = currentUser?.phoneNumber;
    if (phone == null) return null;
    
    // +821012345678 -> 01012345678
    if (phone.startsWith('+82')) {
      return '0${phone.substring(3)}';
    }
    return phone;
  }
}
