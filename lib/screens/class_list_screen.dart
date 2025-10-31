import 'package:flutter/material.dart';
import '../services/alumni_service.dart';
import '../services/auth_manager.dart';
import 'class_alumni_list_screen.dart';
import 'admin_menu_screen.dart';

/// 회별 동문 화면 - 기수별 그리드 표시
class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  final AlumniService _alumniService = AlumniService();
  final AuthManager _authManager = AuthManager();
  
  List<int> _years = [];
  Map<int, int> _countMap = {};
  int _totalCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final years = await _alumniService.getGraduationYears();
      final countMap = await _alumniService.getAlumniCountByYear();
      final totalCount = await _alumniService.getTotalAlumniCount();
      
      setState(() {
        _years = years;
        _countMap = countMap;
        _totalCount = totalCount;
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

  String _getDisplayText(int classNumber) {
    return '$classNumber회';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            // 홈으로 돌아가기
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text(
            '강릉고 동문 주소록',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '새로고침',
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
                        padding: const EdgeInsets.all(16),
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
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.people,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '전체 $_totalCount명',
                                    style: const TextStyle(
                                      fontSize: 16,
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

                    // 기수 목록 섹션
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          '기수별 동문',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),

                    // 기수 그리드
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.0,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final year = _years[index];
                            final count = _countMap[year] ?? 0;
                            final displayText = _getDisplayText(year);
                            
                            return _ClassCard(
                              classText: displayText,
                              count: count,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClassAlumniListScreen(
                                      graduationYear: year,
                                      classText: displayText,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: _years.length,
                        ),
                      ),
                    ),

                    // 하단 여백
                    const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String classText;
  final int count;
  final VoidCallback onTap;

  const _ClassCard({
    required this.classText,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                classText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count명',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
