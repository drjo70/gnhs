import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alumni.dart';
import '../services/alumni_service.dart';
import '../services/auth_manager.dart';
import 'notices_screen.dart';
import 'alumni_search_screen.dart';
import 'class_list_screen.dart';
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
  
  int _totalCount = 0;
  int _totalYears = 0;
  int _visitCount = 0;
  bool _isLoading = true;
  List<Alumni> _recentAlumni = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _recordVisit();
  }

  Future<void> _recordVisit() async {
    try {
      final statsRef = FirebaseFirestore.instance.collection('app_stats').doc('visits');
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(statsRef);
        if (snapshot.exists) {
          final currentCount = snapshot.data()?['count'] ?? 0;
          transaction.update(statsRef, {'count': currentCount + 1});
        } else {
          transaction.set(statsRef, {'count': 1});
        }
      });
    } catch (e) {
      // 접속 기록 실패해도 앱은 정상 작동
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final totalCount = await _alumniService.getTotalAlumniCount();
      final years = await _alumniService.getGraduationYears();
      final recentAlumni = await _loadRecentAlumni();
      final visitCount = await _loadVisitCount();
      
      setState(() {
        _totalCount = totalCount;
        _totalYears = years.length;
        _recentAlumni = recentAlumni;
        _visitCount = visitCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _loadVisitCount() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_stats')
          .doc('visits')
          .get();
      return doc.data()?['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Alumni>> _loadRecentAlumni() async {
    try {
      // Firestore에서 최근 등록된 동문 5명 가져오기
      final querySnapshot = await FirebaseFirestore.instance
          .collection('alumni')
          .orderBy('created_at', descending: true)
          .limit(5)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Alumni.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // created_at 필드가 없는 경우 이름순으로 5명 가져오기
      final querySnapshot = await FirebaseFirestore.instance
          .collection('alumni')
          .limit(5)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Alumni.fromFirestore(doc.data(), doc.id))
          .toList();
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('페이지를 열 수 없습니다')),
        );
      }
    }
  }

  Future<void> _launchWebsite() async {
    final Uri url = Uri.parse('https://www.ganggo.org');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('홈페이지를 열 수 없습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '강릉고 총동문회',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // 관리자 아이콘 (관리자만 표시)
          if (_authManager.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminMenuScreen(),
                  ),
                );
              },
              tooltip: '관리자 메뉴',
              color: Colors.amber,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
                    // 헤더 섹션
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            // 전체 동문 수
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '전체 $_totalCount명',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 메인 메뉴
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '메뉴',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            
                            // 메뉴 3개 한 줄 배치
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMenuCard(
                                    context,
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
                                    context,
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
                                    context,
                                    icon: Icons.language,
                                    title: '홈페이지',
                                    color: Colors.purple,
                                    onTap: _launchWebsite,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 최근 가입 동문
                    if (_recentAlumni.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '최근 가입 동문',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                        ),
                      ),
                      
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final alumni = _recentAlumni[index];
                              return _buildAlumniListItem(alumni);
                            },
                            childCount: _recentAlumni.length,
                          ),
                        ),
                      ),
                    ],

                    // 모임/행사 일정 (Footer 위로 이동)
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
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatItem(
                                            icon: Icons.business,
                                            label: '등록 기업',
                                            value: '2개',
                                            color: Colors.orange,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildStatItem(
                                            icon: Icons.visibility,
                                            label: '총 접속',
                                            value: '$_visitCount회',
                                            color: Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 모임/행사 일정
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '다가오는 행사',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            
                            // 행사 카드
                            _buildEventCard(
                              context,
                              title: '2025 신년 총동문회',
                              date: '2025년 1월 15일 (수)',
                              location: '강릉 파인힐CC',
                              icon: Icons.celebration,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 8),
                            _buildEventCard(
                              context,
                              title: '20회 정기 모임',
                              date: '2024년 12월 20일 (금)',
                              location: '서울 강남역 인근',
                              icon: Icons.groups,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 하단 여백
                    const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddAlumniScreen(),
            ),
          );
          
          // 동문 추가 후 데이터 새로고침
          if (result == true) {
            _loadData();
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('동문 추가'),
        tooltip: '새 동문 추가',
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
            fontSize: 18,
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

  Widget _buildEventCard(
    BuildContext context, {
    required String title,
    required String date,
    required String location,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
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

  Widget _buildCompanyCard(
    BuildContext context, {
    required String companyName,
    required String website,
    required String url,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _launchUrl(url),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.business,
                size: 28,
                color: color,
              ),
              const SizedBox(height: 6),
              Text(
                companyName,
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
                website,
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

  Widget _buildAlumniListItem(Alumni alumni) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: alumni.profilePhotoUrl.isNotEmpty
              ? NetworkImage(alumni.profilePhotoUrl)
              : null,
          child: alumni.profilePhotoUrl.isEmpty
              ? Text(
                  alumni.name.isNotEmpty ? alumni.name[0] : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Text(
              alumni.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                alumni.displayGraduation,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          alumni.company.isNotEmpty 
              ? alumni.company 
              : alumni.jobTitle.isNotEmpty 
                  ? alumni.jobTitle 
                  : '정보 없음',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlumniDetailScreen(alumni: alumni),
            ),
          );
        },
      ),
    );
  }
}
