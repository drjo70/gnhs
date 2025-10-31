import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alumni.dart';
import '../services/alumni_service.dart';
import 'alumni_detail_screen.dart';

class AlumniListScreen extends StatefulWidget {
  const AlumniListScreen({super.key});

  @override
  State<AlumniListScreen> createState() => _AlumniListScreenState();
}

class _AlumniListScreenState extends State<AlumniListScreen> {
  final AlumniService _alumniService = AlumniService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Alumni> _allAlumni = [];
  List<Alumni> _filteredAlumni = [];
  bool _isLoading = true;
  int? _selectedYear;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadAlumni();
    _loadGraduationYears();
  }

  Future<void> _loadAlumni() async {
    setState(() => _isLoading = true);
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('alumni')
          .get();
      
      final alumni = querySnapshot.docs
          .map((doc) => Alumni.fromFirestore(doc.data(), doc.id))
          .toList();
      
      // 이름순으로 정렬
      alumni.sort((a, b) => a.name.compareTo(b.name));
      
      setState(() {
        _allAlumni = alumni;
        _filteredAlumni = alumni;
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

  Future<void> _loadGraduationYears() async {
    final years = await _alumniService.getGraduationYears();
    setState(() => _availableYears = years);
  }

  void _filterAlumni(String query) {
    setState(() {
      if (query.isEmpty && _selectedYear == null) {
        _filteredAlumni = _allAlumni;
      } else {
        _filteredAlumni = _allAlumni.where((alumni) {
          // 통합 검색: 모든 필드에서 검색
          final matchesSearch = query.isEmpty || 
              alumni.name.toLowerCase().contains(query.toLowerCase()) ||
              alumni.company.toLowerCase().contains(query.toLowerCase()) ||
              alumni.jobTitle.toLowerCase().contains(query.toLowerCase()) ||
              alumni.department.toLowerCase().contains(query.toLowerCase()) ||
              alumni.address.toLowerCase().contains(query.toLowerCase()) ||
              alumni.address2.toLowerCase().contains(query.toLowerCase()) ||
              alumni.email.toLowerCase().contains(query.toLowerCase()) ||
              alumni.notes.toLowerCase().contains(query.toLowerCase()) ||
              alumni.phone.contains(query) ||
              alumni.phone2.contains(query);
          
          final matchesYear = _selectedYear == null || 
              alumni.graduationYear == _selectedYear;
          return matchesSearch && matchesYear;
        }).toList();
      }
    });
  }

  void _showYearFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기수 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('전체'),
                onTap: () {
                  setState(() => _selectedYear = null);
                  _filterAlumni(_searchController.text);
                  Navigator.pop(context);
                },
                selected: _selectedYear == null,
              ),
              ..._availableYears.map((year) {
                // graduation_year를 회차로 변환
                String displayText;
                if (year >= 2000) {
                  displayText = '${year - 2000}회';
                } else if (year >= 1900) {
                  displayText = '${year - 1900}회';
                } else {
                  displayText = '$year회';
                }
                return ListTile(
                  title: Text(displayText),
                  onTap: () {
                    setState(() => _selectedYear = year);
                    _filterAlumni(_searchController.text);
                    Navigator.pop(context);
                  },
                  selected: _selectedYear == year,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '강릉고 총동문회',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: '강릉고 총동문회',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.school, size: 48),
                children: const [
                  Text('강릉고등학교 총동문회 주소록 앱입니다.'),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 검색 바
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '이름, 회사, 직책, 주소, 이메일 등 통합 검색...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterAlumni('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: _filterAlumni,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 필터 버튼과 통계
                  Row(
                    children: [
                      // 기수 필터 버튼
                      OutlinedButton.icon(
                        onPressed: _showYearFilterDialog,
                        icon: const Icon(Icons.filter_list),
                        label: Text(
                          _selectedYear == null 
                              ? '기수 선택' 
                              : _selectedYear! >= 2000
                                  ? '${_selectedYear! - 2000}회'
                                  : _selectedYear! >= 1900
                                      ? '${_selectedYear! - 1900}회'
                                      : '$_selectedYear회'
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // 동문 수
                      Text(
                        '전체 ${_filteredAlumni.length}명',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 동문 목록
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAlumni.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '검색 결과가 없습니다',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAlumni,
                          child: ListView.builder(
                            itemCount: _filteredAlumni.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final alumni = _filteredAlumni[index];
                              return _AlumniCard(
                                alumni: alumni,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AlumniDetailScreen(
                                        alumni: alumni,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _AlumniCard extends StatelessWidget {
  final Alumni alumni;
  final VoidCallback onTap;

  const _AlumniCard({
    required this.alumni,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 프로필 아이콘
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: alumni.profilePhotoUrl.isNotEmpty
                    ? NetworkImage(alumni.profilePhotoUrl)
                    : null,
                child: alumni.profilePhotoUrl.isEmpty
                    ? Text(
                        alumni.name.isNotEmpty ? alumni.name[0] : '?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          alumni.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            alumni.displayGraduation,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alumni.company.isNotEmpty && alumni.jobTitle.isNotEmpty
                          ? '${alumni.company} · ${alumni.jobTitle}'
                          : alumni.company.isNotEmpty
                              ? alumni.company
                              : alumni.jobTitle.isNotEmpty
                                  ? alumni.jobTitle
                                  : '정보 없음',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          alumni.maskedPhone,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 화살표 아이콘
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
