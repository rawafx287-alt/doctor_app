import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'auth/auth_service.dart';
import 'locale/app_locale.dart';
import 'locale/language_selection_screen.dart';
import 'theme/hr_nora_colors.dart';

/// Splash → [AuthGate] (FirebaseAuth + Firestore role → login or dashboard).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Duration displayDuration = Duration(milliseconds: 2500);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _ambientController;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _timer = Timer(SplashScreen.displayDuration, _goToAuthGate);
  }

  Future<void> _goToAuthGate() async {
    if (!mounted) return;
    setState(() => _isExiting = true);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    final locale = AppLocaleScope.of(context);
    if (!locale.hasCompletedLanguageSelection) {
      Navigator.of(context, rootNavigator: true).pushReplacement(
        _smoothRoute(const LanguageSelectionScreen()),
      );
      return;
    }

    final auth = AuthService.instance;
    if (await auth.shouldOpenPersistedStaffHome()) {
      final role = await auth.lastRole();
      if (role != null) {
        final home = auth.homeWidgetForPersistedRole(role);
        if (home != null && mounted) {
          Navigator.of(context, rootNavigator: true).pushReplacement(
            _smoothRoute(home),
          );
          return;
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      _smoothRoute(const AuthGate()),
    );
  }

  PageRouteBuilder<void> _smoothRoute(Widget nextScreen) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 800),
      reverseTransitionDuration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HrNoraColors.scaffoldDark,
      body: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, _) {
          final t = _ambientController.value;
          return Stack(
            children: [
              const _SplashBackdrop(),
              _MovingBlob(
                progress: t,
                size: 250,
                color: const Color(0xFF2CA8FF),
                baseAlignment: const Alignment(-1.0, -0.72),
                travel: const Offset(0.20, 0.12),
              ),
              _MovingBlob(
                progress: t,
                size: 225,
                color: const Color(0xFF9B7CFF),
                baseAlignment: const Alignment(1.0, 0.64),
                travel: const Offset(-0.18, -0.12),
              ),
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    opacity: _isExiting ? 0 : 1,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BreathingLogo(progress: t),
                          const SizedBox(height: 30),
                          _LoadingDots(progress: t),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF081734), Color(0xFF020306)],
        ),
      ),
    );
  }
}

class _MovingBlob extends StatelessWidget {
  const _MovingBlob({
    required this.progress,
    required this.size,
    required this.color,
    required this.baseAlignment,
    required this.travel,
  });

  final double progress;
  final double size;
  final Color color;
  final Alignment baseAlignment;
  final Offset travel;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(progress * math.pi * 2);
    final dx = baseAlignment.x + (travel.dx * wave);
    final dy = baseAlignment.y + (travel.dy * math.cos(progress * math.pi * 2));
    return Align(
      alignment: Alignment(dx, dy),
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 62, sigmaY: 62),
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

class _BreathingLogo extends StatelessWidget {
  const _BreathingLogo({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scale = 1 + (math.sin(progress * math.pi * 2) * 0.03);
    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF55BFFF).withValues(alpha: 0.25),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.health_and_safety_rounded,
                size: 74,
                color: Color(0xFF8FD2FF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final indices = [0, 1, 2];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: indices.map((i) {
        final phase = (progress + (i * 0.16)) % 1;
        final pulse = 0.45 + (0.55 * (0.5 + 0.5 * math.sin(phase * math.pi * 2)));
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6FD3FF).withValues(alpha: pulse),
          ),
        );
      }).toList(),
    );
  }
}
