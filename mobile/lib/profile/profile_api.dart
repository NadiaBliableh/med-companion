import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_language.dart';
import 'student_profile.dart';

/// Android Emulator -> 10.0.2.2 ، المتصفح وباقي المنصات -> 127.0.0.1
String defaultApiBaseUrl() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8001';
  }
  return 'http://127.0.0.1:8001';
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 401: الجلسة غير صالحة
class UnauthorizedException extends ApiException {
  UnauthorizedException() : super(tr('انتهت الجلسة، سجّلي الدخول من جديد.', 'Your session has expired. Please log in again.'));
}

/// 422: بيانات غير مقبولة
class ValidationException extends ApiException {
  ValidationException(super.message);
}

class ProfileApi {
  ProfileApi({
    required this.baseUrl,
    required this.readToken,
    required this.clearToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;

  /// يرجّع access_token المحفوظ محليًا (أو null)
  final Future<String?> Function() readToken;

  /// يمسح التوكن المحلي
  final Future<void> Function() clearToken;

  final http.Client _client;

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await readToken();
    if (token == null || token.isEmpty) throw UnauthorizedException();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _run(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 15));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(tr('تعذّر الاتصال بالخادم. تأكدي من الاتصال وحاولي مجددًا.',
          'Could not reach the server. Check your connection and try again.'));
    }
    if (res.statusCode == 401) throw UnauthorizedException();
    if (res.statusCode == 403) throw ApiException(tr('هذا الحساب ليس حساب طالب.', 'This account is not a student account.'));
    if (res.statusCode == 404) throw ApiException(tr('لم يتم العثور على الملف الطلابي.', 'Student profile not found.'));
    if (res.statusCode == 422) throw ValidationException(_validationMessage(res));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(tr('حدث خطأ غير متوقع (${res.statusCode}).', 'Unexpected error (${res.statusCode}).'));
    }
    return res;
  }

  String _validationMessage(http.Response res) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final detail = body is Map ? body['detail'] : null;
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        return detail
            .map((e) => e is Map ? (e['msg'] ?? '').toString() : e.toString())
            .where((m) => m.isNotEmpty)
            .join('\n');
      }
    } catch (_) {}
    return tr('البيانات المدخلة غير مقبولة.', 'The submitted data was not accepted.');
  }

  StudentProfile _parse(http.Response res) =>
      StudentProfile.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);

  /// GET /students/me
  Future<StudentProfile> getMe() async {
    final headers = await _headers();
    final res = await _run(
      () => _client.get(Uri.parse('$baseUrl/students/me'), headers: headers),
    );
    return _parse(res);
  }

  /// PATCH /students/me — أرسلي الحقول المتغيّرة فقط.
  /// المفاتيح المسموحة: full_name, university, study_year, preferred_language
  /// القيمة null تمسح الحقل (للجامعة والسنة).
  Future<StudentProfile> updateMe(Map<String, dynamic> changes) async {
    final headers = await _headers(json: true);
    final res = await _run(
      () => _client.patch(
        Uri.parse('$baseUrl/students/me'),
        headers: headers,
        body: jsonEncode(changes),
      ),
    );
    return _parse(res);
  }

  /// POST /auth/logout ثم مسح التوكن المحلي (يُمسح حتى لو فشل الطلب)
  Future<void> logout() async {
    try {
      final headers = await _headers();
      await _run(
        () => _client.post(Uri.parse('$baseUrl/auth/logout'), headers: headers),
      );
    } on ApiException {
      // الجلسة منتهية أو لا اتصال: نكمّل بتسجيل الخروج محليًا
    } finally {
      await clearToken();
    }
  }
}
