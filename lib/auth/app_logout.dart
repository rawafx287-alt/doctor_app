import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_fonts.dart';
import 'auth_gate.dart';
import 'auth_service.dart';

/// Signs out, clears persisted session flags, and replaces the stack with [AuthGate].
///
/// Pushing [LoginScreen] alone removes [AuthGate] from the tree (MaterialApp’s
/// auth listener root), which commonly yields a black screen and breaks login.
/// [AuthGate] listens to [authStateChanges] and shows [LoginScreen] when the
/// user is null.
Future<void> performAppLogout(BuildContext context) async {
  await AuthService.instance.clearSession();
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    (route) => false,
  );
}

const Color _logoutTitleNavy = Color(0xFF1A237E);
const Color _logoutCancelMuted = Color(0xFF455A64);
const Color _kLuxuryGold = Color(0xFFD4AF37);
const Color _kGoldGradientA = Color(0xFFE8C547);
const Color _kGoldGradientB = Color(0xFFD4AF37);
const Color _kGoldGradientC = Color(0xFFC5A028);

/// Shows a confirmation dialog, then [performAppLogout] if the user confirms.
Future<void> confirmAndPerformAppLogout(BuildContext context) async {
  final barrierLabel =
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kLuxuryGold, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _kLuxuryGold.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFF8E7),
                        border: Border.all(
                          color: _kLuxuryGold.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        size: 28,
                        color: _kLuxuryGold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'ئایا دڵنیایت لە چوونەدەرەوە؟',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kAppFontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      letterSpacing: 0.15,
                      color: _logoutTitleNavy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'دوای چوونەدەرەوە پێویستە دووبارە بچیتەوە ژوورەوە.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kAppFontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      letterSpacing: 0.2,
                      color: const Color(0xFF607D8B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: _logoutCancelMuted,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'نەخێر',
                            style: TextStyle(
                              fontFamily: kAppFontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _kGoldGradientA,
                                _kGoldGradientB,
                                _kGoldGradientC,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _kLuxuryGold.withValues(alpha: 0.38),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(true),
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'بەڵێ',
                                    style: TextStyle(
                                      fontFamily: kAppFontFamily,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  if (ok == true && context.mounted) {
    await performAppLogout(context);
  }
}
