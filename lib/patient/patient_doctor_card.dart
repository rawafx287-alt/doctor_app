import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';

/// Lux sky + gold palette for premium doctor cards.
const Color _kLuxSkyTop = Color(0xFFE3F2FD);
const Color _kLuxSkyMid = Color(0xFFF5FAFF);
const Color _kLuxGold = Color(0xFFFFD54F);

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

  /// Darker than [_navyText] for badge contrast on frosted glass.
  static const Color _badgeText = Color(0xFF050A14);
  static const Color _deepBlue = Color(0xFF1565C0);
  static const Color _avatarRingBlue = Color(0xFF283593);
  static const Color _verifiedBlue = Color(0xFF1565C0);

  static const double _radius = 20;
  static const double _outerBorderWidth = 0.5;
  static const double _innerRadius = 19.5;

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
    const colAlign = CrossAxisAlignment.end;
    const textAlign = TextAlign.end;
    const badgeAlign = AlignmentDirectional.centerEnd;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.92),
              width: _outerBorderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_innerRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _kLuxSkyTop,
                    _kLuxSkyMid,
                    Colors.white,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: 16,
                    spreadRadius: -4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
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
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _avatarRingBlue,
                                      width: 2,
                                    ),
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
                                            color: _avatarRingBlue,
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
                                          color: _avatarRingBlue,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 30),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: colAlign,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              widget.name,
                                              textAlign: textAlign,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _navyText,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                fontFamily: 'KurdishFont',
                                                height: 1.2,
                                                letterSpacing: 0.35,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.65,
                                                        ),
                                                    blurRadius: 10,
                                                    offset: Offset.zero,
                                                  ),
                                                  Shadow(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.45,
                                                        ),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 22,
                                            color: _verifiedBlue,
                                            shadows: [
                                              Shadow(
                                                color: _verifiedBlue.withValues(
                                                  alpha: 0.45,
                                                ),
                                                blurRadius: 6,
                                                offset: Offset.zero,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.white.withValues(
                                                alpha: 0.0,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.72,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.92,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.72,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.0,
                                              ),
                                            ],
                                            stops: const [
                                              0.0,
                                              0.18,
                                              0.5,
                                              0.82,
                                              1.0,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withValues(
                                                alpha: 0.55,
                                              ),
                                              blurRadius: 12,
                                              spreadRadius: -1,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    S.of(context).translate('field_specialty'),
                                    textAlign: textAlign,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.1,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'KurdishFont',
                                      color: _navyText.withValues(alpha: 0.58),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: badgeAlign,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.38,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _deepBlue.withValues(
                                            alpha: 0.5,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        widget.specialty,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: _badgeText,
                                          fontSize: 14,
                                          fontFamily: 'KurdishFont',
                                          height: 1.25,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          textDirection: TextDirection.ltr,
                          children: [
                            Expanded(
                              flex: 60,
                              child: SizedBox(
                                height: 48,
                                child: GestureDetector(
                                  onTap: widget.onBook,
                                  behavior: HitTestBehavior.opaque,
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
                                height: 48,
                                child: GestureDetector(
                                  onTap: widget.onOpenDetails,
                                  behavior: HitTestBehavior.opaque,
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
                ),
              ),
            ),
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
  static const Color _kDetailsTextNavy = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_r),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_r),
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: _kLuxGold.withValues(alpha: 0.9),
              width: 1.2,
            ),
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
                    color: _kDetailsTextNavy.withValues(alpha: 0.96),
                    fontFamily: 'KurdishFont',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                rtl
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _kLuxGold.withValues(alpha: 0.95),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary «نۆرە بگرە» — left, royal crimson glass, rounded rect.
class _BookNowPrimaryButton extends StatelessWidget {
  const _BookNowPrimaryButton({
    required this.pulseGlow,
    required this.bookCtaText,
  });

  final Animation<double> pulseGlow;
  final String bookCtaText;

  static const double _r = 14;
  static const double _buttonHeight = 48;
  static const Color _kBookTextNavy = Color(0xFF0D47A1);

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
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: _kLuxGold.withValues(alpha: 0.95),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
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
                        size: 20,
                        color: _kBookTextNavy.withValues(
                          alpha: 0.85 + 0.1 * pulse,
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
                        color: _kBookTextNavy.withValues(alpha: 0.98),
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.2,
                        letterSpacing: 0.1,
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

  static const Color _dividerRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    return Center(
      child: SizedBox(
        width: maxW,
        height: 1.5,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, _dividerRed, Colors.transparent],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
