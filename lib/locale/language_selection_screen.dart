import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../baxerhatn_login/login.dart';
import '../theme/hr_nora_colors.dart';
import 'app_locale.dart';
import 'app_localizations.dart';

/// First-launch language choice -> saves locale -> [AuthGate].
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with TickerProviderStateMixin {
  bool _isSwitching = false;
  HrNoraLanguage? _selectedLanguage;
  bool _didPrecacheFlags = false;

  late final AnimationController _entryController;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheFlags) return;
    _didPrecacheFlags = true;
    precacheImage(const AssetImage('assets/images/kurdish_flag.png'), context);
    precacheImage(const AssetImage('assets/images/iraq_flag.png'), context);
    precacheImage(const AssetImage('assets/images/british_flag.png'), context);
  }

  void _select(HrNoraLanguage language) {
    if (_isSwitching) return;
    final locale = AppLocaleScope.of(context);
    HapticFeedback.lightImpact();
    setState(() {
      _isSwitching = true;
      _selectedLanguage = language;
    });

    // Save preference in parallel with route transition (no artificial delay).
    unawaited(locale.setLanguage(language));

    Navigator.pushReplacement(
      context,
      _loginRoute(),
    );
  }

  PageRouteBuilder<void> _loginRoute() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const LoginScreen(showBackButton: false),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutQuart,
        );
        final scale = Tween<double>(begin: 0.95, end: 1.0).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        language: HrNoraLanguage.ckb,
        flagAsset: 'assets/images/kurdish_flag.png',
      ),
      (
        language: HrNoraLanguage.ar,
        flagAsset: 'assets/images/iraq_flag.png',
      ),
      (
        language: HrNoraLanguage.en,
        flagAsset: 'assets/images/british_flag.png',
      ),
    ];

    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final t = _ambientController.value;
        return Stack(
          children: [
            _LangBackdrop(progress: t),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              opacity: _isSwitching ? 0.7 : 1,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  backgroundColor: Colors.transparent,
                  body: SafeArea(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 18),
                          Text(
                            S.of(context).translate('choose_language'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: HrNoraColors.textSoft,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'KurdishFont',
                            ),
                          ),
                          const SizedBox(height: 36),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < cards.length; i++) ...[
                                  _buildAnimatedCard(
                                    index: i,
                                    language: cards[i].language,
                                    flagAsset: cards[i].flagAsset,
                                  ),
                                  if (i != cards.length - 1)
                                    const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedCard({
    required int index,
    required HrNoraLanguage language,
    required String flagAsset,
  }) {
    final start = 0.08 + (index * 0.16);
    final end = (start + 0.38).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    final accent = _accentFor(language);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation),
        child: _LanguageCard(
          title: language.nativeTitle,
          subtitle: language.nativeSubtitle,
          flagAsset: flagAsset,
          accentColor: accent,
          selected: _selectedLanguage == language,
          enabled: !_isSwitching,
          onTap: () => _select(language),
        ),
      ),
    );
  }

  Color _accentFor(HrNoraLanguage language) {
    switch (language) {
      case HrNoraLanguage.ckb:
        return const Color(0xFF66BB6A);
      case HrNoraLanguage.ar:
        return const Color(0xFFAB47BC);
      case HrNoraLanguage.en:
        return const Color(0xFF42A5F5);
    }
  }
}

class _LangBackdrop extends StatelessWidget {
  const _LangBackdrop({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final move = math.sin(progress * math.pi * 2);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF081734), Color(0xFF020306)],
        ),
      ),
      child: Stack(
        children: [
          _BackdropBlob(
            alignment: Alignment(-0.95 + (move * 0.08), -0.75),
            size: 260,
            color: const Color(0xFF2CA8FF),
          ),
          _BackdropBlob(
            alignment: Alignment(0.96 - (move * 0.08), 0.72),
            size: 245,
            color: const Color(0xFF9B7CFF),
          ),
        ],
      ),
    );
  }
}

class _BackdropBlob extends StatelessWidget {
  const _BackdropBlob({
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

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.flagAsset,
    required this.accentColor,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final String flagAsset;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: selected
                      ? accentColor.withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.22),
                  width: selected ? 1.6 : 1.1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.28),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                child: Row(
                  children: [
                    _LanguageBadge(
                      flagAsset: flagAsset,
                      accentColor: accentColor,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: HrNoraColors.textSoft,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'KurdishFont',
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: HrNoraColors.textMuted.withValues(alpha: 0.95),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'KurdishFont',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: selected
                          ? accentColor.withValues(alpha: 0.9)
                          : HrNoraColors.accentLight.withValues(alpha: 0.78),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({
    required this.flagAsset,
    required this.accentColor,
  });

  final String flagAsset;
  final Color accentColor;

  static const double _flagW = 36;
  static const double _flagH = 24;
  static final BorderRadius _flagRadius = BorderRadius.circular(4);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _flagW,
          height: _flagH,
          decoration: BoxDecoration(
            borderRadius: _flagRadius,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.46),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: _flagRadius,
            child: Image.asset(
              flagAsset,
              width: _flagW,
              height: _flagH,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.translate_rounded,
          size: 18,
          color: accentColor.withValues(alpha: 0.95),
        ),
      ],
    );
  }
}
