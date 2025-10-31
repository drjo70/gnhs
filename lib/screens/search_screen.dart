import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alumni.dart';
import 'alumni_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Alumni> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query.trim().toLowerCase();
    });

    try {
      // Firestore에서 모든 동문 데이터 가져오기
      final snapshot = await _firestore.collection('alumni').get();
      
      // 클라이언트 측에서 필터링
      final results = <Alumni>[];
      final searchLower = _currentQuery;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final alumni = Alumni.fromFirestore(data, doc.id);
        
        // 모든 필드에서 검색
        final name = alumni.name.toLowerCase();
        final company = alumni.company.toLowerCase();
        final jobTitle = alumni.jobTitle.toLowerCase();
        final department = alumni.department.toLowerCase();
        final address = alumni.address.toLowerCase();
        final address2 = alumni.address2.toLowerCase();
        final email = alumni.email.toLowerCase();
        final phone = alumni.phone.toLowerCase();
        final phone2 = alumni.phone2.toLowerCase();
        final notes = alumni.notes.toLowerCase();
        final graduation = alumni.displayGraduation.toLowerCase();
        
        if (name.contains(searchLower) ||
            company.contains(searchLower) ||
            jobTitle.contains(searchLower) ||
            department.contains(searchLower) ||
            address.contains(searchLower) ||
            address2.contains(searchLower) ||
            email.contains(searchLower) ||
            phone.contains(searchLower) ||
            phone2.contains(searchLower) ||
            notes.contains(searchLower) ||
            graduation.contains(searchLower)) {
          results.add(alumni);
        }
      }
      
      // 이름순 정렬
      results.sort((a, b) => a.name.compareTo(b.name));
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _hasSearched = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 실패: $e')),
        );
      }
    }
  }

  String _highlightText(String text, String query) {
    if (query.isEmpty) return text;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('동문 검색'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 검색창
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '이름, 회사, 직책, 지역, 연락처 등 검색...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  // 실시간 검색 (500ms 딜레이)
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_searchController.text == value) {
                      _performSearch(value);
                    }
                  });
                  setState(() {});
                },
                onSubmitted: _performSearch,
              ),
            ),

            // 검색 결과
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : !_hasSearched
                      ? _buildSearchGuide()
                      : _searchResults.isEmpty
                          ? _buildNoResults()
                          : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchGuide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '동문을 검색하세요',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '이름, 회사, 직책, 지역 등으로 검색 가능합니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '검색 결과가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$_currentQuery"에 대한 결과를 찾을 수 없습니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        // 검색 결과 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              Text(
                '검색 결과: ${_searchResults.length}명',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // 검색 결과 리스트
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final alumni = _searchResults[index];
              return _SearchResultCard(
                alumni: alumni,
                searchQuery: _currentQuery,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlumniDetailScreen(alumni: alumni),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final Alumni alumni;
  final String searchQuery;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.alumni,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이름과 회차
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
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      alumni.displayGraduation,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 회사 및 직책
              if (alumni.company.isNotEmpty && alumni.company != '미등록')
                Row(
                  children: [
                    Icon(Icons.business, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${alumni.company}${alumni.jobTitle.isNotEmpty && alumni.jobTitle != '미등록' ? ' · ${alumni.jobTitle}' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

              // 부서
              if (alumni.department.isNotEmpty && alumni.department != '미등록')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.group, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          alumni.department,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 주소
              if (alumni.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          alumni.address,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // 연락처
              if (alumni.phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        alumni.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
