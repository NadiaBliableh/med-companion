/// GET /learning/subjects  و  GET /learning/subjects/{id}/outline
/// العناوين من الباك إنجليزية دائمًا (حسب التوثيق).

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

class Subject {
  const Subject({
    required this.id,
    required this.title,
    required this.description,
    required this.topicsCount,
    required this.lessonsCount,
    required this.availableLessonsCount,
  });

  final int id;
  final String title;
  final String? description;
  final int topicsCount;
  final int lessonsCount;
  final int availableLessonsCount;

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: _int(j['id']),
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        topicsCount: _int(j['topics_count']),
        lessonsCount: _int(j['lessons_count']),
        availableLessonsCount: _int(j['available_lessons_count']),
      );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.status,
    required this.isAvailable,
  });

  final int id;
  final String title;
  final String? description; // قد تكون null
  final int displayOrder;
  final String status; // not_started | in_progress | completed (تقدّم الطالب فقط)
  final bool isAvailable; // جاهز للدراسة؟ مستقل عن status

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: _int(j['id']),
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        displayOrder: _int(j['display_order']),
        status: (j['status'] ?? 'not_started') as String,
        isAvailable: (j['is_available'] ?? false) as bool,
      );
}

class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.lessonsCount,
    required this.availableLessonsCount,
    required this.completedLessons,
    required this.progressPercentage,
    required this.lessons,
  });

  final int id;
  final String title;
  final String? description;
  final int displayOrder;
  final int lessonsCount;
  final int availableLessonsCount;
  final int completedLessons;
  final double progressPercentage; // 0-100
  final List<Lesson> lessons;

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        id: _int(j['id']),
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        displayOrder: _int(j['display_order']),
        lessonsCount: _int(j['lessons_count']),
        availableLessonsCount: _int(j['available_lessons_count']),
        completedLessons: _int(j['completed_lessons']),
        progressPercentage: (j['progress_percentage'] as num?)?.toDouble() ?? 0,
        lessons: ((j['lessons'] as List?) ?? const [])
            .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SubjectOutline {
  const SubjectOutline({
    required this.id,
    required this.title,
    required this.description,
    required this.topics,
  });

  final int id;
  final String title;
  final String? description;
  final List<Topic> topics;

  factory SubjectOutline.fromJson(Map<String, dynamic> j) => SubjectOutline(
        id: _int(j['id']),
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        topics: ((j['topics'] as List?) ?? const [])
            .map((e) => Topic.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
