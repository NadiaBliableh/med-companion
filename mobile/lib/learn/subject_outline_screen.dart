import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../profile/profile_api.dart';
import '../profile/profile_theme.dart';
import 'learn_models.dart';
import 'learn_service.dart';
import 'learn_widgets.dart';

/// GET /learning/subjects/{id}/outline : الوحدات (topics) ودروسها.
class SubjectOutlineScreen extends StatefulWidget {
  const SubjectOutlineScreen({
    super.key,
    required this.api,
    required this.subjectId,
    required this.subjectTitle,
    required this.onSignedOut,
    this.onOpenLesson,
  });

  final ProfileApi api;
  final int subjectId; // من رد /learning/subjects
  final String subjectTitle; // يظهر أثناء التحميل
  final VoidCallback onSignedOut;

  /// افتحي فيها شاشة الدرس. تُستدعى فقط للدروس is_available == true.
  final void Function(Lesson lesson)? onOpenLesson;

  @override
  State<SubjectOutlineScreen> createState() => _SubjectOutlineScreenState();
}

class _SubjectOutlineScreenState extends State<SubjectOutlineScreen> {
  late final LearnService _service = LearnService(widget.api);
  SubjectOutline? _outline;
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
      final outline = await _service.getOutline(widget.subjectId);
      if (mounted) setState(() => _outline = outline);
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

  void _openLesson(Lesson lesson) {
    if (!lesson.isAvailable) return; // لا نفتح شي للدروس غير المتاحة
    if (widget.onOpenLesson != null) {
      widget.onOpenLesson!(lesson);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('شاشة الدرس قيد التطوير', 'Lesson screen is coming soon'))),
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

  Widget _backRow() => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: pTeal, size: 20),
          label: Text(tr('تعلّم', 'Learn'),
              style: const TextStyle(color: pTeal, fontSize: 16)),
        ),
      );

  Widget _body() {
    final outline = _outline;
    if (outline == null) {
      return Column(
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: _backRow()),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: pTeal))
                : ErrorRetry(
                    message: _error ?? tr('تعذّر تحميل الوحدات.', 'Could not load units.'),
                    retryLabel: tr('إعادة المحاولة', 'Retry'),
                    onRetry: _load,
                  ),
          ),
        ],
      );
    }
    final hasDescription = (outline.description ?? '').trim().isNotEmpty;
    return RefreshIndicator(
      color: pTeal,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _backRow(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(outline.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                if (hasDescription) ...[
                  const SizedBox(height: 6),
                  Text(outline.description!,
                      style: const TextStyle(color: pMuted, fontSize: 15)),
                ],
                const SizedBox(height: 24),
                Text(tr('الوحدات', 'Units'),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (outline.topics.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: cardDecoration(),
              child: Text(tr('لا توجد وحدات بعد.', 'No units yet.'),
                  style: const TextStyle(color: pMuted, fontSize: 15)),
            )
          else
            for (final t in outline.topics) ...[
              _TopicCard(topic: t, onLesson: _openLesson),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.onLesson});
  final Topic topic;
  final void Function(Lesson) onLesson;

  @override
  Widget build(BuildContext context) {
    final order = topic.displayOrder.toString().padLeft(2, '0');
    final hasDescription = (topic.description ?? '').trim().isNotEmpty;
    final hasAvailable = topic.availableLessonsCount > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tr('الوحدة', 'UNIT')} $order',
              style: const TextStyle(color: pMuted, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(topic.title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          if (hasDescription) ...[
            const SizedBox(height: 4),
            Text(topic.description!, style: const TextStyle(color: pMuted, fontSize: 14)),
          ],
          const SizedBox(height: 14),
          if (hasAvailable)
            _TopicProgress(topic: topic)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(label: tr('قريبًا', 'Coming soon')),
InfoChip(label: tr('الدروس: ${topic.lessonsCount}',
    topic.lessonsCount == 1 ? '1 lesson' : '${topic.lessonsCount} lessons')),
     ],
            ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: pCardBorder),
          for (var i = 0; i < topic.lessons.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: pCardBorder),
            _LessonTile(lesson: topic.lessons[i], onTap: () => onLesson(topic.lessons[i])),
          ],
        ],
      ),
    );
  }
}

class _TopicProgress extends StatelessWidget {
  const _TopicProgress({required this.topic});
  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final done = topic.completedLessons;
    final total = topic.availableLessonsCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('$done من $total دروس مكتملة', '$done of $total lessons completed'),
                style: const TextStyle(color: pMuted, fontSize: 13.5),
              ),
            ),
            Text('${topic.progressPercentage.round()}%',
                style: const TextStyle(
                    color: pTeal, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (topic.progressPercentage / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: pTrack,
            valueColor: const AlwaysStoppedAnimation<Color>(pTeal),
          ),
        ),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.onTap});
  final Lesson lesson;
  final VoidCallback onTap;

  Widget _status() {
    if (!lesson.isAvailable) {
      return InfoChip(label: tr('قريبًا', 'Coming soon'));
    }
    switch (lesson.status) {
      case 'completed':
        return InfoChip(highlight: true, label: tr('مكتمل', 'Completed'));
      case 'in_progress':
        return InfoChip(highlight: true, label: tr('قيد التعلّم', 'In progress'));
      default:
        return InfoChip(label: tr('لم يبدأ', 'Not started'));
    }
  }

  String _action() {
    switch (lesson.status) {
      case 'completed':
        return tr('مراجعة', 'Review');
      case 'in_progress':
        return tr('تابع', 'Continue');
      default:
        return tr('ابدأ', 'Start');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription = (lesson.description ?? '').trim().isNotEmpty;
    final available = lesson.isAvailable;
    return Opacity(
      opacity: available ? 1 : 0.6,
      child: InkWell(
        onTap: available ? onTap : null, // غير المتاح: زر معطّل
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pTrack,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(lesson.displayOrder.toString().padLeft(2, '0'),
                    style: const TextStyle(color: pMuted, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    if (hasDescription) ...[
                      const SizedBox(height: 2),
                      Text(lesson.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: pMuted, fontSize: 13)),
                    ],
                    const SizedBox(height: 8),
                    _status(),
                  ],
                ),
              ),
              if (available) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Text(_action(),
                          style: const TextStyle(
                              color: pTeal, fontSize: 14, fontWeight: FontWeight.w600)),
                      const Icon(Icons.chevron_right, color: pTeal, size: 20),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
