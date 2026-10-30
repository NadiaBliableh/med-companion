import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'profile_api.dart';
import 'profile_theme.dart';
import 'student_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.api,
    required this.profile,
    required this.onSessionExpired,
  });

  final ProfileApi api;
  final StudentProfile profile;
  final VoidCallback onSessionExpired;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _university;
  late int? _year;
  late String _lang;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile; // الحقول تُملأ بالبيانات الحالية
    _name = TextEditingController(text: p.fullName);
    _university = TextEditingController(text: p.university ?? '');
    _year = p.studyYear;
    _lang = p.preferredLanguage == 'en' ? 'en' : 'ar';
    appLanguage.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appLanguage.removeListener(_onLanguageChanged);
    _name.dispose();
    _university.dispose();
    super.dispose();
  }

  /// الحقول التي تغيّرت فقط. null = مسح الحقل.
  Map<String, dynamic> _changes() {
    final p = widget.profile;
    final changes = <String, dynamic>{};
    final name = _name.text.trim();
    if (name != p.fullName) changes['full_name'] = name;
    final uni = _university.text.trim();
    final newUni = uni.isEmpty ? null : uni;
    if (newUni != p.university) changes['university'] = newUni;
    if (_year != p.studyYear) changes['study_year'] = _year;
    if (_lang != p.preferredLanguage) changes['preferred_language'] = _lang;
    return changes;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final changes = _changes();
    if (changes.isEmpty) {
      Navigator.of(context).pop(); // لا تغييرات، لا طلب
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.api.updateMe(changes);
      if (!mounted) return;
      Navigator.of(context).pop(updated); // الشاشة السابقة تتحدّث من الرد
    } on UnauthorizedException {
      await widget.api.clearToken();
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSessionExpired();
    } on ApiException catch (e) {
      // نحتفظ بالمدخلات ونعرض الخطأ
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: pMuted),
        filled: true,
        fillColor: pField.withValues(alpha: 0.78),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: pNeonBlue, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: pNeonCyan, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: appTextDirection,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(tr('تعديل الملف', 'Edit profile')),
        ),
        body: GradientBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: pNeonCyan,
                          decoration: _decoration(tr('الاسم الكامل', 'Full name')),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? tr('الاسم مطلوب', 'Name is required')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _university,
                          enabled: !_saving,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: pNeonCyan,
                          decoration: _decoration(tr('الجامعة', 'University')),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int?>(
                          initialValue: _year,
                          dropdownColor: pField,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _decoration(tr('السنة الدراسية', 'Study year')),
                          items: [
                            DropdownMenuItem<int?>(
                                value: null, child: Text(unspecifiedLabel)),
                            for (var y = 1; y <= 6; y++)
                              DropdownMenuItem<int?>(
                                  value: y, child: Text(studyYearLabel(y))),
                          ],
                          onChanged: _saving ? null : (v) => setState(() => _year = v),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _lang,
                          dropdownColor: pField,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: _decoration(tr('اللغة المفضلة', 'Preferred language')),
                          items: const [
                            DropdownMenuItem(value: 'ar', child: Text('العربية')),
                            DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                          onChanged:
                              _saving ? null : (v) => setState(() => _lang = v ?? 'ar'),
                        ),
                        const SizedBox(height: 14),
                        // الإيميل للعرض فقط
                        InputDecorator(
                          decoration: _decoration(tr('البريد الإلكتروني (لا يمكن تعديله)', 'Email (cannot be changed)')),
                          child: Text(widget.profile.email,
                              style: const TextStyle(color: pMuted)),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF079ACB),
                              disabledBackgroundColor:
                                  const Color(0xFF079ACB).withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32)),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4, color: Colors.white),
                                  )
                                : Text(tr('حفظ التعديلات', 'Save changes'),
                                    style: const TextStyle(fontSize: 17, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
