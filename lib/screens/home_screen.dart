import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alumni.dart';
import '../services/alumni_service.dart';
import '../services/auth_manager.dart';
import '../services/visit_stats_service.dart';
import 'class_list_screen.dart';
import 'alumni_search_screen.dart';
import 'add_alumni_screen.dart';
import 'admin_menu_screen.dart';
import 'alumni_detail_screen.dart';

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
    await _visitStatsService.recordVisit();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 병렬 처리로 속도 개선
      final results = await Future.wait([
        _alumniService.getGraduationYears(),
        _alumniService.getTotalAlumniCount(),
        // updated_at 필드로 정렬 (최근 업데이트 순) - 10명으로 증가
        FirebaseFirestore.instance
            .collection('alumni')
            .orderBy('updated_at', descending: true)
            .limit(10)
            .get(),
        _visitStatsService.getAllStats(),
      ]);
      
      final years = results[0] as List<int>;
      final totalCount = results[1] as int;
      final snapshot = results[2] as QuerySnapshot;
      final visitStats = results[3] as Map<String, int>;
      
      final recentAlumni = snapshot.docs
          .map((doc) => Alumni.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      setState(() {
        _totalYears = years.length;
        _totalCount = totalCount;
        _recentAlumni = recentAlumni;
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
                    // 헤더
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            '전체 $_totalCount명',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 메뉴
                    const Text(
                      '메뉴',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
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
                                      radius: 16,
                                      backgroundImage: alumni.profilePhotoUrl.isNotEmpty
                                          ? NetworkImage(alumni.profilePhotoUrl)
                                          : null,
                                      child: alumni.profilePhotoUrl.isEmpty
                                          ? Text(
                                              alumni.name.isNotEmpty ? alumni.name[0] : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
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
