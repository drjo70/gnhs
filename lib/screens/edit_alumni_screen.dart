import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/alumni.dart';
import '../services/auth_manager.dart';

/// 동문 정보 수정 화면
class EditAlumniScreen extends StatefulWidget {
  final Alumni alumni;

  const EditAlumniScreen({
    super.key,
    required this.alumni,
  });

  @override
  State<EditAlumniScreen> createState() => _EditAlumniScreenState();
}

class _EditAlumniScreenState extends State<EditAlumniScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthManager _authManager = AuthManager();
  final ImagePicker _picker = ImagePicker();
  
  bool _isUploadingImage = false;
  XFile? _selectedImage;
  String? _uploadedImageUrl;
  
  late TextEditingController _nameController;
  late TextEditingController _graduationYearController;
  late TextEditingController _phoneController;
  late TextEditingController _phone2Controller;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _address2Controller;
  late TextEditingController _companyController;
  late TextEditingController _jobTitleController;
  late TextEditingController _departmentController;
  late TextEditingController _birthDateController;
  late TextEditingController _notesController;
  
  bool _isLoading = false;
  bool _canEditCoreFields = false;

  @override
  void initState() {
    super.initState();
    
    // 관리자만 핵심 필드(이름, 기수, 전화번호) 수정 가능
    _canEditCoreFields = _authManager.isAdmin;
    
    _nameController = TextEditingController(text: widget.alumni.name);
    _graduationYearController = TextEditingController(text: widget.alumni.graduationYear.toString());
    _phoneController = TextEditingController(text: widget.alumni.phone);
    _phone2Controller = TextEditingController(text: widget.alumni.phone2);
    _emailController = TextEditingController(text: widget.alumni.email);
    _addressController = TextEditingController(text: widget.alumni.address);
    _address2Controller = TextEditingController(text: widget.alumni.address2);
    _companyController = TextEditingController(text: widget.alumni.company);
    _jobTitleController = TextEditingController(text: widget.alumni.jobTitle);
    _departmentController = TextEditingController(text: widget.alumni.department);
    _birthDateController = TextEditingController(text: widget.alumni.birthDate);
    _notesController = TextEditingController(text: widget.alumni.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _graduationYearController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _address2Controller.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    _birthDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // 이미지 선택
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        
        // 즉시 업로드
        await _uploadImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Firebase Storage에 이미지 업로드
  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;
    
    setState(() => _isUploadingImage = true);
    
    try {
      final normalizedPhone = widget.alumni.phone.replaceAll('-', '').replaceAll(' ', '');
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$normalizedPhone.jpg');
      
      // 웹과 모바일 플랫폼 처리
      UploadTask uploadTask;
      if (kIsWeb) {
        // 웹: bytes 사용
        final bytes = await _selectedImage!.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // 모바일: File 사용
        final file = File(_selectedImage!.path);
        uploadTask = storageRef.putFile(file);
      }
      
      // 업로드 완료 대기
      final snapshot = await uploadTask;
      
      // 다운로드 URL 가져오기
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      setState(() {
        _uploadedImageUrl = downloadUrl;
        _isUploadingImage = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 사진이 업로드되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진 업로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 전화번호를 정규화하여 Document ID로 사용 (하이픈 제거)
      final normalizedPhone = widget.alumni.phone.replaceAll('-', '').replaceAll(' ', '');
      
      final alumniRef = FirebaseFirestore.instance
          .collection('alumni')
          .doc(normalizedPhone);

      final updateData = <String, dynamic>{
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'address2': _address2Controller.text.trim(),
        'organization': _companyController.text.trim(),
        'organization_title': _jobTitleController.text.trim(),
        'organization_dept': _departmentController.text.trim(),
        'birthday': _birthDateController.text.trim(),
        'notes': _notesController.text.trim(),
        'phone2': _phone2Controller.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // 업로드된 이미지 URL이 있으면 추가
      if (_uploadedImageUrl != null) {
        print('📸 프로필 사진 URL 저장: $_uploadedImageUrl');
        updateData['profile_photo_url'] = _uploadedImageUrl;
      } else {
        print('⚠️ 업로드된 이미지 URL이 없음');
      }

      // 관리자만 핵심 필드 수정 가능
      if (_canEditCoreFields) {
        updateData['name'] = _nameController.text.trim();
        updateData['class_number'] = int.tryParse(_graduationYearController.text.trim()) ?? 0;
        
        // 전화번호 변경 체크
        final newPhone = _phoneController.text.trim().replaceAll('-', '').replaceAll(' ', '');
        final oldPhone = normalizedPhone;
        
        if (newPhone != oldPhone) {
          // 전화번호가 변경된 경우: 새 Document 생성 후 이전 Document 삭제
          print('📞 전화번호 변경: $oldPhone → $newPhone');
          
          // 1. phone 필드 업데이트
          updateData['phone'] = newPhone;
          
          // 2. 새 Document ID로 문서 생성
          final newDocRef = FirebaseFirestore.instance
              .collection('alumni')
              .doc(newPhone);
          
          await newDocRef.set(updateData);
          
          // 3. 이전 Document 삭제
          await alumniRef.delete();
          
          // 4. 새로 생성된 문서에서 최신 데이터 가져오기
          final newDoc = await newDocRef.get();
          final updatedAlumni = Alumni.fromFirestore(newDoc.data()!, newDoc.id);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ 전화번호가 변경되었습니다!'),
                backgroundColor: Colors.green,
              ),
            );
            // 수정된 Alumni 객체 반환
            Navigator.pop(context, updatedAlumni);
          }
          return; // 여기서 종료
        }
      }

      // 전화번호 변경이 없는 경우 일반 업데이트
      print('💾 Firestore 업데이트 시작...');
      print('📝 업데이트 데이터: $updateData');
      await alumniRef.update(updateData);
      print('✅ Firestore 업데이트 완료');
      
      // 업데이트된 문서에서 최신 데이터 가져오기
      final updatedDoc = await alumniRef.get();
      final updatedAlumni = Alumni.fromFirestore(updatedDoc.data()!, updatedDoc.id);
      print('📊 업데이트된 Alumni: profile_photo_url = ${updatedAlumni.profilePhotoUrl}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 정보가 성공적으로 수정되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        // 수정된 Alumni 객체 반환
        Navigator.pop(context, updatedAlumni);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 수정 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('정보 수정'),
        centerTitle: true,
        actions: [
          if (_canEditCoreFields)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text(
                  '관리자',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.amber[700],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 안내 메시지
                    if (!_canEditCoreFields)
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '이름, 기수는 관리자만 수정 가능합니다.',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // 프로필 사진 섹션
                    Center(
                      child: Column(
                        children: [
                          // 프로필 사진
                          GestureDetector(
                            onTap: _isUploadingImage ? null : _pickImage,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 3,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: CircleAvatar(
                                      radius: 65,
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: _selectedImage != null
                                          ? (kIsWeb
                                              ? NetworkImage(_selectedImage!.path) as ImageProvider
                                              : FileImage(File(_selectedImage!.path)))
                                          : (_uploadedImageUrl ?? widget.alumni.profilePhotoUrl).isNotEmpty
                                              ? NetworkImage(_uploadedImageUrl ?? widget.alumni.profilePhotoUrl)
                                              : null,
                                      child: (_selectedImage == null &&
                                              (_uploadedImageUrl ?? widget.alumni.profilePhotoUrl).isEmpty)
                                          ? Text(
                                              widget.alumni.name.isNotEmpty
                                                  ? widget.alumni.name[0]
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 40,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  if (_isUploadingImage)
                                    Center(
                                      child: Container(
                                        width: 130,
                                        height: 130,
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // 카메라 아이콘 배지
                                  Positioned(
                                    bottom: 5,
                                    right: 5,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _isUploadingImage ? null : _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('사진 선택'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '프로필 사진을 클릭하거나 버튼을 눌러 변경',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 기본 정보
                    _buildSectionTitle('기본 정보'),
                    _buildTextField(
                      controller: _nameController,
                      label: '이름',
                      icon: Icons.person,
                      enabled: _canEditCoreFields,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '이름을 입력하세요';
                        }
                        return null;
                      },
                    ),
                    _buildTextField(
                      controller: _graduationYearController,
                      label: '기수',
                      icon: Icons.school,
                      keyboardType: TextInputType.number,
                      enabled: _canEditCoreFields,
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: '전화번호',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      enabled: _canEditCoreFields, // 관리자만 전화번호 수정 가능
                      helperText: _canEditCoreFields 
                          ? '⚠️ 주의: 전화번호 변경 시 로그인 정보도 변경됩니다'
                          : '전화번호는 관리자만 수정할 수 있습니다',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 연락처 정보
                    _buildSectionTitle('연락처 정보'),
                    _buildTextField(
                      controller: _phone2Controller,
                      label: '회사전화',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                    ),
                    _buildTextField(
                      controller: _emailController,
                      label: '이메일',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 주소 정보
                    _buildSectionTitle('주소 정보'),
                    _buildTextField(
                      controller: _addressController,
                      label: '집주소',
                      icon: Icons.home,
                      maxLines: 2,
                    ),
                    _buildTextField(
                      controller: _address2Controller,
                      label: '회사주소',
                      icon: Icons.location_city,
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 직장 정보
                    _buildSectionTitle('직장 정보'),
                    _buildTextField(
                      controller: _companyController,
                      label: '직장명',
                      icon: Icons.business,
                    ),
                    _buildTextField(
                      controller: _jobTitleController,
                      label: '직책',
                      icon: Icons.badge,
                    ),
                    _buildTextField(
                      controller: _departmentController,
                      label: '부서',
                      icon: Icons.group_work,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 기타 정보
                    _buildSectionTitle('기타 정보'),
                    _buildTextField(
                      controller: _birthDateController,
                      label: '생년월일',
                      icon: Icons.cake,
                      helperText: '예: 1990-01-01',
                    ),
                    _buildTextField(
                      controller: _notesController,
                      label: '메모',
                      icon: Icons.note,
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // 저장 버튼
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveChanges,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        '저장',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          helperText: helperText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabled: enabled,
          filled: !enabled,
          fillColor: enabled ? null : Colors.grey[100],
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
      ),
    );
  }
}
