import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../locale/app_localizations.dart';

/// Doctor row used on patient home and hospital doctor list.
class PatientDoctorCard extends StatefulWidget {
  const PatientDoctorCard({
    super.key,
    required this.name,
    required this.specialty,
    required this.onOpenDetails,
  });

  final String name;
  final String specialty;
  final VoidCallback onOpenDetails;

  @override
  State<PatientDoctorCard> createState() => _PatientDoctorCardState();
}

class _PatientDoctorCardState extends State<PatientDoctorCard>
    with SingleTickerProviderStateMixin {
  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  static const Color _cardBorder = Color(0xFF1A237E);
  static const Color _navyText = Color(0xFF0D2137);
  /// Darker than [_navyText] for badge contrast on frosted glass.
  static const Color _badgeText = Color(0xFF050A14);
  static const Color _deepBlue = Color(0xFF1565C0);
  static const Color _avatarRingBlue = Color(0xFF283593);
  static const Color _verifiedBlue = Color(0xFF1565C0);

  static const double _radius = 20;
  static const double _borderWidth = 1.5;
  static const double _innerRadius = _radius - _borderWidth;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.028).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const colAlign = CrossAxisAlignment.end;
    const textAlign = TextAlign.end;
    const badgeAlign = AlignmentDirectional.centerEnd;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) => _scaleController.reverse(),
        onTapCancel: () => _scaleController.reverse(),
        onTap: widget.onOpenDetails,
        borderRadius: BorderRadius.circular(_radius),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: _cardBorder,
                width: _borderWidth,
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
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        _deepBlue,
                        Colors.white.withValues(alpha: 0.95),
                      ],
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
                    padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          textDirection: Directionality.of(context),
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
                                child: Image.network(
                                  _placeholderImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    color: Colors.white.withValues(alpha: 0.85),
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
                                        mainAxisAlignment: MainAxisAlignment.end,
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
                                                    offset:
                                                        const Offset(0, 1),
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
                                                color: _verifiedBlue
                                                    .withValues(alpha: 0.45),
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
                                          borderRadius:
                                              BorderRadius.circular(2),
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
                                  const SizedBox(height: 14),
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
                                  const SizedBox(height: 6),
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 4,
                                sigmaY: 4,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: 0.32,
                                    ),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  textDirection: TextDirection.ltr,
                                  children: [
                                    Text(
                                      S.of(context).translate(
                                        'click_for_details',
                                      ),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.96,
                                        ),
                                        fontFamily: 'KurdishFont',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      rtl
                                          ? Icons.arrow_back_ios_new_rounded
                                          : Icons.arrow_forward_ios_rounded,
                                      size: 13,
                                      color: Colors.white.withValues(
                                        alpha: 0.98,
                                      ),
                                      shadows: [
                                        Shadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          blurRadius: 8,
                                          offset: Offset.zero,
                                        ),
                                        Shadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 14,
                                          offset: const Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
              colors: [
                Colors.transparent,
                _dividerRed,
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
