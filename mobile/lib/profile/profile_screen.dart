import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'edit_profile_screen.dart';
import 'profile_api.dart';
import 'profile_overview.dart';
import 'profile_theme.dart';
import 'student_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.api,
    required this.onSignedOut,
    this.onOpenLesson,
  });

  final ProfileApi api;

  /// تُستدعى بعد تسجيل الخروج أو عند 401 (ارجعي فيها لشاشة تسجيل الدخول)
  final VoidCallback onSignedOut;

  /// افتحي فيها شاشة الدرس (lesson.lessonId). إذا null بنعرض رسالة "قريبًا".
  final void Function(ContinueLearning lesson)? onOpenLesson;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileOverview? _overview;
  StudentProfile? _student; // للتعديل (الإيميل والجامعة)
  bool _loading = true;
  bool _loggingOut = false;
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
      final r = await Future.wait<Object>([
        widget.api.getOverview(),
        widget.api.getMe(),
      ]);
      if (!mounted) return;
      final overview = r[0] as ProfileOverview;
      changeAppLanguage(overview.preferredLanguage); // اللغة المحفوظة بالحساب
      setState(() {
        _overview = overview;
        _student = r[1] as StudentProfile;
      });
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

  Future<void> _edit() async {
    if (_student == null) return;
    final updated = await Navigator.of(context).push<StudentProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          api: widget.api,
          profile: _student!,
          onSessionExpired: widget.onSignedOut,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    changeAppLanguage(updated.preferredLanguage);
    setState(() => _student = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('تم حفظ التعديلات بنجاح', 'Changes saved successfully'))),
    );
    _load(); // الاسم/السنة/عناوين الدروس (حسب اللغة) تتحدّث من الباك
  }

  void _openLesson(ContinueLearning lesson) {
    if (widget.onOpenLesson != null) {
      widget.onOpenLesson!(lesson);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('شاشة الدرس قيد التطوير', 'Lesson screen is coming soon'))),
    );
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await widget.api.logout();
    if (mounted) widget.onSignedOut();
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
    if (_loading && _overview == null) {
      return const Center(child: CircularProgressIndicator(color: pTeal));
    }
    final o = _overview;
    if (o == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? tr('تعذّر تحميل الملف الشخصي.', 'Could not load your profile.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: Text(tr('إعادة المحاولة', 'Retry'))),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: pTeal,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _TopBar(),
          const SizedBox(height: 12),
          _Header(overview: o, onEdit: _edit),
          const SizedBox(height: 16),
          _StatsCard(overview: o),
          const SizedBox(height: 16),
          _ContinueCard(data: o.continueLearning, onContinue: _openLesson),
          const SizedBox(height: 16),
          _WeekCard(days: o.weekly),
          const SizedBox(height: 16),
          _LinksCard(
            language: o.preferredLanguage,
            savedCount: o.savedLessonsCount,
            onLanguageTap: _edit,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _loggingOut ? null : _logout,
              icon: _loggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout, color: Colors.redAccent),
              label: Text(tr('تسجيل الخروج', 'Log out'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- top bar

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(tr('الملف الشخصي', 'Profile'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
          if (canPop)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- header

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '؟';
  return parts.take(2).map((p) => String.fromCharCode(p.runes.first)).join().toUpperCase();
}

class _Header extends StatelessWidget {
  const _Header({required this.overview, required this.onEdit});
  final ProfileOverview overview;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = overview.fullName.trim();
    final role = tr('طالب طب', 'Medical Student');
    final subtitle = overview.studyYear == null
        ? role
        : '$role • ${studyYearLabel(overview.studyYear)}';
    return Row(
      children: [
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2B9C99)),
          child: Text(_initials(name),
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? unspecifiedLabel : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: pMuted, fontSize: 14)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16, color: pTeal),
                label: Text(tr('تعديل الملف', 'Edit profile'),
                    style: const TextStyle(color: pTeal, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: pTeal),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ stats

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.overview});
  final ProfileOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: cardDecoration(),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                icon: Icons.local_fire_department,
                color: const Color(0xFFFF6B4A),
                value: '${overview.streakDays}',
                label: tr('أيام متتالية', 'Day streak'),
              ),
            ),
            const VerticalDivider(width: 1, color: pCardBorder),
            Expanded(
              child: _Stat(
                icon: Icons.schedule,
                color: pTeal,
                value: formatDuration(overview.totalStudySeconds),
                label: tr('وقت الدراسة', 'Studied'),
              ),
            ),
            const VerticalDivider(width: 1, color: pCardBorder),
            Expanded(
              child: _Stat(
                icon: Icons.bar_chart,
                color: pTeal,
                value: '${overview.overallProgress.round()}%',
                label: tr('التقدّم العام', 'Overall progress'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: pMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- continue learning

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.data, required this.onContinue});
  final ContinueLearning? data;
  final void Function(ContinueLearning) onContinue;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('تابع التعلّم', 'Continue learning'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          if (d == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(tr('لا يوجد درس حالي', 'No current lesson'),
                  style: const TextStyle(color: pMuted, fontSize: 14)),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // thumbnail_url دائمًا null حاليًا: أيقونة بديلة
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: pField,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: pCardBorder),
                  ),
                  child: const Icon(Icons.favorite_border, color: pTeal, size: 38),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.subjectTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: pMuted, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(d.lessonTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        tr('الدرس ${d.lessonOrder} من ${d.lessonsCount}',
                            'Lesson ${d.lessonOrder} of ${d.lessonsCount}'),
                        style: const TextStyle(color: pMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (d.topicProgress / 100).clamp(0.0, 1.0).toDouble(),
                                minHeight: 8,
                                backgroundColor: pTrack,
                                valueColor: const AlwaysStoppedAnimation<Color>(pTeal),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${d.topicProgress.round()}%',
                              style: const TextStyle(color: pMuted, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => onContinue(d),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pTeal,
                  foregroundColor: const Color(0xFF04121A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      d.status == 'not_started'
                          ? tr('ابدأ الدرس', 'Start lesson')
                          : tr('تابع الدرس', 'Continue lesson'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- this week

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.days});
  final List<DayActivity> days;

  static const _en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _ar = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

  String _letter(int weekday) {
    final i = (weekday - 1).clamp(0, 6);
    return tr(_ar[i], _en[i]);
  }

  @override
  Widget build(BuildContext context) {
    final total = days.fold<int>(0, (sum, d) => sum + d.studySeconds);
    final maxSec = days.fold<int>(0, (m, d) => d.studySeconds > m ? d.studySeconds : m);
    const barHeight = 80.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('هذا الأسبوع', 'This week'),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              Text(formatDuration(total),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text(tr('تركيز', 'focused'),
                  style: const TextStyle(color: pMuted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: barHeight,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: pTrack,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: d.studySeconds > 0 && maxSec > 0
                            ? Container(
                                width: 22,
                                height: (barHeight * d.studySeconds / maxSec)
                                    .clamp(6.0, barHeight)
                                    .toDouble(),
                                decoration: BoxDecoration(
                                  color: pTeal,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(_letter(d.weekday),
                          style: const TextStyle(color: pMuted, fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ links

class _LinksCard extends StatelessWidget {
  const _LinksCard({
    required this.language,
    required this.savedCount,
    required this.onLanguageTap,
  });
  final String language;
  final int savedCount;
  final VoidCallback onLanguageTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      child: Column(
        children: [
          _LinkRow(
            icon: Icons.language,
            title: tr('لغة الدراسة', 'Study language'),
            trailing: languageLabel(language),
            showChevron: true,
            onTap: onLanguageTap,
          ),
          const Divider(height: 1, color: pCardBorder),
          _LinkRow(
            icon: Icons.bookmark_border,
            title: tr('الدروس المحفوظة', 'Saved lessons'),
            trailing: '$savedCount',
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.trailing,
    this.showChevron = false,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: pMuted, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
            Text(trailing, style: const TextStyle(color: pMuted, fontSize: 14)),
            if (showChevron) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: pMuted, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}
