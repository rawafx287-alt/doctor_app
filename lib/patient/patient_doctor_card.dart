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

/// Compact doctor row: vertical image on the end side, specialty + centered name
/// and book CTA; ⋮ opens details (no dropdown).
class PatientDoctorCard extends StatelessWidget {
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

  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  static const Color _navyText = kPatientNavyText;

  static const Color _deepBlue = Color(0xFF1565C0);

  /// Muted tone for specialty badge text (does not compete with the name).
  static const Color _kSpecialtySubtitle = Color(0xFF6B7F96);

  /// Very light fill for specialty capsule (premium chip).
  static const Color _kSpecialtyBadgeFill = Color(0xFF1565C0);

  static const double _radius = 20;
  static const double _kSilverBorderWidth = 0.9;
  static const double _kLightLeakBorder = 1.35;

  /// Slim card content; image matches this height.
  static const double _kCardContentHeight = 112;
  static const double _kImageStripWidth = 96;

  @override
  Widget build(BuildContext context) {
    final hasArabicScript = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
    ).hasMatch(name);
    final nameDirection =
        hasArabicScript ? TextDirection.rtl : TextDirection.ltr;
    final rAfterSilver = _radius - _kSilverBorderWidth;
    final innerR = rAfterSilver - _kLightLeakBorder;
    final rawProfile = profileImageUrl?.trim() ?? '';
    final avatarUrl =
        rawProfile.isNotEmpty ? rawProfile : _placeholderImageUrl;

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
                  clipBehavior: Clip.hardEdge,
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
                              seed: name.hashCode,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: _kCardContentHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            textDirection: TextDirection.ltr,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    40,
                                    6,
                                    4,
                                    6,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final innerW = constraints.maxWidth;
                                      final specialtyLabel =
                                          S.of(context).translate(
                                        'field_specialty',
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Align(
                                              alignment:
                                                  Alignment.centerRight,
                                              child:
                                                  _PatientDoctorSpecialtyBadge(
                                                label: specialtyLabel,
                                                specialty: specialty,
                                                maxWidth: innerW,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Expanded(
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 4,
                                                      ),
                                                      child: SizedBox(
                                                        width: innerW,
                                                        child: FittedBox(
                                                          fit: BoxFit
                                                              .scaleDown,
                                                          alignment:
                                                              Alignment
                                                                  .center,
                                                          child:
                                                              Directionality(
                                                            textDirection:
                                                                nameDirection,
                                                            child: Text(
                                                              name.trim(),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              maxLines: 1,
                                                              softWrap: false,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                fontFamily:
                                                                    kPatientPrimaryFont,
                                                                fontSize:
                                                                    18.25,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                height: 1.15,
                                                                letterSpacing:
                                                                    -0.12,
                                                                color: Color(
                                                                  0xFF0A1628,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Center(
                                                      child:
                                                          _DoctorCardPressableButton(
                                                        onTap: onBook,
                                                        child:
                                                            _BookNowPrimaryButton(
                                                          bookCtaText: S
                                                              .of(context)
                                                              .translate(
                                                            'patient_doctor_card_book_cta',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius:
                                    BorderRadiusDirectional.horizontal(
                                  end: Radius.circular(innerR),
                                ),
                                child: SizedBox(
                                  width: _kImageStripWidth,
                                  height: _kCardContentHeight,
                                  child: CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    memCacheWidth: 256,
                                    memCacheHeight: 384,
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
                          Positioned(
                            left: 0,
                            top: -4,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onOpenDetails();
                                },
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                borderRadius: BorderRadius.circular(22),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.more_vert_rounded,
                                    size: 21,
                                    color: _navyText.withValues(alpha: 0.72),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded capsule for specialty — top-right of the card text area.
class _PatientDoctorSpecialtyBadge extends StatelessWidget {
  const _PatientDoctorSpecialtyBadge({
    required this.label,
    required this.specialty,
    required this.maxWidth,
  });

  final String label;
  final String specialty;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final line = '$label | $specialty';
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth.clamp(48, 176),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PatientDoctorCard._kSpecialtyBadgeFill.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: PatientDoctorCard._kSpecialtySubtitle.withValues(
              alpha: 0.2,
            ),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontSize: 8.75,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.06,
              color: PatientDoctorCard._kSpecialtySubtitle.withValues(
                alpha: 0.95,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Book CTA: quick scale-down on press, snap back on release + light haptic.
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

/// Primary «نۆرە بگرە» — gold glass CTA (text-only, compact).
class _BookNowPrimaryButton extends StatelessWidget {
  const _BookNowPrimaryButton({
    required this.bookCtaText,
  });

  final String bookCtaText;

  static const double _r = 10;
  static const double _buttonHeight = 28;
  static const double _maxButtonWidth = 152;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: _maxButtonWidth,
        minHeight: _buttonHeight,
        maxHeight: _buttonHeight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
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
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: -2,
                  offset: const Offset(-0.5, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              child: Center(
                child: Text(
                  bookCtaText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    height: 1.1,
                    letterSpacing: 0.04,
                    color: Colors.black.withValues(alpha: 0.9),
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
