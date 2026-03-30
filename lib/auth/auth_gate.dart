import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../baxerhatn_login/login.dart';
import 'auth_navigation.dart';

/// Root widget: listens to auth + Firestore role and shows login or the correct home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScaffold();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen(showBackButton: false);
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting &&
                !docSnapshot.hasData) {
              return const _AuthLoadingScaffold();
            }

            final doc = docSnapshot.data;
            if (doc == null || !doc.exists) {
              return _FirestoreMissingProfileHandler(uid: user.uid);
            }

            final data = doc.data() ?? {};
            final role = (data['role'] ?? '').toString();
            final isApproved = data['isApproved'] == true;

            if (role == 'Doctor' && !isApproved) {
              return const DoctorPendingApprovalScreen();
            }

            final home = homeWidgetForUserData(data);
            if (home != null) {
              return home;
            }

            return const UnknownRoleScreen();
          },
        );
      },
    );
  }
}

class _AuthLoadingScaffold extends StatelessWidget {
  const _AuthLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0E21),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
      ),
    );
  }
}

/// Firestore doc missing: sign out once and show loading until auth stream clears.
class _FirestoreMissingProfileHandler extends StatefulWidget {
  const _FirestoreMissingProfileHandler({required this.uid});

  final String uid;

  @override
  State<_FirestoreMissingProfileHandler> createState() =>
      _FirestoreMissingProfileHandlerState();
}

class _FirestoreMissingProfileHandlerState extends State<_FirestoreMissingProfileHandler> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_started) return;
      _started = true;
      await FirebaseAuth.instance.signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _AuthLoadingScaffold();
  }
}

/// Doctor logged in but [isApproved] is false.
class DoctorPendingApprovalScreen extends StatelessWidget {
  const DoctorPendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 72, color: Color(0xFF42A5F5)),
                const SizedBox(height: 24),
                Text(
                  s.translate('auth_doctor_pending_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.translate('auth_doctor_pending_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF829AB1).withValues(alpha: 0.95),
                    fontFamily: 'KurdishFont',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: const Color(0xFF102A43),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: Text(
                    s.translate('auth_back_to_login'),
                    style: const TextStyle(fontFamily: 'KurdishFont', fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnknownRoleScreen extends StatelessWidget {
  const UnknownRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFF829AB1)),
                const SizedBox(height: 20),
                Text(
                  s.translate('auth_unknown_role'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: const Color(0xFF102A43),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: Text(
                    s.translate('auth_back'),
                    style: const TextStyle(fontFamily: 'KurdishFont', fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
