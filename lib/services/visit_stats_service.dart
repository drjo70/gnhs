import 'package:cloud_firestore/cloud_firestore.dart';

/// 접속 통계 관리 서비스
class VisitStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 접속 기록 추가 (사용자 정보 포함)
  Future<void> recordVisit({String? userId, String? userName}) async {
    try {
      final now = DateTime.now();
      
      // 오늘 날짜 (YYYY-MM-DD 형식)
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      // visit_stats 컬렉션에 날짜별 문서 생성/업데이트
      final docRef = _firestore.collection('visit_stats').doc(dateKey);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        
        if (snapshot.exists) {
          // 기존 문서가 있으면 카운트 증가
          final currentCount = snapshot.data()?['count'] ?? 0;
          final visitedUsers = List<Map<String, dynamic>>.from(snapshot.data()?['visited_users'] ?? []);
          
          // 사용자 정보가 있으면 visited_users에 추가 (중복 제거 안 함!)
          if (userId != null && userName != null) {
            // 최신 접속 정보를 맨 앞에 추가 (기존 기록 유지)
            visitedUsers.insert(0, {
              'user_id': userId,
              'user_name': userName,
              'timestamp': now,
            });
          }
          
          transaction.update(docRef, {
            'count': currentCount + 1,
            'last_visit': FieldValue.serverTimestamp(),
            'visited_users': visitedUsers,
          });
        } else {
          // 새 문서 생성
          final visitedUsers = <Map<String, dynamic>>[];
          if (userId != null && userName != null) {
            visitedUsers.add({
              'user_id': userId,
              'user_name': userName,
              'timestamp': now,
            });
          }
          
          transaction.set(docRef, {
            'date': dateKey,
            'count': 1,
            'created_at': FieldValue.serverTimestamp(),
            'last_visit': FieldValue.serverTimestamp(),
            'visited_users': visitedUsers,
          });
        }
      });
    } catch (e) {
      // 접속 기록 실패는 무시 (앱 동작에 영향 없음)
      print('접속 기록 실패: $e');
    }
  }

  /// 오늘 접속자 수 가져오기
  Future<int> getTodayVisits() async {
    try {
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final doc = await _firestore.collection('visit_stats').doc(dateKey).get();
      
      if (doc.exists) {
        return doc.data()?['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 이번 주 접속자 수 가져오기
  Future<int> getWeekVisits() async {
    try {
      final now = DateTime.now();
      
      // 이번 주 월요일 날짜 계산
      final weekday = now.weekday; // 1(월) ~ 7(일)
      final monday = now.subtract(Duration(days: weekday - 1));
      
      // 월요일부터 오늘까지의 날짜 목록 생성
      final dates = <String>[];
      for (int i = 0; i <= now.difference(monday).inDays; i++) {
        final date = monday.add(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dates.add(dateKey);
      }
      
      // 각 날짜의 접속자 수 합산
      int totalVisits = 0;
      for (final dateKey in dates) {
        final doc = await _firestore.collection('visit_stats').doc(dateKey).get();
        if (doc.exists) {
          totalVisits += (doc.data()?['count'] ?? 0) as int;
        }
      }
      
      return totalVisits;
    } catch (e) {
      return 0;
    }
  }

  /// 이번 달 접속자 수 가져오기
  Future<int> getMonthVisits() async {
    try {
      final now = DateTime.now();
      
      // 이번 달 1일부터 오늘까지의 날짜 목록 생성
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final dates = <String>[];
      
      for (int day = 1; day <= now.day; day++) {
        final date = DateTime(now.year, now.month, day);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dates.add(dateKey);
      }
      
      // 각 날짜의 접속자 수 합산
      int totalVisits = 0;
      for (final dateKey in dates) {
        final doc = await _firestore.collection('visit_stats').doc(dateKey).get();
        if (doc.exists) {
          totalVisits += (doc.data()?['count'] ?? 0) as int;
        }
      }
      
      return totalVisits;
    } catch (e) {
      return 0;
    }
  }

  /// 전체 접속자 수 가져오기
  Future<int> getTotalVisits() async {
    try {
      final querySnapshot = await _firestore.collection('visit_stats').get();
      
      int totalVisits = 0;
      for (final doc in querySnapshot.docs) {
        totalVisits += (doc.data()['count'] ?? 0) as int;
      }
      
      return totalVisits;
    } catch (e) {
      return 0;
    }
  }

  /// 전체 통계 한 번에 가져오기 (효율적)
  Future<Map<String, int>> getAllStats() async {
    try {
      final todayVisits = await getTodayVisits();
      final weekVisits = await getWeekVisits();
      final monthVisits = await getMonthVisits();
      final totalVisits = await getTotalVisits();
      
      return {
        'today': todayVisits,
        'week': weekVisits,
        'month': monthVisits,
        'total': totalVisits,
      };
    } catch (e) {
      return {
        'today': 0,
        'week': 0,
        'month': 0,
        'total': 0,
      };
    }
  }

  /// 최근 N일간 접속한 동문 목록 가져오기 (접속 횟수 포함)
  Future<List<Map<String, dynamic>>> getRecentVisitors({int days = 10}) async {
    try {
      final now = DateTime.now();
      final userMap = <String, Map<String, dynamic>>{}; // user_id를 키로 사용
      
      print('🔍 [최근접속자] 최근 $days일간 접속자 조회 시작');
      
      // 최근 N일간의 날짜 목록 생성
      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        final doc = await _firestore.collection('visit_stats').doc(dateKey).get();
        
        if (doc.exists) {
          final data = doc.data();
          final visitedUsers = data?['visited_users'] as List<dynamic>?;
          
          print('📅 [최근접속자] $dateKey: ${visitedUsers?.length ?? 0}명');
          
          if (visitedUsers != null) {
            for (final user in visitedUsers) {
              final userId = user['user_id'] as String?;
              final userName = user['user_name'] as String?;
              final timestamp = user['timestamp'];
              
              if (userId != null && userName != null) {
                if (!userMap.containsKey(userId)) {
                  // 새 사용자 추가
                  userMap[userId] = {
                    'user_id': userId,
                    'user_name': userName,
                    'timestamp': timestamp is Timestamp ? timestamp.toDate() : timestamp,
                    'visit_count': 1, // 접속 횟수 초기화
                  };
                } else {
                  // 기존 사용자: 횟수 증가 및 최신 시간 업데이트
                  final existingUser = userMap[userId]!;
                  existingUser['visit_count'] = (existingUser['visit_count'] as int) + 1;
                  
                  // 더 최근 접속이면 timestamp 업데이트
                  if (timestamp != null && existingUser['timestamp'] != null) {
                    final existingTime = existingUser['timestamp'] as DateTime;
                    final newTime = timestamp is Timestamp ? timestamp.toDate() : timestamp as DateTime;
                    if (newTime.isAfter(existingTime)) {
                      existingUser['timestamp'] = newTime;
                    }
                  }
                }
              }
            }
          }
        }
      }
      
      // 각 사용자의 기수 정보 가져오기
      print('🔍 [최근접속자] 기수 정보 조회 시작... 총 ${userMap.length}명');
      for (final userId in userMap.keys) {
        try {
          print('  📱 [기수조회] userId: $userId');
          final alumniDoc = await _firestore.collection('alumni').doc(userId).get();
          print('  📄 [기수조회] 문서 존재: ${alumniDoc.exists}');
          
          if (alumniDoc.exists) {
            final alumniData = alumniDoc.data();
            
            // class_number 필드가 이미 존재함 (기수 정보)
            final classNumber = alumniData?['class_number'] as int?;
            print('  🎓 [기수조회] class_number: $classNumber');
            
            if (classNumber != null) {
              userMap[userId]!['class_number'] = classNumber;
              print('  ✅ [기수조회] ${userMap[userId]!['user_name']} - 기수: $classNumber');
            } else {
              print('  ⚠️ [기수조회] class_number가 null');
            }
          } else {
            print('  ⚠️ [기수조회] alumni 문서 없음');
          }
        } catch (e) {
          print('⚠️ [최근접속자] $userId 기수 정보 조회 실패: $e');
        }
      }
      
      // Map을 List로 변환하고 최신순 정렬
      final result = userMap.values.toList();
      result.sort((a, b) {
        final aTime = a['timestamp'] as DateTime?;
        final bTime = b['timestamp'] as DateTime?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      
      print('✅ [최근접속자] 총 ${result.length}명 발견');
      for (final user in result.take(5)) {
        print('  - ${user['user_name']} (${user['class_number'] ?? '?'}회): 접속 ${user['visit_count']}회');
      }
      
      return result;
    } catch (e) {
      print('❌ [최근접속자] 조회 실패: $e');
      return [];
    }
  }
}
