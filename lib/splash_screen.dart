import 'dart:async';

import 'package:flutter/material.dart';

import 'app_rtl.dart';
import 'auth/auth_gate.dart';
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
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
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
    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: HrNoraColors.scaffoldDark,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
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
              const SizedBox(height: 32),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  'HR Nora',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HrNoraColors.textSoft,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: HrNoraColors.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: HrNoraColors.accentLight,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'کەمێک چاوەڕوان بن...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HrNoraColors.textMuted.withValues(alpha: 0.95),
                  fontSize: 14,
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
