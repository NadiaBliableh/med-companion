import '../l10n/app_language.dart';
import '../profile/profile_api.dart';
import 'learn_models.dart';

class LearnService {
  LearnService(this.api);
  final ProfileApi api;

  /// GET /learning/subjects  (لا مواد -> قائمة فاضية)
  Future<List<Subject>> getSubjects() async {
    final json = await api.getJson('/learning/subjects') as Map<String, dynamic>;
    return ((json['subjects'] as List?) ?? const [])
        .map((e) => Subject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /learning/subjects/{id}/outline  (id يجي من getSubjects، لا نفترض رقم)
  Future<SubjectOutline> getOutline(int subjectId) async {
    final json = await api.getJson(
      '/learning/subjects/$subjectId/outline',
      notFoundMessage: tr('المادة غير موجودة أو غير منشورة.', 'Subject not found or not published.'),
    ) as Map<String, dynamic>;
    return SubjectOutline.fromJson(json);
  }
}
