/// GET /students/me/profile-overview
class DayActivity {
  const DayActivity({required this.date, required this.studySeconds});

  final String date; // YYYY-MM-DD
  final int studySeconds;

  factory DayActivity.fromJson(Map<String, dynamic> json) => DayActivity(
        date: (json['date'] ?? '') as String,
        studySeconds: (json['study_seconds'] as num?)?.toInt() ?? 0,
      );

  /// 1 = الاثنين ... 7 = الأحد
  int get weekday => DateTime.tryParse(date)?.weekday ?? 1;
}

class ContinueLearning {
  const ContinueLearning({
    required this.lessonId,
    required this.subjectTitle,
    required this.topicTitle,
    required this.lessonTitle,
    required this.lessonOrder,
    required this.lessonsCount,
    required this.status,
    required this.topicProgress,
  });

  final int lessonId;
  final String subjectTitle; // العناوين تجي من الباك باللغة المختارة
  final String topicTitle;
  final String lessonTitle;
  final int lessonOrder;
  final int lessonsCount;
  final String status; // in_progress | not_started
  final double topicProgress; // 0-100

  factory ContinueLearning.fromJson(Map<String, dynamic> json) => ContinueLearning(
        lessonId: (json['lesson_id'] as num?)?.toInt() ?? 0,
        subjectTitle: (json['subject_title'] ?? '') as String,
        topicTitle: (json['topic_title'] ?? '') as String,
        lessonTitle: (json['lesson_title'] ?? '') as String,
        lessonOrder: (json['lesson_order'] as num?)?.toInt() ?? 0,
        lessonsCount: (json['lessons_count'] as num?)?.toInt() ?? 0,
        status: (json['status'] ?? 'not_started') as String,
        topicProgress: (json['topic_progress_percentage'] as num?)?.toDouble() ?? 0,
      );
}

class ProfileOverview {
  const ProfileOverview({
    required this.fullName,
    required this.studyYear,
    required this.preferredLanguage,
    required this.streakDays,
    required this.totalStudySeconds,
    required this.overallProgress,
    required this.continueLearning,
    required this.weekly,
    required this.savedLessonsCount,
  });

  final String fullName;
  final int? studyYear;
  final String preferredLanguage;
  final int streakDays;
  final int totalStudySeconds;
  final double overallProgress; // 0-100
  final ContinueLearning? continueLearning; // قد تكون null
  final List<DayActivity> weekly; // 7 أيام
  final int savedLessonsCount;

  factory ProfileOverview.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>?) ?? const {};
    final stats = (json['stats'] as Map<String, dynamic>?) ?? const {};
    final cl = json['continue_learning'];
    final weekly = (json['weekly_activity'] as List?) ?? const [];
    return ProfileOverview(
      fullName: (profile['full_name'] ?? '') as String,
      studyYear: (profile['study_year'] as num?)?.toInt(),
      preferredLanguage: (profile['preferred_language'] ?? 'ar') as String,
      streakDays: (stats['current_streak_days'] as num?)?.toInt() ?? 0,
      totalStudySeconds: (stats['total_study_seconds'] as num?)?.toInt() ?? 0,
      overallProgress: (stats['overall_progress_percentage'] as num?)?.toDouble() ?? 0,
      continueLearning:
          cl is Map<String, dynamic> ? ContinueLearning.fromJson(cl) : null,
      weekly: weekly
          .map((e) => DayActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
      savedLessonsCount: (json['saved_lessons_count'] as num?)?.toInt() ?? 0,
    );
  }
}
