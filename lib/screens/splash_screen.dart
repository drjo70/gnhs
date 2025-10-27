import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/auth_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    try {
      print('🚀 [Splash] 시작');
      
      // AuthManager 초기화 및 로그인 상태 확인
      await AuthManager().loadLoginState();
      
      // 디버깅: 로그인 상태 확인
      final isLoggedIn = AuthManager().isLoggedIn;
      final currentPhone = AuthManager().currentUserPhone;
      print('🔍 [Splash] 로그인 상태: $isLoggedIn');
      print('🔍 [Splash] 저장된 전화번호: $currentPhone');
      
      // 스플래시 화면 최소 표시 시간 (1초로 단축)
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        // 로그인 상태에 따라 적절한 화면으로 이동
        final nextScreen = isLoggedIn 
            ? const HomeScreen() 
            : const LoginScreen();
        
        print('🔍 [Splash] 다음 화면: ${nextScreen.runtimeType}');
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      }
    } catch (e, stackTrace) {
      print('❌ [Splash] 오류 발생: $e');
      print('❌ [Splash] 스택 트레이스: $stackTrace');
      
      // 오류 발생 시 로그인 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 학교 로고 (아이콘으로 대체)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.school,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 앱 이름
              const Text(
                '강릉고등학교',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                '총동문회',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // 로딩 인디케이터
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
