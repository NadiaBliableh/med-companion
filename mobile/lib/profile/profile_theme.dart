import 'package:flutter/material.dart';

import '../l10n/app_language.dart';

// نفس ألوان شاشة Create account
const Color pBackground = Color(0xFF050608);
const Color pField = Color(0xFF031725);
const Color pNeonBlue = Color(0xFF00BFFF);
const Color pNeonCyan = Color(0xFF32DFFF);
const Color pMuted = Color(0xFF9DB8CB);
const Color pDivider = Color(0xFF07536B);

// ألوان تصميم البروفايل الجديد
const Color pTeal = Color(0xFF4FD1C5);
const Color pCard = Color(0xFF0D1520);
const Color pCardBorder = Color(0xFF1C2A38);
const Color pTrack = Color(0xFF1E2A36);

String get unspecifiedLabel => tr('غير محدد', 'Not specified');

const _years = ['الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة'];

String studyYearLabel(int? year) {
  if (year == null || year < 1 || year > 6) return unspecifiedLabel;
  return tr('السنة ${_years[year - 1]}', 'Year $year');
}

String languageLabel(String code) => code == 'en' ? 'English' : 'العربية';

BoxDecoration cardDecoration() => BoxDecoration(
      color: pCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: pCardBorder, width: 1),
    );

/// ثواني -> 7h 45m / 7 س 45 د
String formatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return tr('$h س $m د', '${h}h ${m}m');
  return tr('$m د', '${m}m');
}

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF020914), pBackground, Color(0xFF010306)],
          ),
        ),
        child: child,
      );
}
