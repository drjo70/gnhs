import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddAlumniScreen extends StatefulWidget {
  const AddAlumniScreen({super.key});

  @override
  State<AddAlumniScreen> createState() => _AddAlumniScreenState();
}

class _AddAlumniScreenState extends State<AddAlumniScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isSaving = false;
  
  // 필수 항목
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _graduationYearController = TextEditingController();
  
  // 선택 항목
  final _emailController = TextEditingController();
  final _email2Controller = TextEditingController();
  final _companyController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _addressController = TextEditingController();
  final _address2Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _birthDateController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _graduationYearController.dispose();
    _emailController.dispose();
    _email2Controller.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    _addressController.dispose();
    _address2Controller.dispose();
    _phone2Controller.dispose();
    _birthDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _cleanPhoneNumber(String phone) {
    // 하이픈 제거
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatPhoneNumber(String phone) {
    // 010-1234-5678 형식으로 변환
    final cleaned = _cleanPhoneNumber(phone);
    if (cleaned.length == 11 && cleaned.startsWith('010')) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    }
    return phone;
  }

  Future<void> _saveAlumni() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final phone = _cleanPhoneNumber(_phoneController.text.trim());
      
      // 중복 체크
      final existingDoc = await _firestore
          .collection('alumni')
          .doc(phone)
          .get();
      
      if (existingDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 등록된 전화번호입니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      // 회차 그대로 저장 (예: 25 → 25, 1 → 1)
      final graduationYear = int.tryParse(_graduationYearController.text.trim()) ?? 0;

      // Firestore에 저장
      final alumniData = {
        'name': _nameController.text.trim(),
        'phone': _formatPhoneNumber(_phoneController.text.trim()),
        'graduation_year': graduationYear,
        'email': _emailController.text.trim(),
        'email2': _email2Controller.text.trim(),
        'company': _companyController.text.trim().isEmpty 
            ? '미등록' 
            : _companyController.text.trim(),
        'job_title': _jobTitleController.text.trim().isEmpty 
            ? '미등록' 
            : _jobTitleController.text.trim(),
        'department': _departmentController.text.trim(),
        'address': _addressController.text.trim(),
        'address2': _address2Controller.text.trim(),
        'phone2': _phone2Controller.text.trim(),
        'birth_date': _birthDateController.text.trim(),
        'notes': _notesController.text.trim(),
        'profile_photo_url': '',
        'is_verified': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('alumni').doc(phone).set(alumniData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 동문 정보가 추가되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // true 반환하여 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
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
        title: const Text('동문 추가'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveAlumni,
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 필수 항목 섹션
              _SectionHeader(
                title: '필수 항목',
                icon: Icons.star,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),

              // 이름
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름 *',
                  hintText: '홍길동',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이름을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 전화번호
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '전화번호 *',
                  hintText: '010-1234-5678',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '전화번호를 입력해주세요';
                  }
                  final cleaned = _cleanPhoneNumber(value);
                  if (!cleaned.startsWith('010') || cleaned.length != 11) {
                    return '올바른 010 전화번호를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 회차
              TextFormField(
                controller: _graduationYearController,
                decoration: const InputDecoration(
                  labelText: '회차 *',
                  hintText: '25 (숫자만 입력)',
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(),
                  suffixText: '회',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '회차를 입력해주세요';
                  }
                  final year = int.tryParse(value.trim());
                  if (year == null || year < 1 || year > 100) {
                    return '올바른 회차를 입력해주세요 (1-100)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 선택 항목 섹션
              _SectionHeader(
                title: '선택 항목',
                icon: Icons.edit,
                color: Colors.blue.shade400,
              ),
              const SizedBox(height: 16),

              // 이메일
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // 이메일 2
              TextFormField(
                controller: _email2Controller,
                decoration: const InputDecoration(
                  labelText: '이메일 2',
                  hintText: 'example2@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // 회사
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: '회사',
                  hintText: '삼성전자',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 직책
              TextFormField(
                controller: _jobTitleController,
                decoration: const InputDecoration(
                  labelText: '직책',
                  hintText: '부장',
                  prefixIcon: Icon(Icons.work),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 부서
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: '부서',
                  hintText: '영업팀',
                  prefixIcon: Icon(Icons.group),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 주소
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '주소',
                  hintText: '서울시 강남구 테헤란로 123',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // 주소 2
              TextFormField(
                controller: _address2Controller,
                decoration: const InputDecoration(
                  labelText: '주소 2',
                  hintText: '상세주소',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // 전화번호 2
              TextFormField(
                controller: _phone2Controller,
                decoration: const InputDecoration(
                  labelText: '전화번호 2',
                  hintText: '02-1234-5678',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // 생년월일
              TextFormField(
                controller: _birthDateController,
                decoration: const InputDecoration(
                  labelText: '생년월일',
                  hintText: '1980-01-01',
                  prefixIcon: Icon(Icons.cake),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),

              // 메모
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  hintText: '추가 정보를 입력하세요',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              // 저장 버튼
              ElevatedButton(
                onPressed: _isSaving ? null : _saveAlumni,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '동문 추가',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
