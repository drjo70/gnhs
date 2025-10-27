import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/alumni.dart';
import '../services/auth_manager.dart';
import 'edit_profile_screen.dart';

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
  late Alumni _alumni;
  final AuthManager _authManager = AuthManager();

  @override
  void initState() {
    super.initState();
    _alumni = widget.alumni;
  }

  // 본인 소유 확인 헬퍼 메서드
  bool get _isOwner => _authManager.isOwner(_alumni.phone);

  Future<void> _makePhoneCall() async {
    final Uri url = Uri(scheme: 'tel', path: _alumni.phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendSMS() async {
    final Uri url = Uri(scheme: 'sms', path: _alumni.phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendEmail() async {
    final Uri url = Uri(
      scheme: 'mailto',
      path: _alumni.email,
      query: 'subject=강릉고 동문 인사',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _navigateToEdit() async {
    // 본인 확인은 버튼 표시 단계에서 이미 완료됨 (AuthManager.isOwner)
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(alumni: _alumni),
      ),
    );

    // 수정 완료 후 데이터 새로고침
    if (result == true && mounted) {
      await _refreshAlumniData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 프로필이 업데이트되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }



  Future<void> _refreshAlumniData() async {
    try {
      // Firestore에서 최신 데이터 가져오기
      final doc = await FirebaseFirestore.instance
          .collection('alumni')
          .doc(_alumni.phone) // phone은 이미 문서 ID
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _alumni = Alumni.fromFirestore(doc.data()!, doc.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 새로고침 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteAlumni() async {
    // 본인 확인은 버튼 표시 단계에서 이미 완료됨 (AuthManager.isOwner)
    
    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('동문 정보 삭제'),
        content: Text('${_alumni.name}님의 정보를 정말 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Firestore에서 삭제
      await FirebaseFirestore.instance
          .collection('alumni')
          .doc(_alumni.phone)
          .delete();

      if (mounted) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 동문 정보가 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 이전 화면으로 돌아가기 (삭제되었음을 알림)
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    // Web 플랫폼에서는 기능 비활성화 (Android APK 전용)
    if (kIsWeb) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('기능 제한'),
            content: const Text(
              '프로필 사진 업로드는 Android 앱에서만 사용 가능합니다.\n\nWeb 버전에서는 보기 전용입니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      
      // 이미지 선택
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      // 로딩 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('사진 업로드 중...'),
              ],
            ),
            duration: Duration(hours: 1),
          ),
        );
      }

      // Web용: 이미지를 Uint8List로 읽기
      final Uint8List imageBytes = await image.readAsBytes();
      
      // Firebase Storage에 업로드
      final String fileName = 'profile_photos/${_alumni.phone}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      // 메타데이터 설정
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_by': _alumni.name,
          'alumni_phone': _alumni.phone,
        },
      );

      // 업로드 실행
      final TaskSnapshot uploadTask = await storageRef.putData(imageBytes, metadata);
      
      // 다운로드 URL 가져오기
      final String downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('alumni')
          .doc(_alumni.phone)
          .update({
        'profile_photo_url': downloadUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 로컬 상태 업데이트
      await _refreshAlumniData();

      // 로딩 스낵바 제거 및 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 프로필 사진이 업로드되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 업로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteProfilePhoto() async {
    if (_alumni.profilePhotoUrl.isEmpty) return;

    // Web 플랫폼에서는 기능 비활성화
    if (kIsWeb) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('기능 제한'),
            content: const Text('프로필 사진 삭제는 Android 앱에서만 사용 가능합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 사진 삭제'),
        content: const Text('프로필 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Firestore에서 URL 제거
      await FirebaseFirestore.instance
          .collection('alumni')
          .doc(_alumni.phone)
          .update({
        'profile_photo_url': '',
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Firebase Storage에서 파일 삭제 시도 (옵션)
      try {
        final Reference photoRef = FirebaseStorage.instance.refFromURL(_alumni.profilePhotoUrl);
        await photoRef.delete();
      } catch (e) {
        // Storage 삭제 실패는 무시 (URL만 제거되어도 OK)
      }

      // 로컬 상태 업데이트
      await _refreshAlumniData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 프로필 사진이 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('동문 정보'),
        actions: [
          // 본인 정보일 경우에만 수정/삭제 버튼 표시
          if (_isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _navigateToEdit,
              tooltip: '정보 수정',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteAlumni,
              tooltip: '정보 삭제',
              color: Colors.red,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 프로필 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  children: [
                    // 프로필 사진 (원형 아바타) - 클릭하여 업로드/변경
                    GestureDetector(
                      onTap: _uploadProfilePhoto,
                      onLongPress: _alumni.profilePhotoUrl.isNotEmpty ? _deleteProfilePhoto : null,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            backgroundImage: _alumni.profilePhotoUrl.isNotEmpty
                                ? NetworkImage(_alumni.profilePhotoUrl)
                                : null,
                            child: _alumni.profilePhotoUrl.isEmpty
                                ? Text(
                                    _alumni.name.isNotEmpty ? _alumni.name[0] : '?',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 이름
                    Text(
                      _alumni.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 기수
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _alumni.displayGraduation,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 연락 버튼
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _ContactButton(
                        icon: Icons.phone,
                        label: '전화',
                        onPressed: _makePhoneCall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ContactButton(
                        icon: Icons.message,
                        label: '문자',
                        onPressed: _sendSMS,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ContactButton(
                        icon: Icons.email,
                        label: '이메일',
                        onPressed: _sendEmail,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // 상세 정보
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '상세 정보',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (_alumni.company.isNotEmpty && _alumni.company != '미등록')
                      _InfoItem(
                        icon: Icons.business,
                        label: '직장',
                        value: _alumni.company,
                      ),
                    
                    if (_alumni.department.isNotEmpty && _alumni.department != '미등록')
                      _InfoItem(
                        icon: Icons.domain,
                        label: '부서',
                        value: _alumni.department,
                      ),
                    
                    if (_alumni.jobTitle.isNotEmpty && _alumni.jobTitle != '미등록')
                      _InfoItem(
                        icon: Icons.work,
                        label: '직책',
                        value: _alumni.jobTitle,
                      ),
                    
                    _InfoItem(
                      icon: Icons.phone,
                      label: '연락처 1',
                      value: _alumni.phone,
                    ),
                    
                    if (_alumni.phone2.isNotEmpty)
                      _InfoItem(
                        icon: Icons.phone_android,
                        label: '연락처 2',
                        value: _alumni.phone2,
                      ),
                    
                    if (_alumni.email.isNotEmpty)
                      _InfoItem(
                        icon: Icons.email,
                        label: '이메일 1',
                        value: _alumni.email,
                      ),
                    
                    if (_alumni.email2.isNotEmpty)
                      _InfoItem(
                        icon: Icons.alternate_email,
                        label: '이메일 2',
                        value: _alumni.email2,
                      ),
                    
                    if (_alumni.address.isNotEmpty)
                      _InfoItem(
                        icon: Icons.home,
                        label: '주소 1',
                        value: _alumni.address,
                      ),
                    
                    if (_alumni.address2.isNotEmpty)
                      _InfoItem(
                        icon: Icons.location_on,
                        label: '주소 2',
                        value: _alumni.address2,
                      ),
                    
                    if (_alumni.birthDate.isNotEmpty)
                      _InfoItem(
                        icon: Icons.cake,
                        label: '생년월일',
                        value: _alumni.birthDate,
                      ),
                    
                    if (_alumni.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '메모',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _alumni.notes,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
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

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
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
        ],
      ),
    );
  }
}
