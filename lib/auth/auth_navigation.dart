import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_localizations.dart';
import '../admin_panel/admin_dashboard.dart';
import '../doctor/doctor_home_screen.dart';
import '../patient/patient_home_screen.dart';
import '../secretary/secretary_home_screen.dart';

/// Maps Firestore [users] document to the correct home screen.
/// Returns `null` if the doctor is not approved yet.
Widget? homeWidgetForUserData(Map<String, dynamic> data) {
  final role = (data['role'] ?? '').toString();
  final isApproved = data['isApproved'] == true;

  if (role == 'Doctor' && !isApproved) {
    return null;
  }
  if (role == 'Admin') {
    return const AdminDashboard();
  }
  if (role == 'Secretary') {
    return const SecretaryHomeScreen();
  }
  if (role == 'Doctor') {
    return const DoctorHomeScreen();
  }
  if (role.toLowerCase() == 'patient') {
    return const PatientHomeScreen();
  }
  return null;
}

/// After email/password login: [AuthGate] rebuilds from auth + Firestore streams.
/// Do not push home routes here — that removes [AuthGate] and breaks auth-driven UI.
/// Only sign out and show snackbars for invalid / pending states.
Future<void> navigateAfterLogin(
  BuildContext context,
  Map<String, dynamic> userData,
) async {
  final role = (userData['role'] ?? '').toString();
  final isApproved = userData['isApproved'] == true;

  if (role == 'Doctor' && !isApproved) {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          S.of(context).translate('auth_snack_doctor_not_approved'),
          style: const TextStyle(fontFamily: 'KurdishFont'),
        ),
      ),
    );
    return;
  }

  if (!context.mounted) return;

  if (homeWidgetForUserData(userData) != null) {
    return;
  }

  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        S.of(context).translate('auth_snack_unknown_role'),
        style: const TextStyle(fontFamily: 'KurdishFont'),
      ),
    ),
  );
}
