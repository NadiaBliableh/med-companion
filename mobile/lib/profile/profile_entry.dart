import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'profile_api.dart';
import 'profile_screen.dart';

/// نقطة الدخول لشاشة البروفايل: تربطها بـ AuthService الموجود.
/// loginBuilder: ارجعي منه LoginScreen (موجودة بـ main.dart).
class ProfileEntry extends StatelessWidget {
  const ProfileEntry({super.key, required this.loginBuilder});

  final Widget Function() loginBuilder;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => ProfileScreen(
        api: ProfileApi(
          baseUrl: AuthService.baseUrl,
          readToken: () async => AuthService.accessToken,
          clearToken: () async => AuthService.accessToken = null,
        ),
        onSignedOut: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => loginBuilder()),
          (route) => false,
        ),
      ),
    );
  }
}
