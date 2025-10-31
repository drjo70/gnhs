import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/visit_stats_service.dart';
import '../services/user_activity_service.dart';

class VisitStatsScreen extends StatefulWidget {
  const VisitStatsScreen({super.key});

  @override
  State<VisitStatsScreen> createState() => _VisitStatsScreenState();
}

class _VisitStatsScreenState extends State<VisitStatsScreen> {
  final VisitStatsService _statsService = VisitStatsService();
  final UserActivityService _activityService = UserActivityService();
  
  bool _isLoading = true;
  int _todayVisits = 0;
  int _weekVisits = 0;
  int _monthVisits = 0;
  int _totalVisits = 0;
  List<Map<String, dynamic>> _recentStats = [];
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      // 전체 통계 가져오기
      final stats = await _statsService.getAllStats();
      
      // 최근 30일 상세 통계 가져오기 (그래프용)
      final recentStats = await _getRecentStats(30);
      
      // 최근 10일간 접속한 동문 가져오기 (중복 제거)
      final recentActivities = await _statsService.getRecentVisitors(days: 10);
      
      setState(() {
        _todayVisits = stats['today'] ?? 0;
        _weekVisits = stats['week'] ?? 0;
        _monthVisits = stats['month'] ?? 0;
        _totalVisits = stats['total'] ?? 0;
        _recentStats = recentStats;
        _recentActivities = recentActivities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('통계를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentStats(int days) async {
    try {
      final now = DateTime.now();
      final stats = <Map<String, dynamic>>[];
      
      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        final doc = await FirebaseFirestore.instance
            .collection('visit_stats')
            .doc(dateKey)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          stats.add({
            'date': dateKey,
            'count': data['count'] ?? 0,
            'displayDate': '${date.month}/${date.day}',
            'fullDisplayDate': '${date.month}월 ${date.day}일',
            'weekday': _getWeekdayString(date.weekday),
            'dayIndex': days - 1 - i,
          });
        } else {
          stats.add({
            'date': dateKey,
            'count': 0,
            'displayDate': '${date.month}/${date.day}',
            'fullDisplayDate': '${date.month}월 ${date.day}일',
            'weekday': _getWeekdayString(date.weekday),
            'dayIndex': days - 1 - i,
          });
        }
      }
      
      return stats;
    } catch (e) {
      return [];
    }
  }

  String _getWeekdayString(int weekday) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[weekday - 1];
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM/dd HH:mm').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('접속 통계'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 요약 통계 카드
                      _buildSummaryCards(),
                      
                      const SizedBox(height: 24),
                      
                      // 그래프
                      const Text(
                        '최근 30일 접속 추이',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildChart(),
                      
                      const SizedBox(height: 24),
                      
                      // 최근 활동 동문
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '최근 로그인 동문 (10일간)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '총 ${_recentActivities.length}명',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 활동 리스트
                      if (_recentActivities.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '최근 활동 기록이 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ..._recentActivities.map((activity) => _buildActivityItem(activity)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: '오늘',
                count: _todayVisits,
                icon: Icons.today,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: '이번 주',
                count: _weekVisits,
                icon: Icons.date_range,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: '이번 달',
                count: _monthVisits,
                icon: Icons.calendar_month,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: '전체',
                count: _totalVisits,
                icon: Icons.analytics,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              '$count회',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_recentStats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Text('데이터가 없습니다'),
          ),
        ),
      );
    }

    final maxCount = _recentStats.fold<int>(0, (max, item) {
      final count = item['count'] as int;
      return count > max ? count : max;
    });

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxCount > 0 ? (maxCount / 5).ceilToDouble() : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300]!,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 5,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= _recentStats.length) {
                        return const Text('');
                      }
                      if (index % 5 != 0) {
                        return const Text('');
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _recentStats[index]['displayDate'],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxCount > 0 ? (maxCount / 5).ceilToDouble() : 1,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey[300]!),
              ),
              minX: 0,
              maxX: (_recentStats.length - 1).toDouble(),
              minY: 0,
              maxY: maxCount > 0 ? (maxCount * 1.2).ceilToDouble() : 10,
              lineBarsData: [
                LineChartBarData(
                  spots: _recentStats.map((stat) {
                    return FlSpot(
                      (stat['dayIndex'] as int).toDouble(),
                      (stat['count'] as int).toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Theme.of(context).colorScheme.primary,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      final index = barSpot.x.toInt();
                      if (index < 0 || index >= _recentStats.length) {
                        return null;
                      }
                      final stat = _recentStats[index];
                      return LineTooltipItem(
                        '${stat['fullDisplayDate']}\n${stat['count']}회',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final userName = activity['user_name'] as String;
    final timestamp = activity['timestamp'] as DateTime;
    final visitCount = activity['visit_count'] as int? ?? 1;
    final classNumber = activity['class_number'] as int?;
    
    print('📋 [접속자표시] $userName - 기수: $classNumber, 접속: $visitCount회');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              '🔐',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                classNumber != null ? '$userName($classNumber)' : userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '접속',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${visitCount}회',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
