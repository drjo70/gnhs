import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alumni.dart';

class EditProfileScreen extends StatefulWidget {
  final Alumni alumni;

  const EditProfileScreen({
    super.key,
    required this.alumni,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  
  // 텍스트 컨트롤러들
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _email2Controller;
  late TextEditingController _companyController;
  late TextEditingController _jobTitleController;
  late TextEditingController _departmentController;
  late TextEditingController _addressController;
  late TextEditingController _address2Controller;
  late TextEditingController _phoneController;
  late TextEditingController _phone2Controller;
  late TextEditingController _birthDateController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    
    // 기존 데이터로 초기화
    _nameController = TextEditingController(text: widget.alumni.name);
    _emailController = TextEditingController(text: widget.alumni.email);
    _email2Controller = TextEditingController(text: widget.alumni.email2);
    _companyController = TextEditingController(text: widget.alumni.company);
    _jobTitleController = TextEditingController(text: widget.alumni.jobTitle);
    _departmentController = TextEditingController(text: widget.alumni.department);
    _addressController = TextEditingController(text: widget.alumni.address);
    _address2Controller = TextEditingController(text: widget.alumni.address2);
    _phoneController = TextEditingController(text: widget.alumni.phone);
    _phone2Controller = TextEditingController(text: widget.alumni.phone2);
    _birthDateController = TextEditingController(text: widget.alumni.birthDate);
    _notesController = TextEditingController(text: widget.alumni.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _email2Controller.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    _addressController.dispose();
    _address2Controller.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _birthDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Firestore 업데이트
      // widget.alumni.phone은 이제 문서 ID 그 자체 (하이픈 없음)
      await FirebaseFirestore.instance
          .collection('alumni')
          .doc(widget.alumni.phone)
          .update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'email2': _email2Controller.text.trim(),
        'company': _companyController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'department': _departmentController.text.trim(),
        'address': _addressController.text.trim(),
        'address2': _address2Controller.text.trim(),
        'phone2': _phone2Controller.text.trim().replaceAll('-', '').replaceAll(' ', ''),
        'birth_date': _birthDateController.text.trim(),
        'notes': _notesController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 프로필이 성공적으로 업데이트되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true를 반환하여 새로고침 필요 표시
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: '저장',
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 안내 메시지
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '모든 동문이 볼 수 있는 정보입니다.\n정확한 정보를 입력해주세요.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 기본 정보
                _SectionHeader(title: '기본 정보'),
                _buildTextField(
                  controller: _nameController,
                  label: '이름',
                  icon: Icons.person,
                  required: true,
                ),
                _buildTextField(
                  controller: _phoneController,
                  label: '전화번호',
                  icon: Icons.phone,
                  enabled: false, // 전화번호는 수정 불가
                  helperText: '전화번호는 변경할 수 없습니다',
                ),
                _buildTextField(
                  controller: _phone2Controller,
                  label: '보조 전화번호',
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                ),
                _buildTextField(
                  controller: _birthDateController,
                  label: '생년월일',
                  icon: Icons.cake,
                  helperText: '예: 1990-01-01',
                ),

                const SizedBox(height: 24),

                // 이메일
                _SectionHeader(title: '이메일'),
                _buildTextField(
                  controller: _emailController,
                  label: '이메일 1',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildTextField(
                  controller: _email2Controller,
                  label: '이메일 2',
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 24),

                // 직장 정보
                _SectionHeader(title: '직장 정보'),
                _buildTextField(
                  controller: _companyController,
                  label: '직장',
                  icon: Icons.business,
                ),
                _buildTextField(
                  controller: _departmentController,
                  label: '부서',
                  icon: Icons.domain,
                ),
                _buildTextField(
                  controller: _jobTitleController,
                  label: '직책',
                  icon: Icons.work,
                ),

                const SizedBox(height: 24),

                // 주소
                _SectionHeader(title: '주소'),
                _buildTextField(
                  controller: _addressController,
                  label: '주소 1',
                  icon: Icons.home,
                  maxLines: 2,
                ),
                _buildTextField(
                  controller: _address2Controller,
                  label: '주소 2',
                  icon: Icons.location_on,
                  maxLines: 2,
                ),

                const SizedBox(height: 24),

                // 메모
                _SectionHeader(title: '메모'),
                _buildTextField(
                  controller: _notesController,
                  label: '메모',
                  icon: Icons.note,
                  maxLines: 4,
                  helperText: '동문들과 공유하고 싶은 내용을 자유롭게 작성하세요',
                ),

                const SizedBox(height: 32),

                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? '저장 중...' : '저장하기',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: !enabled,
          fillColor: enabled ? null : Colors.grey[200],
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label을(를) 입력해주세요';
                }
                return null;
              }
            : null,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
