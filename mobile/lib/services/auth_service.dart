import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _webBaseUrl = 'http://127.0.0.1:8001';
  static const String _androidBaseUrl = 'http://10.0.2.2:8001';

  static String get baseUrl =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? _androidBaseUrl
          : _webBaseUrl;

  static String? accessToken;

  static String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final detail = body['detail'];

      if (detail is String) return detail;

      if (detail is List && detail.isNotEmpty) {
        return detail
            .map((item) => item['msg']?.toString() ?? 'Invalid input')
            .join('\n');
      }

      return 'Request failed (${response.statusCode})';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
  }

  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'full_name': fullName.trim(),
            'email': email.trim(),
            'password': password,
            'university': null,
            'study_year': null,
            'preferred_language': 'ar',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_errorMessage(response));
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      accessToken = data['access_token'] as String?;
      return data;
    }

    throw Exception(_errorMessage(response));
  }
}