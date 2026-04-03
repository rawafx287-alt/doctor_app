import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';
import 'patient_grain_painter.dart';

/// Lux sky + gold palette for premium doctor cards.
const Color _kLuxGold = Color(0xFFD4AF37);
const Color _kLuxGoldLight = Color(0xFFF6E7A6);

/// Thin metallic rim around the home doctor card (top-left → bottom-right).
const LinearGradient _kDoctorCardSilverBorderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF0F0F0),
    Color(0xFFD1D1D1),
    Color(0xFFE0E0E0),
  ],
  stops: [0.0, 0.48, 1.0],
);

/// Layered elevation: soft ambient + deep lift + top highlight.
const List<BoxShadow> _kDoctorCardLayeredShadows = [
  BoxShadow(
    color: Color(0x12000000),
    blurRadius: 22,
    spreadRadius: -2,
    offset: Offset(0, 6),
  ),
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 40,
    spreadRadius: -8,
    offset: Offset(0, 16),
  ),
  BoxShadow(
    color: Color(0x18FFFFFF),
    blurRadius: 12,
    spreadRadius: -8,
    offset: Offset(0, -3),
  ),
];

/// Doctor row used on patient home and hospital doctor list.
class PatientDoctorCard extends StatefulWidget {
  const PatientDoctorCard({
    super.key,
    required this.name,
    required this.specialty,
    required this.onBook,
    required this.onOpenDetails,
    this.profileImageUrl,
  });

  final String name;
  final String specialty;
  final VoidCallback onBook;
  final VoidCallback onOpenDetails;
  /// Firestore `profileImageUrl`; placeholder if null/empty.
  final String? profileImageUrl;

  @override
  State<PatientDoctorCard> createState() => _PatientDoctorCardState();
}

