import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 활동 로그 서비스
class UserActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 활동 로그 기록
  Future<void> recordActivity({
    required String userId,
    required String userName,
    required String activityType,
    String? details,
  }) async {
    try {
      print('📝 [활동기록] 시작');
      print('  - 사용자 ID: $userId');
      print('  - 사용자 이름: $userName');
      print('  - 활동 타입: $activityType');
      print('  - 상세: $details');
      
      final docRef = await _firestore.collection('user_activities').add({
        'user_id': userId,
        'user_name': userName,
        'activity_type': activityType, // 'login', 'search', 'view_profile', 'edit_profile', etc.
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });
      
      print('✅ [활동기록] 성공! 문서 ID: ${docRef.id}');
      
      // 기록된 내용 바로 확인
      final savedDoc = await docRef.get();
      if (savedDoc.exists) {
        final data = savedDoc.data();
        print('✅ [활동기록] 저장된 데이터 확인:');
        print('  - user_id: ${data?['user_id']}');
        print('  - user_name: ${data?['user_name']}');
        print('  - activity_type: ${data?['activity_type']}');
        print('  - timestamp: ${data?['timestamp']}');
      }
    } catch (e, stackTrace) {
      print('❌ [활동기록] 활동 로그 기록 실패: $e');
      print('❌ [활동기록] 스택 트레이스: $stackTrace');
    }
  }

  /// 최근 활동 가져오기
  Future<List<Map<String, dynamic>>> getRecentActivities({int days = 10, int limit = 50}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      
      final querySnapshot = await _firestore
          .collection('user_activities')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      final activities = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        
        if (timestamp != null) {
          final activityDate = timestamp.toDate();
          
          // 최근 N일 이내 활동만 포함
          if (activityDate.isAfter(cutoffDate)) {
            activities.add({
              'id': doc.id,
              'user_id': data['user_id'] ?? '',
              'user_name': data['user_name'] ?? '알 수 없음',
              'activity_type': data['activity_type'] ?? '',
              'details': data['details'],
              'timestamp': activityDate,
            });
          }
        }
      }
      
      return activities;
    } catch (e) {
      print('활동 로그 조회 실패: $e');
      return [];
    }
  }

  /// 최근 로그인 활동 가져오기 (중복 통합)
  Future<List<Map<String, dynamic>>> getRecentLoginActivities({int days = 10, int limit = 50}) async {
    try {
      print('🔍 [활동조회] 시작: 최근 $days일, 최대 $limit개');
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      print('🔍 [활동조회] 기준 날짜: $cutoffDate');
      
      // 로그인 활동만 조회
      final querySnapshot = await _firestore
          .collection('user_activities')
          .where('activity_type', isEqualTo: 'login')
          .orderBy('timestamp', descending: true)
          .limit(limit * 2) // 중복 고려하여 더 많이 가져오기
          .get();
      
      print('🔍 [활동조회] Firestore 쿼리 결과: ${querySnapshot.docs.length}개 문서');
      
      final activities = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        
        print('  📄 문서 ID: ${doc.id}');
        print('    - 사용자: ${data['user_name']} (${data['user_id']})');
        print('    - 타입: ${data['activity_type']}');
        print('    - 시간: $timestamp');
        
        if (timestamp != null) {
          final activityDate = timestamp.toDate();
          
          // 최근 N일 이내 활동만 포함
          if (activityDate.isAfter(cutoffDate)) {
            activities.add({
              'id': doc.id,
              'user_id': data['user_id'] ?? '',
              'user_name': data['user_name'] ?? '알 수 없음',
              'activity_type': data['activity_type'] ?? '',
              'details': data['details'],
              'timestamp': activityDate,
            });
            print('    ✅ 추가됨 (기준일 이후)');
          } else {
            print('    ❌ 제외됨 (기준일 이전)');
          }
        } else {
          print('    ⚠️ timestamp가 null');
        }
      }
      
      print('🔍 [활동조회] 필터링 후: ${activities.length}개 활동');
      
      // 사용자별로 통합 (가장 최근 활동만 + 횟수 카운트)
      final Map<String, Map<String, dynamic>> consolidatedActivities = {};
      
      for (final activity in activities) {
        final userId = activity['user_id'] as String;
        
        if (consolidatedActivities.containsKey(userId)) {
          // 이미 있는 사용자: 횟수만 증가
          consolidatedActivities[userId]!['count'] = (consolidatedActivities[userId]!['count'] as int) + 1;
        } else {
          // 새 사용자: 추가
          consolidatedActivities[userId] = {
            ...activity,
            'count': 1,
          };
        }
      }
      
      print('🔍 [활동조회] 통합 후: ${consolidatedActivities.length}명');
      
      // Map을 List로 변환하고 최신순 정렬
      final result = consolidatedActivities.values.toList();
      result.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      
      print('🔍 [활동조회] 최종 결과: ${result.length}명');
      
      // limit까지만 반환
      return result.take(limit).toList();
    } catch (e, stackTrace) {
      print('❌ [활동조회] 로그인 활동 로그 조회 실패: $e');
      print('❌ [활동조회] 스택 트레이스: $stackTrace');
      return [];
    }
  }

  /// 활동 타입별 한글 이름
  String getActivityTypeName(String activityType) {
    const typeNames = {
      'login': '로그인',
      'search': '검색',
      'view_profile': '프로필 조회',
      'edit_profile': '프로필 수정',
      'view_alumni': '동문 조회',
      'view_notice': '공지사항 조회',
      'add_alumni': '동문 추가',
    };
    
    return typeNames[activityType] ?? activityType;
  }

  /// 활동 타입별 아이콘
  String getActivityIcon(String activityType) {
    const typeIcons = {
      'login': '🔐',
      'search': '🔍',
      'view_profile': '👤',
      'edit_profile': '✏️',
      'view_alumni': '👥',
      'view_notice': '📢',
      'add_alumni': '➕',
    };
    
    return typeIcons[activityType] ?? '📝';
  }
}
