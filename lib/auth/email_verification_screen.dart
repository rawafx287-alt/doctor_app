import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';

/// Shown when the user is signed in but [User.emailVerified] is false.
class EmailVerificationPendingScreen extends StatelessWidget {
  const EmailVerificationPendingScreen({
    super.key,
    required this.onRecheck,
  });

  /// Called after [User.reload] so [AuthGate] can rebuild and re-read verification.
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5))),
      );
    }

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
                const Icon(Icons.mark_email_unread_rounded,
                    size: 72, color: Color(0xFF42A5F5)),
                const SizedBox(height: 24),
                Text(
                  s.translate('auth_verify_email_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.translate('auth_verify_email_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF829AB1).withValues(alpha: 0.95),
                    fontFamily: 'KurdishFont',
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF42A5F5),
                    fontFamily: 'KurdishFont',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: const Color(0xFF102A43),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await user.sendEmailVerification();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            s.translate('auth_verify_email_resent'),
                            style: const TextStyle(fontFamily: 'KurdishFont'),
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$e',
                            style: const TextStyle(fontFamily: 'KurdishFont'),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    s.translate('auth_resend_verification'),
                    style: const TextStyle(
                      fontFamily: 'KurdishFont',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF42A5F5),
                    side: const BorderSide(color: Color(0xFF42A5F5)),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await user.reload();
                    onRecheck();
                  },
                  child: Text(
                    s.translate('auth_verify_email_recheck'),
                    style: const TextStyle(
                      fontFamily: 'KurdishFont',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: Text(
                    s.translate('auth_back_to_login'),
                    style: const TextStyle(
                      color: Color(0xFF829AB1),
                      fontFamily: 'KurdishFont',
                      fontWeight: FontWeight.w600,
                    ),
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
