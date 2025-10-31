import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alumni.dart';
import '../services/auth_manager.dart';
import 'alumni_detail_screen.dart';
import 'admin_menu_screen.dart';

/// 동문 검색 화면
class AlumniSearchScreen extends StatefulWidget {
  const AlumniSearchScreen({super.key});

  @override
  State<AlumniSearchScreen> createState() => _AlumniSearchScreenState();
}

class _AlumniSearchScreenState extends State<AlumniSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthManager _authManager = AuthManager();
  
  bool _isSearching = false;
  List<Alumni> _searchResults = [];

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('alumni')
          .get();
      
      final results = querySnapshot.docs
          .map((doc) => Alumni.fromFirestore(doc.data(), doc.id))
          .where((alumni) {
            final searchLower = query.toLowerCase();
            return alumni.name.toLowerCase().contains(searchLower) ||
                alumni.company.toLowerCase().contains(searchLower) ||
                alumni.jobTitle.toLowerCase().contains(searchLower) ||
                alumni.phone.contains(query) ||
                alumni.address.toLowerCase().contains(searchLower);
          })
          .toList();

      results.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 실패: $e')),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
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
        child: Column(
          children: [
            // 검색창 헤더
            Container(
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
              child: TextField(
                controller: _searchController,
                onChanged: _performSearch,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: '이름, 회사, 직책, 지역, 연락처 등 검색...',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade500,
                    size: 24,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
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
                    vertical: 14,
                  ),
                ),
              ),
            ),

            // 검색 결과
            Expanded(
              child: _isSearching
                  ? _searchResults.isEmpty
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
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final alumni = _searchResults[index];
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
                        )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '동문 이름이나 정보를 검색하세요',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
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
