import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin_panel/admin_dashboard.dart';
import '../doctor/doctor_home_screen.dart';
import '../secretary/secretary_home_screen.dart';

/// Persists staff login session via [SharedPreferences] (survives app restarts;
/// cleared on uninstall, app data clear, or [clearSession] / logout).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _kLoggedIn = 'auth_is_logged_in';
  static const String _kRole = 'auth_last_role';

  /// Call after any successful login (staff or patient).
  Future<void> persistSession({required String role}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLoggedIn, true);
    await p.setString(_kRole, role.trim().toLowerCase());
  }

  /// Clears persisted flags (call on logout).
  Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLoggedIn);
    await p.remove(_kRole);
  }

  Future<bool> isLoggedInFlag() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kLoggedIn) ?? false;
  }

  Future<String?> lastRole() async {
    final p = await SharedPreferences.getInstance();
    final r = p.getString(_kRole);
    if (r == null || r.isEmpty) return null;
    return r.trim().toLowerCase();
  }

  /// Roles that use Firestore-only login (no Firebase user) — splash can open home directly.
  static const Set<String> staffRolesBypassingAuthGate = {
    'secretary',
    'doctor',
    'admin',
  };

  /// Whether splash should skip [LoginScreen] and open [homeWidgetForPersistedRole].
  Future<bool> shouldOpenPersistedStaffHome() async {
    final loggedIn = await isLoggedInFlag();
    final role = await lastRole();
    if (!loggedIn || role == null) return false;
    return staffRolesBypassingAuthGate.contains(role);
  }

  /// Returns the home widget for a persisted staff [role], or null.
  Widget? homeWidgetForPersistedRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'secretary':
        return const SecretaryHomeScreen();
      case 'doctor':
        return const DoctorHomeScreen();
      case 'admin':
        return const AdminDashboard();
      default:
        return null;
    }
  }
}
