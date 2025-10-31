import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alumni.dart';
import 'alumni_detail_screen.dart';

class ClassAlumniListScreen extends StatefulWidget {
  final int graduationYear;
  final String classText;

  const ClassAlumniListScreen({
    super.key,
    required this.graduationYear,
    required this.classText,
  });

  @override
  State<ClassAlumniListScreen> createState() => _ClassAlumniListScreenState();
}

class _ClassAlumniListScreenState extends State<ClassAlumniListScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Alumni> _allAlumni = [];
  List<Alumni> _filteredAlumni = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlumni();
  }

  Future<void> _loadAlumni() async {
    setState(() => _isLoading = true);
    
    try {
      // class_number 필드로 검색 (신규 데이터)
      final querySnapshot1 = await FirebaseFirestore.instance
          .collection('alumni')
          .where('class_number', isEqualTo: widget.graduationYear)
          .get();
      
      // graduation_year 필드로도 검색 (구버전 데이터 호환)
      final querySnapshot2 = await FirebaseFirestore.instance
          .collection('alumni')
          .where('graduation_year', isEqualTo: widget.graduationYear)
          .get();
      
      // 두 결과 합치기 (중복 제거)
      final alumniMap = <String, Alumni>{};
      
      for (var doc in querySnapshot1.docs) {
        alumniMap[doc.id] = Alumni.fromFirestore(doc.data(), doc.id);
      }
      
      for (var doc in querySnapshot2.docs) {
        if (!alumniMap.containsKey(doc.id)) {
          alumniMap[doc.id] = Alumni.fromFirestore(doc.data(), doc.id);
        }
      }
      
      final alumni = alumniMap.values.toList();
      
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

  void _filterAlumni(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAlumni = _allAlumni;
      } else {
        _filteredAlumni = _allAlumni.where((alumni) {
          return alumni.name.toLowerCase().contains(query.toLowerCase()) ||
              alumni.company.toLowerCase().contains(query.toLowerCase()) ||
              alumni.jobTitle.toLowerCase().contains(query.toLowerCase()) ||
              alumni.department.toLowerCase().contains(query.toLowerCase()) ||
              alumni.address.toLowerCase().contains(query.toLowerCase()) ||
              alumni.email.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
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
                      hintText: '이름, 회사, 직책 등으로 검색...',
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
                  
                  // 동문 수 표시
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${_filteredAlumni.length}명',
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
                child: Text(
                  alumni.name.isNotEmpty ? alumni.name[0] : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alumni.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
