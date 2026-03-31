import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';

/// Royal crimson primary CTA (deep → garnet).
const Color _kCrimsonDeep = Color(0xFF6B141E);
const Color _kCrimsonGarnet = Color(0xFFC62828);
const Color _kCrimsonBorderLight = Color(0xFFFF8A80);

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
                color: Colors.grey.withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_innerRadius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    _deepBlue,
                    Color.lerp(
                          _deepBlue,
                          const Color(0xFFE8EEF5),
                          0.72,
                        ) ??
                        const Color(0xFFE8EEF5),
                    Colors.white.withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: Offset.zero,
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_r),
      child: Container(
        width: double.infinity,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.26),
              Colors.white.withValues(alpha: 0.09),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.38),
            width: 0.5,
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
                  color: Colors.white.withValues(alpha: 0.96),
                  fontFamily: 'KurdishFont',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              rtl
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.98),
              shadows: const [
                Shadow(
                  color: Color(0xD9FFFFFF),
                  blurRadius: 6,
                  offset: Offset.zero,
                ),
                Shadow(
                  color: Color(0x59FFFFFF),
                  blurRadius: 10,
                  offset: Offset.zero,
                ),
              ],
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _buttonHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_r),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_r),
            border: Border.all(
              color: _kCrimsonBorderLight.withValues(alpha: 0.88),
              width: 1,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kCrimsonDeep, Color(0xFF8E1B2E), _kCrimsonGarnet],
              stops: [0.0, 0.48, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _kCrimsonDeep.withValues(alpha: 0.42),
                blurRadius: 22,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _kCrimsonGarnet.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.38),
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
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
                          color: Colors.white.withValues(
                            alpha: 0.94 + 0.05 * pulse,
                          ),
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(
                                alpha: 0.25 + 0.1 * pulse,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                            Shadow(
                              color: Colors.white.withValues(
                                alpha: 0.35 + 0.15 * pulse,
                              ),
                              blurRadius: 6,
                              offset: Offset.zero,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        bookCtaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.97),
                          fontFamily: 'KurdishFont',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.15,
                          letterSpacing: 0.06,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: Offset.zero,
                            ),
                          ],
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
