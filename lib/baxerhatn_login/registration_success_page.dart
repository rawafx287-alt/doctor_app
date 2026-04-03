import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import 'login.dart';

/// Shown after email/password sign-up and Firestore user document write.
class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({
    super.key,
    this.customMessage,
    this.customInstruction,
  });

  final String? customMessage;
  final String? customInstruction;

  void _goToLogin(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(showBackButton: false),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 36,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF2E7D32)
                                      .withValues(alpha: 0.22),
                                  border: Border.all(
                                    color: const Color(0xFF66BB6A)
                                        .withValues(alpha: 0.6),
                                    width: 1.6,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF81C784),
                                  size: 56,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                customMessage ??
                                    S.of(context).translate(
                                      'registration_success_message',
                                    ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFE7EEF7),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.45,
                                  fontFamily: 'NRT',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                customInstruction ??
                                    S.of(context).translate(
                                      'registration_success_instruction',
                                    ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 1.55,
                                  fontFamily: 'NRT',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF26C6DA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _goToLogin(context);
                        },
                        child: Text(
                          S.of(context).translate('registration_success_next'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'NRT',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08152F), Color(0xFF020305)],
        ),
      ),
      child: Stack(
        children: const [
          _BgBlob(
            alignment: Alignment(-1.0, -0.75),
            size: 220,
            color: Color(0xFF29B6F6),
          ),
          _BgBlob(
            alignment: Alignment(1.0, -0.4),
            size: 200,
            color: Color(0xFF7C4DFF),
          ),
        ],
      ),
    );
  }
}

class _BgBlob extends StatelessWidget {
  const _BgBlob({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 58, sigmaY: 58),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
