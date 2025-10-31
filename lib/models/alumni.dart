class Alumni {
  // documentId 필드 제거 - phone이 곧 Document ID
  final String phone;
  final String name;
  final int graduationYear;
  final String email;
  final String company;
  final String jobTitle;
  final String department;
  final String address;
  final String address2;
  final String birthDate;
  final String notes;
  final String phone2;
  final String profilePhotoUrl;
  final bool isVerified;

  Alumni({
    required this.phone,
    required this.name,
    required this.graduationYear,
    required this.email,
    required this.company,
    required this.jobTitle,
    required this.department,
    required this.address,
    required this.address2,
    required this.birthDate,
    required this.notes,
    required this.phone2,
    required this.profilePhotoUrl,
    required this.isVerified,
  });

  factory Alumni.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Alumni(
      // phone 필드 사용, 없으면 documentId 사용 (Document ID = 전화번호)
      phone: data['phone'] ?? documentId,
      name: data['name'] ?? '',
      // class_number (새 필드) 또는 graduation_year (이전 필드) 지원
      graduationYear: data['class_number'] ?? data['graduation_year'] ?? 0,
      email: data['email'] ?? '',
      // organization (새 필드) 또는 company (이전 필드) 지원
      company: data['organization'] ?? data['company'] ?? '',
      jobTitle: data['organization_title'] ?? data['job_title'] ?? '',
      department: data['organization_dept'] ?? data['department'] ?? '',
      address: data['address'] ?? '',
      address2: data['address2'] ?? '',
      birthDate: data['birthday'] ?? data['birth_date'] ?? '',
      notes: data['notes'] ?? '',
      phone2: data['phone2'] ?? '',
      profilePhotoUrl: data['profile_photo_url'] ?? '',
      isVerified: data['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phone': phone,
      'name': name,
      'graduation_year': graduationYear,
      'email': email,
      'company': company,
      'job_title': jobTitle,
      'department': department,
      'address': address,
      'address2': address2,
      'birth_date': birthDate,
      'notes': notes,
      'phone2': phone2,
      'profile_photo_url': profilePhotoUrl,
      'is_verified': isVerified,
      'updated_at': DateTime.now(),
    };
  }

  String get displayGraduation {
    // graduation_year는 이미 회차 숫자 (1, 2, 3, ... 25, ...)
    return '$graduationYear회';
  }
  
  String get maskedPhone {
    if (phone.length < 11) return phone;
    return '${phone.substring(0, 3)}-****-${phone.substring(phone.length - 4)}';
  }
}
