import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alumni.dart';
import '../models/notice.dart';
import '../services/alumni_service.dart';
import '../services/auth_manager.dart';
import '../services/visit_stats_service.dart';
import 'class_list_screen.dart';
import 'alumni_search_screen.dart';
import 'add_alumni_screen.dart';
import 'admin_menu_screen.dart';
import 'alumni_detail_screen.dart';
import 'notices_screen.dart';
import 'splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AlumniService _alumniService = AlumniService();
  final AuthManager _authManager = AuthManager();
  final VisitStatsService _visitStatsService = VisitStatsService();
  
  int _totalCount = 0;
  int _totalYears = 0;
  bool _isLoading = true;
  List<Alumni> _recentAlumni = [];
  List<Notice> _recentNotices = [];
  
  // 접속 통계
  int _todayVisits = 0;
  int _weekVisits = 0;
  int _monthVisits = 0;

  @override
  void initState() {
    super.initState();
    _recordVisit();
    _loadData();
  }

  Future<void> _recordVisit() async {
    // 현재 로그인한 사용자 정보 가져오기
    final currentPhone = _authManager.currentUserPhone;
    
    if (currentPhone != null) {
      try {
        // Firestore에서 사용자 이름 조회
        final doc = await FirebaseFirestore.instance
            .collection('alumni')
            .doc(currentPhone)
            .get();
        
        if (doc.exists) {
          final userName = doc.data()?['name'] ?? '알 수 없음';
          await _visitStatsService.recordVisit(
            userId: currentPhone,
            userName: userName,
          );
        } else {
          await _visitStatsService.recordVisit();
        }
      } catch (e) {
        await _visitStatsService.recordVisit();
      }
    } else {
      await _visitStatsService.recordVisit();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 병렬 처리로 속도 개선
      final results = await Future.wait([
        _alumniService.getGraduationYears(),
        _alumniService.getTotalAlumniCount(),
        // updated_at 필드로 정렬 (최근 업데이트 순) - 6명으로 변경
        FirebaseFirestore.instance
            .collection('alumni')
            .orderBy('updated_at', descending: true)
            .limit(6)
            .get(),
        _visitStatsService.getAllStats(),
        // 최근 공지사항 3개 가져오기 (활성화된 것만)
        FirebaseFirestore.instance
            .collection('notices')
            .where('is_active', isEqualTo: true)
            .get(),
      ]);
      
      final years = results[0] as List<int>;
      final totalCount = results[1] as int;
      final alumniSnapshot = results[2] as QuerySnapshot;
      final visitStats = results[3] as Map<String, int>;
      final noticeSnapshot = results[4] as QuerySnapshot;
      
      final recentAlumni = alumniSnapshot.docs
          .map((doc) => Alumni.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // 공지사항을 메모리에서 정렬하고 최근 3개만 선택
      final allNotices = noticeSnapshot.docs
          .map((doc) => Notice.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      allNotices.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 최신순
      final recentNotices = allNotices.take(3).toList();
      
      setState(() {
        _totalYears = years.length;
        _totalCount = totalCount;
        _recentAlumni = recentAlumni;
        _recentNotices = recentNotices;
        _todayVisits = visitStats['today'] ?? 0;
        _weekVisits = visitStats['week'] ?? 0;
        _monthVisits = visitStats['month'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _launchWebsite() async {
    final Uri url = Uri.parse('https://www.ganggo.org');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _handleLogout() async {
    // 로그아웃 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 로그아웃 처리
      await _authManager.logout();
      
      if (mounted) {
        // 로그인 화면으로 이동
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            // 이미 홈 화면이므로 아무것도 안 함
          },
          child: const Text(
            '강릉고 동문 주소록',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_authManager.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminMenuScreen(),
                  ),
                );
              },
              tooltip: '관리자 메뉴',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('로그아웃'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 메뉴
                    Row(
                      children: [
                        Expanded(
                          child: _buildMenuCard(
                            icon: Icons.search,
                            title: '동문 검색',
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AlumniSearchScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuCard(
                            icon: Icons.groups,
                            title: '회별 동문',
                            color: Colors.green,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ClassListScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuCard(
                            icon: Icons.language,
                            title: '홈페이지',
                            color: Colors.purple,
                            onTap: _launchWebsite,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMenuCard(
                            icon: Icons.person_add,
                            title: '동문추가',
                            color: Colors.orange,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AddAlumniScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 공지사항
                    Card(
                      color: Colors.blue[50],
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NoticesScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.notifications_active, color: Colors.blue[700], size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '공지사항',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.blue[700], size: 20),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_recentNotices.isEmpty)
                                Text(
                                  '등록된 공지사항이 없습니다',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                )
                              else
                                ..._recentNotices.asMap().entries.map((entry) {
                                  return Column(
                                    children: [
                                      if (entry.key > 0) const SizedBox(height: 8),
                                      _buildNoticeItem(entry.value.title),
                                    ],
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 최근 업데이트 동문
                    if (_recentAlumni.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '최근 업데이트 동문',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AlumniSearchScreen(),
                                ),
                              );
                            },
                            child: const Text('전체보기'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 2열 그리드 레이아웃 (세로 폭 대폭 축소)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _recentAlumni.length,
                        itemBuilder: (context, index) {
                          final alumni = _recentAlumni[index];
                          return Card(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AlumniDetailScreen(alumni: alumni),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      radius: 28,
                                      backgroundImage: alumni.profilePhotoUrl.isNotEmpty
                                          ? NetworkImage(alumni.profilePhotoUrl)
                                          : null,
                                      child: alumni.profilePhotoUrl.isEmpty
                                          ? Text(
                                              alumni.name.isNotEmpty ? alumni.name[0] : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            alumni.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${alumni.graduationYear}회${alumni.company.isNotEmpty ? " • ${alumni.company}" : ""}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // 동문회 현황 통계
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '동문회 현황',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.people,
                                    label: '전체 동문',
                                    value: '$_totalCount명',
                                    color: Colors.blue,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.school,
                                    label: '기수',
                                    value: '$_totalYears개',
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 접속 통계
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '접속 통계',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.today,
                                    label: '오늘',
                                    value: '$_todayVisits',
                                    color: Colors.orange,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.date_range,
                                    label: '이번주',
                                    value: '$_weekVisits',
                                    color: Colors.purple,
                                  ),
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.calendar_month,
                                    label: '이번달',
                                    value: '$_monthVisits',
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 동문 업체 섹션
                    const Text(
                      '동문 업체',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    // 3칸 그리드 레이아웃
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompanyCard(
                            name: '(주)조유',
                            url: 'www.jou.kr',
                            icon: Icons.business,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompanyCard(
                            name: '오달동이',
                            url: 'www.ohdal.kr',
                            icon: Icons.restaurant,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            child: Container(
                              height: 120,
                              padding: const EdgeInsets.all(12),
                              child: Center(
                                child: Text(
                                  '광고 문의',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•',
          style: TextStyle(
            fontSize: 14,
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyCard({
    required String name,
    required String url,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        onTap: () async {
          final Uri fullUrl = Uri.parse('https://$url');
          if (await canLaunchUrl(fullUrl)) {
            await launchUrl(fullUrl);
          }
        },
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                url,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
