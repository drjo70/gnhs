class Alumni {
  final String phone;
  final String name;
  final int graduationYear;
  final String email;
  final String email2;
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
    required this.email2,
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
      // 문서 ID를 phone으로 사용 (문서 ID는 항상 하이픈 없는 전화번호)
      phone: documentId,
      name: data['name'] ?? '',
      graduationYear: data['graduation_year'] ?? 0,
      email: data['email'] ?? '',
      email2: data['email2'] ?? '',
      company: data['company'] ?? '',
      jobTitle: data['job_title'] ?? '',
      department: data['department'] ?? '',
      address: data['address'] ?? '',
      address2: data['address2'] ?? '',
      birthDate: data['birth_date'] ?? '',
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
      'email2': email2,
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
