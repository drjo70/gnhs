import 'package:cloud_firestore/cloud_firestore.dart';

class AlumniService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 모든 기수 목록 가져오기 (1회부터 정렬)
  Future<List<int>> getGraduationYears() async {
    try {
      final snapshot = await _firestore.collection('alumni').get();
      
      final years = <int>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final year = data['graduation_year'] as int?;
        // 유효한 회차만 포함 (0, null 등 제외)
        if (year != null && year > 0) {
          years.add(year);
        }
      }
      
      // 오름차순 정렬 (1회, 2회, 3회 순서)
      final sortedYears = years.toList()..sort((a, b) => a.compareTo(b));
      return sortedYears;
    } catch (e) {
      return [];
    }
  }

  /// 기수별 동문 수 가져오기
  Future<Map<int, int>> getAlumniCountByYear() async {
    try {
      final snapshot = await _firestore.collection('alumni').get();
      
      final countMap = <int, int>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final year = data['graduation_year'] as int?;
        // 유효한 회차만 포함 (0, null 등 제외)
        if (year != null && year > 0) {
          countMap[year] = (countMap[year] ?? 0) + 1;
        }
      }
      
      return countMap;
    } catch (e) {
      return {};
    }
  }

  /// 전체 동문 수 가져오기 (유효한 회차만)
  Future<int> getTotalAlumniCount() async {
    try {
      final snapshot = await _firestore.collection('alumni').get();
      
      int validCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final year = data['graduation_year'] as int?;
        // 유효한 회차만 카운트 (0, null 등 제외)
        if (year != null && year > 0) {
          validCount++;
        }
      }
      
      return validCount;
    } catch (e) {
      return 0;
    }
  }

  /// 특정 기수의 동문 수 가져오기
  Future<int> getAlumniCountForYear(int year) async {
    try {
      final snapshot = await _firestore
          .collection('alumni')
          .where('graduation_year', isEqualTo: year)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
