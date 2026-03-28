import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'locale/app_locale.dart';
import 'locale/app_localizations.dart';
import 'locale/language_selection_screen.dart';
import 'theme/hr_nora_colors.dart';

/// Splash → [AuthGate] (FirebaseAuth + Firestore role → login or dashboard).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Duration displayDuration = Duration(milliseconds: 2500);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.displayDuration, _goToAuthGate);
  }

  void _goToAuthGate() {
    if (!mounted) return;
    final locale = AppLocaleScope.of(context);
    final next = locale.hasCompletedLanguageSelection
        ? const AuthGate()
        : const LanguageSelectionScreen();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => next),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: HrNoraColors.scaffoldDark,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HrNoraColors.accentLight.withValues(alpha: 0.12),
                    border: Border.all(
                      color: HrNoraColors.accentLight.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: HrNoraColors.primary.withValues(alpha: 0.15),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    size: 76,
                    color: HrNoraColors.accentLight,
                  ),
                ),
                const SizedBox(height: 20),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    'HR Nora',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: HrNoraColors.primary.withValues(alpha: 0.45),
                          blurRadius: 22,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: HrNoraColors.accentLight,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  S.of(context).translate('splash_loading'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
