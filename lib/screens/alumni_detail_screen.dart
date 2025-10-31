import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alumni.dart';
import '../services/auth_manager.dart';
import 'edit_alumni_screen.dart';

/// 동문 상세 정보 화면
class AlumniDetailScreen extends StatefulWidget {
  final Alumni alumni;

  const AlumniDetailScreen({
    super.key,
    required this.alumni,
  });

  @override
  State<AlumniDetailScreen> createState() => _AlumniDetailScreenState();
}

class _AlumniDetailScreenState extends State<AlumniDetailScreen> {
  final AuthManager _authManager = AuthManager();
  late Alumni _alumni;

  @override
  void initState() {
    super.initState();
    _alumni = widget.alumni;
  }

  bool get _canEdit {
    // 관리자이거나 본인인 경우 수정 가능
    return _authManager.isAdmin || _authManager.isOwner(_alumni.phone);
  }

  Future<void> _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAlumniScreen(alumni: _alumni),
      ),
    );

    // 수정 완료 후 돌아왔을 때 데이터 업데이트
    if (result != null && mounted) {
      if (result is Alumni) {
        // Alumni 객체가 반환된 경우 (전화번호 변경 또는 일반 수정)
        setState(() {
          _alumni = result;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 정보가 업데이트되었습니다!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
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
          // 수정 버튼 (본인이거나 관리자만 표시)
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _navigateToEdit,
              tooltip: '정보 수정',
            ),
          // 관리자 표시
          if (_authManager.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  label: const Text(
                    '관리자',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.amber[700],
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 헤더
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: _alumni.profilePhotoUrl.isNotEmpty
                          ? NetworkImage(_alumni.profilePhotoUrl)
                          : null,
                      child: _alumni.profilePhotoUrl.isEmpty
                          ? Text(
                              _alumni.name.isNotEmpty ? _alumni.name[0] : '?',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _alumni.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_alumni.graduationYear}회',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    if (_alumni.isVerified)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '인증됨',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 연락처 정보
              _buildSection(
                context,
                title: '연락처 정보',
                icon: Icons.contact_phone,
                children: [
                  if (_alumni.phone.isNotEmpty)
                    _buildInfoTile(
                      context,
                      icon: Icons.phone,
                      label: '전화번호',
                      value: _alumni.phone,
                      onTap: () => _makePhoneCall(_alumni.phone),
                      onLongPress: () => _copyToClipboard(context, _alumni.phone, '전화번호'),
                    ),
                  if (_alumni.phone2.isNotEmpty)
                    _buildInfoTile(
                      context,
                      icon: Icons.phone_android,
                      label: '회사전화',
                      value: _alumni.phone2,
                      onTap: () => _makePhoneCall(_alumni.phone2),
                      onLongPress: () => _copyToClipboard(context, _alumni.phone2, '회사전화'),
                    ),
                  if (_alumni.email.isNotEmpty)
                    _buildInfoTile(
                      context,
                      icon: Icons.email,
                      label: '이메일',
                      value: _alumni.email,
                      onTap: () => _sendEmail(_alumni.email),
                      onLongPress: () => _copyToClipboard(context, _alumni.email, '이메일'),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 주소 정보
              if (_alumni.address.isNotEmpty || _alumni.address2.isNotEmpty)
                _buildSection(
                  context,
                  title: '주소 정보',
                  icon: Icons.location_on,
                  children: [
                    if (_alumni.address.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.home,
                        label: '집주소',
                        value: _alumni.address,
                        onLongPress: () => _copyToClipboard(context, _alumni.address, '집주소'),
                      ),
                    if (_alumni.address2.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.location_city,
                        label: '회사주소',
                        value: _alumni.address2,
                        onLongPress: () => _copyToClipboard(context, _alumni.address2, '회사주소'),
                      ),
                  ],
                ),
              
              const SizedBox(height: 24),
              
              // 직장 정보
              if (_alumni.company.isNotEmpty || _alumni.jobTitle.isNotEmpty || _alumni.department.isNotEmpty)
                _buildSection(
                  context,
                  title: '직장 정보',
                  icon: Icons.work,
                  children: [
                    if (_alumni.company.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.business,
                        label: '직장명',
                        value: _alumni.company,
                      ),
                    if (_alumni.jobTitle.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.badge,
                        label: '직책',
                        value: _alumni.jobTitle,
                      ),
                    if (_alumni.department.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.group_work,
                        label: '부서',
                        value: _alumni.department,
                      ),
                  ],
                ),
              
              const SizedBox(height: 24),
              
              // 기타 정보
              if (_alumni.birthDate.isNotEmpty || _alumni.notes.isNotEmpty)
                _buildSection(
                  context,
                  title: '기타 정보',
                  icon: Icons.info,
                  children: [
                    if (_alumni.birthDate.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.cake,
                        label: '생년월일',
                        value: _alumni.birthDate,
                      ),
                    if (_alumni.notes.isNotEmpty)
                      _buildInfoTile(
                        context,
                        icon: Icons.note,
                        label: '메모',
                        value: _alumni.notes,
                      ),
                  ],
                ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
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

  void _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 복사됨: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
