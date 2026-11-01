import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../profile/profile_api.dart';
import '../profile/profile_theme.dart';
import 'learn_models.dart';
import 'learn_service.dart';
import 'learn_widgets.dart';
import 'subject_outline_screen.dart';

/// شاشة Learn الرئيسية: GET /learning/subjects
class LearnHomeScreen extends StatefulWidget {
  const LearnHomeScreen({super.key, required this.api, required this.onSignedOut});

  final ProfileApi api;
  final VoidCallback onSignedOut;

  @override
  State<LearnHomeScreen> createState() => _LearnHomeScreenState();
}

class _LearnHomeScreenState extends State<LearnHomeScreen> {
  late final LearnService _service = LearnService(widget.api);
  List<Subject>? _subjects;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    appLanguage.addListener(_onLanguageChanged);
    _load();
  }

  @override
  void dispose() {
    appLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subjects = await _service.getSubjects();
      if (mounted) setState(() => _subjects = subjects);
    } on UnauthorizedException {
      await widget.api.clearToken();
      if (mounted) widget.onSignedOut();
      return;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Subject s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubjectOutlineScreen(
          api: widget.api,
          subjectId: s.id,
          subjectTitle: s.title,
          onSignedOut: widget.onSignedOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: appTextDirection,
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _body(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _subjects == null) {
      return const Center(child: CircularProgressIndicator(color: pTeal));
    }
    final subjects = _subjects;
    if (subjects == null) {
      return ErrorRetry(
        message: _error ?? tr('تعذّر تحميل المواد.', 'Could not load subjects.'),
        retryLabel: tr('إعادة المحاولة', 'Retry'),
        onRetry: _load,
      );
    }
    return RefreshIndicator(
      color: pTeal,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const Text('MED COMPANION',
              style: TextStyle(color: pMuted, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 6),
          Text(tr('تعلّم', 'Learn'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            tr('ابنِ فهمك درسًا بعد درس.', 'Build your understanding, one lesson at a time.'),
            style: const TextStyle(color: pMuted, fontSize: 15),
          ),
          const SizedBox(height: 28),
          Text(tr('المواد', 'Your subjects'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: cardDecoration(),
              child: Text(
                tr('لا توجد مواد حاليًا.', 'No subjects yet.'),
                style: const TextStyle(color: pMuted, fontSize: 15),
              ),
            )
          else
            for (final s in subjects) ...[
              _SubjectCard(subject: s, onOpen: () => _open(s)),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.onOpen});
  final Subject subject;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hasDescription = (subject.description ?? '').trim().isNotEmpty;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // thumbnail_url دائمًا null حاليًا: خلفية بديلة
          Container(
            height: 140,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2A33), pCard],
              ),
            ),
            child: Center(
              child: Icon(Icons.favorite, size: 64, color: pTeal.withValues(alpha: 0.85)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
                if (hasDescription) ...[
                  const SizedBox(height: 4),
                  Text(subject.description!,
                      style: const TextStyle(color: pMuted, fontSize: 14)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoChip(label: tr('الوحدات: ${subject.topicsCount}', '${subject.topicsCount} units')),
                    InfoChip(label: tr('الدروس: ${subject.lessonsCount}', '${subject.lessonsCount} lessons')),
                    subject.availableLessonsCount > 0
                        ? InfoChip(
                            highlight: true,
                            label: tr('${subject.availableLessonsCount} دروس متاحة',
                                '${subject.availableLessonsCount} lessons available'))
                        : InfoChip(label: tr('قريبًا', 'Coming soon')),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pTeal,
                      foregroundColor: const Color(0xFF04121A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(tr('تصفّح الوحدات', 'Browse units'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
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
