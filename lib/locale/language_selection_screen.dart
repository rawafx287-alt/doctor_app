import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../baxerhatn_login/login.dart';
import '../theme/app_fonts.dart';
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
  late final AnimationController _continueRevealController;

  static const Color _selectionGold = Color(0xFFE8C547);
  static const Color _selectionGreen = HrNoraColors.openDayGradientLight;

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
    _continueRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ambientController.dispose();
    _continueRevealController.dispose();
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

  Future<void> _onLanguageCardTap(HrNoraLanguage language) async {
    if (_isSwitching) return;
    await HapticFeedback.lightImpact();
    final hadSelection = _selectedLanguage != null;
    setState(() => _selectedLanguage = language);
    if (!hadSelection) {
      _continueRevealController.forward(from: 0);
    }
  }

  Future<void> _onContinue() async {
    final language = _selectedLanguage;
    if (language == null || _isSwitching) return;

    final locale = AppLocaleScope.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    await HapticFeedback.mediumImpact();
    setState(() => _isSwitching = true);

    unawaited(locale.setLanguage(language));

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    navigator.pushReplacement(_loginRoute());
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
                              fontFamily: 'NRT',
                            ),
                          ),
                          const SizedBox(height: 36),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                        const SizedBox(height: 24),
                                        _ContinueBar(
                                          controller: _continueRevealController,
                                          hasSelection:
                                              _selectedLanguage != null,
                                          busy: _isSwitching,
                                          onPressed: _onContinue,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isSwitching) ...[
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: const _LoadingOverlay(),
                ),
              ),
            ],
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
          selectionGold: _selectionGold,
          selectionGreen: _selectionGreen,
          enabled: !_isSwitching,
          onTap: () => _onLanguageCardTap(language),
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

/// Gold-gradient continue control; Kurdish label uses NRT bold (NRT-Bd).
/// Dims and sits low until [hasSelection]; then fades and slides up into focus.
class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.controller,
    required this.hasSelection,
    required this.busy,
    required this.onPressed,
  });

  final AnimationController controller;
  final bool hasSelection;
  final bool busy;
  final VoidCallback onPressed;

  static const Color _goldGlow = Color(0xFFE8C547);

  static const LinearGradient _activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC9A227),
      Color(0xFFF4D03F),
      Color(0xFFD4AF37),
      Color(0xFFB8860B),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final interactive = hasSelection && !busy;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = hasSelection
            ? Curves.easeOutCubic.transform(controller.value)
            : 0.0;
        final opacity = 0.40 + (1.0 - 0.40) * t;
        final dy = (1.0 - t) * 14.0;
        final shadowGold = _goldGlow.withValues(alpha: 0.22 + 0.32 * t);
        final shadowDepth = 6.0 + 16.0 * t;
        final labelColor = Color.lerp(
          HrNoraColors.textSoft.withValues(alpha: 0.42),
          HrNoraColors.primary,
          t,
        )!;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: interactive ? onPressed : null,
                    borderRadius: BorderRadius.circular(30),
                    child: Ink(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: interactive ? 0.34 : 0.16,
                          ),
                          width: 1.1,
                        ),
                        gradient: _activeGradient,
                        boxShadow: [
                          BoxShadow(
                            color: shadowGold,
                            blurRadius: shadowDepth,
                            offset: Offset(0, 4 + shadowDepth * 0.35),
                            spreadRadius: -2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: interactive ? 0.32 : 0.18,
                            ),
                            blurRadius: interactive ? 18 : 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'بەردەوامبە',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kAppFontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                            letterSpacing: 0.2,
                            color: labelColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
    required this.selectionGold,
    required this.selectionGreen,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final String flagAsset;
  final Color accentColor;
  final bool selected;
  final Color selectionGold;
  final Color selectionGreen;
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
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: selected
                      ? selectionGold
                      : Colors.white.withValues(alpha: 0.22),
                  width: selected ? 2.35 : 1.1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: selectionGold.withValues(alpha: 0.55),
                          blurRadius: 22,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: selectionGreen.withValues(alpha: 0.38),
                          blurRadius: 28,
                          spreadRadius: -4,
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
                              fontFamily: 'NRT',
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
                                fontFamily: 'NRT',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: selected
                          ? selectionGold.withValues(alpha: 0.92)
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

  /// Outer glass bubble; circular flag sits inside with inset padding.
  static const double _bubbleSize = 56;
  static const double _flagInset = 8;
  static const double _flagDiameter = 36;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _bubbleSize,
      height: _bubbleSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.26),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(_flagInset),
            child: ClipOval(
              child: Image.asset(
                flagAsset,
                width: _flagDiameter,
                height: _flagDiameter,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.26),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: 112,
                  height: 112,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF46B4FF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
