// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

import '../screens/caregiver_home_screen.dart';
import '../screens/home_screen.dart';
import 'auth_service.dart';
import 'user_role.dart';

class RoleRouter {
  static final AuthService _authService = AuthService();

  /// Determine the right home screen for current user.
  /// If user has no role yet (existing accounts), backfill as visionUser.
  static Future<Widget> resolveHomeScreen() async {
    final user = _authService.currentUser;
    if (user == null) {
      // Should not happen in normal flow, but safe fallback
      return const HomeScreen();
    }

    try {
      var role = await _authService.getCurrentUserRole();

      // Backfill missing role for existing accounts (e.g., Samiha)
      if (role == UserRole.unknown) {
        print('No role found, backfilling as vision user');
        await _authService.backfillRoleIfMissing(UserRole.visionUser);
        role = UserRole.visionUser;
      }

      switch (role) {
        case UserRole.visionUser:
          return const HomeScreen();
        case UserRole.caregiver:
          return const CaregiverHomeScreen();
        case UserRole.unknown:
          // Fallback: treat as vision user
          return const HomeScreen();
      }
    } catch (e) {
      print('RoleRouter resolve error: $e');
      return const HomeScreen();
    }
  }

  /// Navigate to the correct home screen, replacing the current route.
  static Future<void> navigateToHome(BuildContext context) async {
    final screen = await resolveHomeScreen();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }
}
