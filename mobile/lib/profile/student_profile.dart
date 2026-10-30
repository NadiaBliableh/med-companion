class StudentProfile {
  const StudentProfile({
    required this.fullName,
    required this.email,
    required this.preferredLanguage,
    this.university,
    this.studyYear,
  });

  final String fullName;
  final String email; // للعرض فقط
  final String? university;
  final int? studyYear;
  final String preferredLanguage; // 'ar' | 'en'

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    // في حال كان الرد ملفوفًا داخل مفتاح student
    final data = json['student'] is Map<String, dynamic>
        ? json['student'] as Map<String, dynamic>
        : json;
    return StudentProfile(
      fullName: (data['full_name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      university: data['university'] as String?,
      studyYear: data['study_year'] as int?,
      preferredLanguage: (data['preferred_language'] ?? 'ar') as String,
    );
  }
}
