import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'edit_profile_screen.dart';
import 'profile_api.dart';
import 'profile_theme.dart';
import 'student_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.onSignedOut});

  final ProfileApi api;

  /// تُستدعى بعد تسجيل الخروج أو عند 401 (ارجعي فيها لشاشة تسجيل الدخول)
  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StudentProfile? _profile;
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
      final p = await widget.api.getMe();
      if (!mounted) return;
      changeAppLanguage(p.preferredLanguage); // اللغة المحفوظة بالحساب
      setState(() => _profile = p);
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
    final updated = await Navigator.of(context).push<StudentProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          api: widget.api,
          profile: _profile!,
          onSessionExpired: widget.onSignedOut,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    changeAppLanguage(updated.preferredLanguage);
    setState(() => _profile = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('تم حفظ التعديلات بنجاح', 'Changes saved successfully'))),
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
    if (_loading && _profile == null) {
      return const Center(child: CircularProgressIndicator(color: pNeonCyan));
    }
    if (_profile == null) {
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
    final p = _profile!;
    return RefreshIndicator(
      color: pNeonCyan,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _Header(profile: p, onEdit: _edit),
          const SizedBox(height: 16),
          _InfoCard(profile: p),
          const SizedBox(height: 16),
          _JourneyEmptyState(),
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

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onEdit});
  final StudentProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName.trim();
    final initial = name.isEmpty ? '؟' : String.fromCharCode(name.runes.first);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pBackground,
                  border: Border.all(color: pNeonCyan, width: 1.6),
                  boxShadow: [
                    BoxShadow(color: pNeonBlue.withValues(alpha: 0.35), blurRadius: 18),
                  ],
                ),
                child: Text(initial,
                    style: const TextStyle(
                        color: pNeonCyan, fontSize: 28, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? unspecifiedLabel : name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _meta(Icons.account_balance_outlined,
                        profile.university ?? unspecifiedLabel),
                    const SizedBox(height: 4),
                    _meta(Icons.school_outlined, studyYearLabel(profile.studyYear)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18, color: pNeonCyan),
              label: Text(tr('تعديل الملف', 'Edit profile'),
                  style: const TextStyle(color: pNeonCyan)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: pNeonCyan),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: pMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(color: pMuted, fontSize: 13.5)),
          ),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile});
  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (Icons.person_outline, tr('الاسم', 'Name'), profile.fullName.trim().isEmpty ? unspecifiedLabel : profile.fullName),
      (Icons.mail_outline, tr('البريد الإلكتروني', 'Email'), profile.email.isEmpty ? unspecifiedLabel : profile.email),
      (Icons.account_balance_outlined, tr('الجامعة', 'University'), profile.university ?? unspecifiedLabel),
      (Icons.school_outlined, tr('السنة الدراسية', 'Study year'), studyYearLabel(profile.studyYear)),
      (Icons.language, tr('اللغة المفضلة', 'Preferred language'), languageLabel(profile.preferredLanguage)),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('معلوماتي', 'My information'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: pDivider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(rows[i].$1, size: 20, color: pNeonCyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$2,
                            style: const TextStyle(color: pMuted, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(rows[i].$3,
                            style: const TextStyle(color: Colors.white, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// حالة فارغة بتصميم المحطات. باك التقدّم مؤجّل، فلا توجد نسب أو نتائج.
/// لاحقًا استبدلي هذا الـ widget بالمحطات الحقيقية القادمة من الـ API.
class _JourneyEmptyState extends StatelessWidget {
  _JourneyEmptyState();

  static List<(IconData, String)> get _stations => [
        (Icons.favorite_border, tr('التشريح', 'Anatomy')),
        (Icons.monitor_heart_outlined, tr('وظائف الأعضاء', 'Physiology')),
        (Icons.description_outlined, tr('الاختبارات', 'Exams')),
        (Icons.medical_services_outlined, tr('التدريب السريري', 'Clinical training')),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(tr('رحلتي بالتعلّم', 'My learning journey'),
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _stations.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Container(height: 1, color: pDivider),
                    ),
                  ),
                SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: pDivider, width: 1.4),
                        ),
                        child: Icon(_stations[i].$1, size: 20, color: pMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(_stations[i].$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: pMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
                tr('سيظهر تقدّمك هنا عند بدء الأنشطة التعليمية',
                    'Your progress will appear here once you start learning activities'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: pMuted, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
