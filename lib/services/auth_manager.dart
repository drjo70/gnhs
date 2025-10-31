import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// 조건부 import: 웹에서만 dart:html 사용
import 'web_storage_stub.dart'
    if (dart.library.html) 'web_storage_web.dart' as web_storage;

class AuthManager {
  static const String _keyLoggedInPhone = 'logged_in_phone';
  
  // 관리자 전화번호 목록 (정규화된 형태)
  static const List<String> _adminPhones = [
    '01092729081', // 닥터조 관리자
  ];
  
  // 싱글톤 패턴
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();
  
  String? _currentUserPhone;
  
  /// 로그인된 사용자의 전화번호 가져오기
  String? get currentUserPhone => _currentUserPhone;
  
  /// 로그인 여부 확인
  bool get isLoggedIn => _currentUserPhone != null && _currentUserPhone!.isNotEmpty;
  
  /// 관리자 여부 확인
  bool get isAdmin {
    if (!isLoggedIn) return false;
    final normalizedPhone = _currentUserPhone!.replaceAll('-', '').replaceAll(' ', '');
    return _adminPhones.contains(normalizedPhone);
  }
  
  /// 앱 시작 시 저장된 로그인 정보 불러오기
  Future<void> loadLoginState() async {
    try {
      print('🔐 [AuthManager] loadLoginState 시작');
      
      if (kIsWeb) {
        // 웹 환경: localStorage 사용
        print('🌐 [AuthManager] 웹 환경 - localStorage 사용');
        _currentUserPhone = web_storage.WebStorage.getItem(_keyLoggedInPhone);
      } else {
        // 모바일 환경: SharedPreferences 사용
        print('📱 [AuthManager] 모바일 환경 - SharedPreferences 사용');
        final prefs = await SharedPreferences.getInstance();
        _currentUserPhone = prefs.getString(_keyLoggedInPhone);
      }
      
      // 디버깅: 로그인 상태 로드 결과
      print('🔐 [AuthManager] 저장된 전화번호: $_currentUserPhone');
      print('🔐 [AuthManager] 로그인 상태: $isLoggedIn');
    } catch (e, stackTrace) {
      print('❌ [AuthManager] loadLoginState 오류: $e');
      print('❌ [AuthManager] 스택 트레이스: $stackTrace');
      _currentUserPhone = null;
    }
  }
  
  /// 로그인 (전화번호 저장)
  Future<void> login(String phoneNumber) async {
    // 전화번호 정규화 (하이픈, 공백 제거)
    final normalizedPhone = phoneNumber.replaceAll('-', '').replaceAll(' ', '');
    
    if (kIsWeb) {
      // 웹 환경: localStorage 사용
      print('🌐 [AuthManager] 웹 - localStorage에 저장');
      web_storage.WebStorage.setItem(_keyLoggedInPhone, normalizedPhone);
    } else {
      // 모바일 환경: SharedPreferences 사용
      print('📱 [AuthManager] 모바일 - SharedPreferences에 저장');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLoggedInPhone, normalizedPhone);
    }
    
    _currentUserPhone = normalizedPhone;
    
    // 디버깅: 로그인 성공
    print('✅ [AuthManager] 로그인 성공!');
    print('✅ [AuthManager] 저장된 전화번호: $normalizedPhone');
  }
  
  /// 로그아웃
  Future<void> logout() async {
    if (kIsWeb) {
      // 웹 환경: localStorage 사용
      web_storage.WebStorage.removeItem(_keyLoggedInPhone);
    } else {
      // 모바일 환경: SharedPreferences 사용
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLoggedInPhone);
    }
    _currentUserPhone = null;
  }
  
  /// 본인 확인 (동문 정보의 전화번호와 비교)
  bool isOwner(String alumniPhone) {
    if (!isLoggedIn) return false;
    
    // 전화번호 정규화 후 비교
    final normalizedAlumniPhone = alumniPhone.replaceAll('-', '').replaceAll(' ', '');
    final normalizedCurrentPhone = _currentUserPhone!.replaceAll('-', '').replaceAll(' ', '');
    
    return normalizedAlumniPhone == normalizedCurrentPhone;
  }
}
