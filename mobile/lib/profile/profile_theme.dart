import 'package:flutter/material.dart';

import '../l10n/app_language.dart';

// نفس ألوان شاشة Create account
const Color pBackground = Color(0xFF050608);
const Color pField = Color(0xFF031725);
const Color pNeonBlue = Color(0xFF00BFFF);
const Color pNeonCyan = Color(0xFF32DFFF);
const Color pMuted = Color(0xFF9DB8CB);
const Color pDivider = Color(0xFF07536B);

String get unspecifiedLabel => tr('غير محدد', 'Not specified');

const _years = ['الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة'];

String studyYearLabel(int? year) {
  if (year == null || year < 1 || year > 6) return unspecifiedLabel;
  return tr('السنة ${_years[year - 1]}', 'Year $year');
}

String languageLabel(String code) => code == 'en' ? 'English' : 'العربية';

BoxDecoration cardDecoration() => BoxDecoration(
      color: pField.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: pNeonBlue.withValues(alpha: 0.55), width: 1),
    );

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
