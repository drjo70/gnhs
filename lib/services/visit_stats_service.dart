import 'package:cloud_firestore/cloud_firestore.dart';

/// 접속 통계 관리 서비스
class VisitStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 접속 기록 추가
  Future<void> recordVisit() async {
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
          transaction.update(docRef, {
            'count': currentCount + 1,
            'last_visit': FieldValue.serverTimestamp(),
          });
        } else {
          // 새 문서 생성
          transaction.set(docRef, {
            'date': dateKey,
            'count': 1,
            'created_at': FieldValue.serverTimestamp(),
            'last_visit': FieldValue.serverTimestamp(),
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

  /// 전체 통계 한 번에 가져오기 (효율적)
  Future<Map<String, int>> getAllStats() async {
    try {
      final todayVisits = await getTodayVisits();
      final weekVisits = await getWeekVisits();
      final monthVisits = await getMonthVisits();
      
      return {
        'today': todayVisits,
        'week': weekVisits,
        'month': monthVisits,
      };
    } catch (e) {
      return {
        'today': 0,
        'week': 0,
        'month': 0,
      };
    }
  }
}
