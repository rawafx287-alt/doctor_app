import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../baxerhatn_login/login.dart';
import '../firestore/firestore_cache_helpers.dart';
import 'auth_navigation.dart';
import 'firestore_user_doc_id.dart';
import 'phone_auth_config.dart';

/// Root widget: listens to auth + Firestore role and shows login or the correct home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data ?? FirebaseAuth.instance.currentUser;
        final waiting = authSnapshot.connectionState == ConnectionState.waiting;
        if (waiting && user == null) {
          return const _AuthLoadingScaffold();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: user == null
              ? const LoginScreen(
                  key: ValueKey<String>('auth_login'),
                  showBackButton: false,
                )
              : _AuthenticatedShell(
                  key: ValueKey<String>('auth_uid_${user.uid}'),
                  user: user,
                ),
        );
      },
    );
  }
}

/// Firestore role resolution after [FirebaseAuth] has a signed-in user.
class _AuthenticatedShell extends StatelessWidget {
  const _AuthenticatedShell({super.key, required this.user});

  final User user;

  Future<Map<String, dynamic>?> _lookupFallbackProfile(User user) async {
    final users = FirebaseFirestore.instance.collection('users');
    final email = (user.email ?? '').trim();

    // Phone-auth style account: try phone-keyed doc and phone field queries.
    if (email.endsWith('@$kPhoneAuthEmailDomain')) {
      final phone = email.split('@').first.trim();
      // کەمکردنەوەی خوێندنەوە: کاش→سێرڤەر.
      final byPhoneDoc = await getDocCacheFirst(users.doc(phone));
      if (byPhoneDoc.exists && byPhoneDoc.data() != null) {
        return byPhoneDoc.data();
      }
      final byPhoneStr = await getQueryCacheFirst(
        users.where('phone', isEqualTo: phone).limit(1),
      );
      if (byPhoneStr.docs.isNotEmpty) return byPhoneStr.docs.first.data();
      final phoneInt = int.tryParse(phone);
      if (phoneInt != null) {
        final byPhoneInt = await getQueryCacheFirst(
          users.where('phone', isEqualTo: phoneInt).limit(1),
        );
        if (byPhoneInt.docs.isNotEmpty) return byPhoneInt.docs.first.data();
      }
    }

    // Email-keyed fallback for legacy doc IDs.
    if (email.isNotEmpty) {
      final byEmail = await getQueryCacheFirst(
        users.where('email', isEqualTo: email).limit(1),
      );
      if (byEmail.docs.isNotEmpty) return byEmail.docs.first.data();
    }

    return null;
  }

  Widget _buildHomeFromData(Map<String, dynamic> data) {
    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    final isApproved = status == 'approved' || data['isApproved'] == true;

    if (role == 'doctor' && !isApproved) {
      return const DoctorPendingApprovalScreen();
    }

    final home = homeWidgetForUserData(data);
    return home ?? const UnknownRoleScreen();
  }

  @override
  Widget build(BuildContext context) {
    final docId = firestoreUserDocId(user);
    // کەمکردنەوەی "Read": دەستکاریکردنی ڕۆڵ/ستاتوس زۆرجار پێویست بە ریل‌تایم ناکات.
    // بۆیە سەرەتا cache-first `.get()` دەکەین؛ ئەگەر داتا نەبوو دواتر بە fallback دەچین.
    final ref = FirebaseFirestore.instance.collection('users').doc(docId);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: getDocCacheFirst(ref),
      builder: (context, docSnapshot) {
        if (docSnapshot.connectionState == ConnectionState.waiting &&
            !docSnapshot.hasData) {
          return const _AuthLoadingScaffold();
        }

        final doc = docSnapshot.data;
        if (doc != null && doc.exists) {
          final data = doc.data() ?? {};
          return _buildHomeFromData(data);
        }

        // Don't sign out automatically on doc-id mismatch; resolve legacy profile.
        return FutureBuilder<Map<String, dynamic>?>(
          future: _lookupFallbackProfile(user),
          builder: (context, fallbackSnap) {
            if (fallbackSnap.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScaffold();
            }
            final data = fallbackSnap.data;
            if (data == null) {
              return const UnknownRoleScreen();
            }
            return _buildHomeFromData(data);
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
                    fontFamily: 'NRT',
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
                    fontFamily: 'NRT',
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
                    style: const TextStyle(fontFamily: 'NRT', fontWeight: FontWeight.w700),
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
                    fontFamily: 'NRT',
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
                    style: const TextStyle(fontFamily: 'NRT', fontWeight: FontWeight.w700),
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