class _PatientDoctorCardState extends State<PatientDoctorCard>
    with TickerProviderStateMixin {
  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  static const Color _navyText = kPatientNavyText;

  static const Color _deepBlue = Color(0xFF1565C0);

  static const double _radius = 20;
  static const double _kSilverBorderWidth = 0.9;
  static const double _kLightLeakBorder = 1.35;

  late AnimationController _pulseController;
  late Animation<double> _pulseGlow;

  String get _avatarUrl {
    final u = widget.profileImageUrl?.trim() ?? '';
    return u.isNotEmpty ? u : _placeholderImageUrl;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseGlow = Tween<double>(begin: 0.28, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final colAlign =
        rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = rtl ? TextAlign.end : TextAlign.start;
    final badgeAlign =
        rtl ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart;
    final hasArabicScript = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
    ).hasMatch(widget.name);
    final nameAlign = hasArabicScript ? TextAlign.right : TextAlign.left;
    final nameDirection =
        hasArabicScript ? TextDirection.rtl : TextDirection.ltr;
    final nameBoxAlignment =
        hasArabicScript ? Alignment.centerRight : Alignment.centerLeft;
    final rAfterSilver = _radius - _kSilverBorderWidth;
    final innerR = rAfterSilver - _kLightLeakBorder;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          gradient: _kDoctorCardSilverBorderGradient,
          boxShadow: _kDoctorCardLayeredShadows,
        ),
        padding: const EdgeInsets.all(_kSilverBorderWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(rAfterSilver),
          child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rAfterSilver),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.58),
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.52),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.2, 0.45, 0.7, 1.0],
                ),
              ),
              padding: const EdgeInsets.all(_kLightLeakBorder),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerR),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color(0xFFB3E5FC),
                      ],
                      stops: [0.35, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(innerR),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(innerR),
                            child: CustomPaint(
                              painter: PatientSubtleGrainPainter(
                                seed: widget.name.hashCode,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          textDirection: Directionality.of(context),
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _kLuxGold.withValues(alpha: 0.95),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.42),
                                        blurRadius: 8,
                                        spreadRadius: -1,
                                        offset: const Offset(0, -1),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: _avatarUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 128,
                                      memCacheHeight: 128,
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      placeholder: (context, url) => Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        alignment: Alignment.center,
                                        child: const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _deepBlue,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.medical_services_rounded,
                                          color: _deepBlue,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: colAlign,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Align(
                                        alignment: nameBoxAlignment,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: hasArabicScript
                                                ? const BorderRadius.only(
                                                    topRight: Radius.circular(20),
                                                    bottomRight: Radius.circular(20),
                                                    bottomLeft: Radius.circular(20),
                                                    topLeft: Radius.circular(0),
                                                  )
                                                : const BorderRadius.only(
                                                    topLeft: Radius.circular(20),
                                                    bottomLeft: Radius.circular(20),
                                                    bottomRight: Radius.circular(20),
                                                    topRight: Radius.circular(0),
                                                  ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withValues(alpha: 0.9),
                                                Colors.white.withValues(alpha: 0.84),
                                              ],
                                            ),
                                            border: Border.all(
                                              color: _kLuxGold.withValues(alpha: 0.34),
                                              width: 0.6,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.06),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            textDirection: nameDirection,
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: ShaderMask(
                                                  blendMode: BlendMode.srcIn,
                                                  shaderCallback: (bounds) =>
                                                      const LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Color(0xFF1B365D),
                                                      Color(0xFF2F3A45),
                                                    ],
                                                  ).createShader(
                                                    Rect.fromLTWH(
                                                      0,
                                                      0,
                                                      bounds.width,
                                                      bounds.height,
                                                    ),
                                                  ),
                                                  child: RichText(
                                                    textDirection: nameDirection,
                                                    textAlign: nameAlign,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: widget.name.trim(),
                                                          style: const TextStyle(
                                                            fontFamily:
                                                                kPatientPrimaryFont,
                                                            fontSize: 18.5,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            height: 1.12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Align(
                                        alignment: nameBoxAlignment,
                                        child: FractionallySizedBox(
                                          widthFactor: 0.62,
                                          child: Container(
                                            height: 1.5,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(999),
                                              gradient: LinearGradient(
                                                begin: hasArabicScript
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                                end: hasArabicScript
                                                    ? Alignment.centerLeft
                                                    : Alignment.centerRight,
                                                colors: [
                                                  _kLuxGold.withValues(alpha: 0.92),
                                                  _kLuxGold.withValues(alpha: 0.05),
                                                ],
                                                stops: const [0.0, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    S.of(context).translate('field_specialty'),
                                    textAlign: textAlign,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      height: 1.1,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: kPatientPrimaryFont,
                                      color: _navyText.withValues(alpha: 0.58),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: badgeAlign,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: BackdropFilter(
                                        filter: ui.ImageFilter.blur(
                                          sigmaX: 12,
                                          sigmaY: 12,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 13,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                const Color(
                                                  0xFFF3D6C4,
                                                ).withValues(alpha: 0.4),
                                                Colors.white.withValues(
                                                  alpha: 0.24,
                                                ),
                                                const Color(
                                                  0xFFE9D5C7,
                                                ).withValues(alpha: 0.34),
                                              ],
                                            ),
                                            border: Border.all(
                                              color: _kLuxGold.withValues(
                                                alpha: 0.98,
                                              ),
                                              width: 1.1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _kLuxGold.withValues(
                                                  alpha: 0.26,
                                                ),
                                                blurRadius: 8,
                                                spreadRadius: -2,
                                                offset: const Offset(0, 1),
                                              ),
                                              BoxShadow(
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 10,
                                                spreadRadius: -4,
                                                offset: const Offset(0, -2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            widget.specialty,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 13,
                                              fontFamily: kPatientPrimaryFont,
                                              height: 1.2,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          textDirection: TextDirection.ltr,
                          children: [
                            Expanded(
                              flex: 60,
                              child: SizedBox(
                                height: 42,
                                child: _DoctorCardPressableButton(
                                  onTap: widget.onBook,
                                  child: _BookNowPrimaryButton(
                                    pulseGlow: _pulseGlow,
                                    bookCtaText: S
                                        .of(context)
                                        .translate(
                                          'patient_doctor_card_book_cta',
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 35,
                              child: SizedBox(
                                height: 42,
                                child: _DoctorCardPressableButton(
                                  onTap: widget.onOpenDetails,
                                  child: _DoctorCardDetailsButton(
                                    rtl: rtl,
                                    label: S
                                        .of(context)
                                        .translate(
                                          'patient_doctor_card_details_short',
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

/// Book / Details CTAs: quick scale-down on press, snap back on release + light haptic.
class _DoctorCardPressableButton extends StatefulWidget {
  const _DoctorCardPressableButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_DoctorCardPressableButton> createState() =>
      _DoctorCardPressableButtonState();
}

class _DoctorCardPressableButtonState extends State<_DoctorCardPressableButton>
    with SingleTickerProviderStateMixin {
  static const double _kPressedScale = 0.96;

  late final AnimationController _scaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 115),
    reverseDuration: const Duration(milliseconds: 135),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: _kPressedScale,
  ).animate(
    CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
    ),
  );

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _pressDown() {
    HapticFeedback.lightImpact();
    _scaleController.forward();
  }

  void _pressEnd() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) => _pressEnd(),
      onTapCancel: _pressEnd,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Glass «وردەکاری» chip — flex layout, fixed height with book CTA.
class _DoctorCardDetailsButton extends StatelessWidget {
  const _DoctorCardDetailsButton({
    required this.rtl,
    required this.label,
  });

  final bool rtl;
  final String label;

  static const double _r = 14;
  static const Color _kDetailsTextColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_r),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_r),
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(
              color: _kLuxGold.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.38),
                blurRadius: 5,
                spreadRadius: -2,
                offset: const Offset(-0.5, -2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 7,
                spreadRadius: -2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _kDetailsTextColor.withValues(alpha: 0.92),
                    fontFamily: kPatientPrimaryFont,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                rtl
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.black.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary «نۆرە بگرە» — gold glass CTA.
class _BookNowPrimaryButton extends StatelessWidget {
  const _BookNowPrimaryButton({
    required this.pulseGlow,
    required this.bookCtaText,
  });

  final Animation<double> pulseGlow;
  final String bookCtaText;

  static const double _r = 14;
  static const double _buttonHeight = 42;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _buttonHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_r),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _kLuxGold.withValues(alpha: 0.95),
                  _kLuxGoldLight.withValues(alpha: 0.98),
                  _kLuxGold.withValues(alpha: 0.95),
                ],
              ),
              border: Border.all(
                color: _kLuxGold.withValues(alpha: 0.95),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.45),
                  blurRadius: 5,
                  spreadRadius: -2,
                  offset: const Offset(-0.5, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                textDirection: TextDirection.ltr,
                children: [
                  AnimatedBuilder(
                    animation: pulseGlow,
                    builder: (context, child) {
                      final pulse = pulseGlow.value;
                      return Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: Colors.black.withValues(
                          alpha: 0.84 + 0.08 * pulse,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      bookCtaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        height: 1.15,
                        letterSpacing: 0.08,
                        color: Colors.black.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal rule between doctor cards: transparent → theme red → transparent.
class DoctorCardGradientDivider extends StatelessWidget {
  const DoctorCardGradientDivider({super.key});
  static const Color _dividerGold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.7;
    return Center(
      child: SizedBox(
        width: maxW,
        height: 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                _dividerGold.withValues(alpha: 0.6),
                Colors.transparent,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
