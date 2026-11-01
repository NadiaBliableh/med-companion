import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../learn/learn_home_screen.dart';
import '../profile/profile_api.dart';
import '../profile/profile_screen.dart';
import '../profile/profile_theme.dart';
import '../services/auth_service.dart';

/// الإطار الرئيسي بعد تسجيل الدخول: تابات Learn و Profile.
/// (Home وPractice وAI Tutor تنضاف لما تجهز شاشاتها.)
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.loginBuilder});

  /// ارجعي منه LoginScreen (موجودة بـ main.dart)
  final Widget Function() loginBuilder;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final ProfileApi _api;
  int _index = 0; // 0 = Learn, 1 = Profile

  @override
  void initState() {
    super.initState();
    _api = ProfileApi(
      baseUrl: AuthService.baseUrl,
      readToken: () async => AuthService.accessToken,
      clearToken: () async => AuthService.accessToken = null,
    );
    appLanguage.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    appLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _signedOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => widget.loginBuilder()),
      (route) => false,
    );
  }

  // الصفحة تنبني من جديد عند تبديل التاب، فالبيانات تنطلب كل مرة تنفتح الشاشة
  Widget _page() => _index == 0
      ? LearnHomeScreen(key: const ValueKey('learn'), api: _api, onSignedOut: _signedOut)
      : ProfileScreen(key: const ValueKey('profile'), api: _api, onSignedOut: _signedOut);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: appTextDirection,
      child: Scaffold(
        body: _page(),
        bottomNavigationBar: NavigationBar(
          backgroundColor: pCard,
          indicatorColor: pTeal.withValues(alpha: 0.18),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined, color: pMuted),
              selectedIcon: const Icon(Icons.menu_book, color: pTeal),
              label: tr('تعلّم', 'Learn'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline, color: pMuted),
              selectedIcon: const Icon(Icons.person, color: pTeal),
              label: tr('الملف الشخصي', 'Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
