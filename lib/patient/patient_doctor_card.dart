import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../locale/app_localizations.dart';
import '../specialty_categories.dart';
import '../theme/patient_premium_theme.dart';

/// Lux sky + gold palette for premium doctor cards.
const Color _kLuxGold = Color(0xFFD4AF37);
const Color _kLuxGoldLight = Color(0xFFF6E7A6);
const Color _kLuxGoldMid = Color(0xFFE8D18A);

/// Floating white card — soft multi-layer shadow (includes requested spread + blur).
const List<BoxShadow> _kFloatingCardShadows = [
  BoxShadow(
    color: Color(0x18000000),
    blurRadius: 10,
    spreadRadius: 1,
    offset: Offset(0, 3),
  ),
  BoxShadow(
    color: Color(0x0C000000),
    blurRadius: 20,
    spreadRadius: -2,
    offset: Offset(0, 8),
  ),
  BoxShadow(
    color: Color(0x06000000),
    blurRadius: 6,
    spreadRadius: 0,
    offset: Offset(0, 2),
  ),
];

/// Subtle lift for the doctor photo strip.
const List<BoxShadow> _kDoctorImageShadows = [
  BoxShadow(
    color: Color(0x22000000),
    blurRadius: 12,
    spreadRadius: 0,
    offset: Offset(-1, 4),
  ),
  BoxShadow(
    color: Color(0x10000000),
    blurRadius: 5,
    offset: Offset(0, 2),
  ),
];

/// Compact doctor row: vertical image on the end side, specialty + centered name
/// and book CTA; ⋮ opens details (no dropdown).
class PatientDoctorCard extends StatefulWidget {
  const PatientDoctorCard({
    super.key,
    required this.name,
    required this.specialty,
    required this.onBook,
    required this.onOpenDetails,
    this.profileImageUrl,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.initiallyFavorite = false,
    this.onFavoriteChanged,
  });

  final String name;
  final String specialty;
  final VoidCallback onBook;
  final VoidCallback onOpenDetails;
  /// Firestore `profileImageUrl`; placeholder if null/empty.
  final String? profileImageUrl;

  /// From `users/{doctor}` aggregate [ratingAverage] / [ratingCount].
  final double ratingAverage;
  final int ratingCount;

  /// UI-only favorite toggle (until you wire persistence).
  final bool initiallyFavorite;
  final ValueChanged<bool>? onFavoriteChanged;

  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  static const Color _navyText = kPatientNavyText;

  static const Color _deepBlue = Color(0xFF1565C0);

  /// Primary blue used for specialty chip tint (matches app accent).
  static const Color _kSpecialtyBadgeFill = Color(0xFF1565C0);

  static const double _radius = 20;

  /// Card row height — image strip matches; chip + name + rating + CTA.
  static const double _kCardContentHeight = 156;
  static const double _kImageStripWidth = 96;
  static const double _kImageCornerRadius = 16;

  @override
  State<PatientDoctorCard> createState() => _PatientDoctorCardState();
}

class _PatientDoctorCardState extends State<PatientDoctorCard> {
  late bool _isFavorite = widget.initiallyFavorite;

  @override
  void didUpdateWidget(covariant PatientDoctorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyFavorite != widget.initiallyFavorite) {
      _isFavorite = widget.initiallyFavorite;
    }
  }

  void _toggleFavorite() {
    HapticFeedback.selectionClick();
    setState(() => _isFavorite = !_isFavorite);
    widget.onFavoriteChanged?.call(_isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final hasArabicScript = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
    ).hasMatch(widget.name);
    final nameDirection =
        hasArabicScript ? TextDirection.rtl : TextDirection.ltr;
    final rawProfile = widget.profileImageUrl?.trim() ?? '';
    final avatarUrl = rawProfile.isNotEmpty
        ? rawProfile
        : PatientDoctorCard._placeholderImageUrl;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF4F9FF),
              const Color(0xFFEAF4FF),
              const Color(0xFFE8F4FC),
            ],
            stops: const [0.0, 0.52, 1.0],
          ),
          borderRadius: BorderRadius.circular(PatientDoctorCard._radius),
          border: Border.all(
            color: PatientDoctorCard._deepBlue.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: _kFloatingCardShadows,
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: SizedBox(
          height: PatientDoctorCard._kCardContentHeight,
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
                        8,
                        6,
                        8,
                      ),
                      child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final innerW = constraints.maxWidth;
                                      final specialtyLabel =
                                          S.of(context).translate(
                                        'field_specialty',
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          1,
                                          8,
                                          4,
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
                                                specialty: widget.specialty,
                                                maxWidth: innerW,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
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
                                                              widget.name.trim(),
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
                                                                        .w600,
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
                                                    const SizedBox(height: 10),
                                                    // Use [Wrap] instead of [Row] so small
                                                    // widths never overflow (rating + CTA can
                                                    // wrap to 2 lines when needed).
                                                    Wrap(
                                                      alignment:
                                                          WrapAlignment.center,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      spacing: 10,
                                                      runSpacing: 8,
                                                      children: [
                                                        if (widget.ratingCount > 0)
                                                          _PatientDoctorCardRatingLine(
                                                            average:
                                                                widget.ratingAverage,
                                                            count: widget.ratingCount,
                                                            compact: true,
                                                          ),
                                                        _DoctorCardPressableButton(
                                                          onTap: widget.onBook,
                                                          child:
                                                              _BookNowPrimaryButton(
                                                            bookCtaText: S
                                                                .of(context)
                                                                .translate(
                                                              'patient_doctor_card_book_cta',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
                              Container(
                                width: PatientDoctorCard._kImageStripWidth,
                                height: PatientDoctorCard._kCardContentHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    PatientDoctorCard._kImageCornerRadius,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFE5E1D9),
                                    width: 1,
                                  ),
                                  boxShadow: _kDoctorImageShadows,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    PatientDoctorCard._kImageCornerRadius - 0.5,
                                  ),
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
                                        alpha: 0.9,
                                      ),
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: PatientDoctorCard._deepBlue,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.medical_services_rounded,
                                        color: PatientDoctorCard._deepBlue,
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    tooltip: '',
                                    onPressed: _toggleFavorite,
                                    icon: Icon(
                                      _isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 21,
                                      color: _isFavorite
                                          ? const Color(0xFFE53935)
                                          : PatientDoctorCard._navyText
                                              .withValues(alpha: 0.72),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      widget.onOpenDetails();
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
                                        color: PatientDoctorCard._navyText
                                            .withValues(alpha: 0.72),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact ⭐ average (count) under the doctor name.
class _PatientDoctorCardRatingLine extends StatelessWidget {
  const _PatientDoctorCardRatingLine({
    required this.average,
    required this.count,
    this.compact = false,
  });

  final double average;
  final int count;
  final bool compact;

  static const Color _goldStar = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Center(
        child: Text(
          S.of(context).translate('doctor_card_rating_none'),
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontSize: compact ? 11 : 11.5,
            fontWeight: FontWeight.w600,
            color: kPatientNavyText.withValues(alpha: 0.48),
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.star_rounded,
          size: compact ? 15 : 16,
          color: _goldStar,
        ),
        const SizedBox(width: 4),
        Text(
          average.clamp(0, 5).toStringAsFixed(1),
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontSize: compact ? 12.25 : 12.5,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0A1628).withValues(alpha: 0.92),
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// Modern pill chip for specialty — top-right of the card text area.
class _PatientDoctorSpecialtyBadge extends StatelessWidget {
  const _PatientDoctorSpecialtyBadge({
    required this.label,
    required this.specialty,
    required this.maxWidth,
  });

  static const Color _kPrimary = PatientDoctorCard._kSpecialtyBadgeFill;

  final String label;
  final String specialty;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final prefix = '$label | ';
    final iconColor = _kPrimary.withValues(alpha: 0.88);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth.clamp(48, 176),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _kPrimary.withValues(alpha: 0.38),
            width: 0.75,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontSize: 8.35,
                      height: 1.22,
                      letterSpacing: 0.03,
                    ),
                    children: [
                      TextSpan(
                        text: prefix,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _kPrimary.withValues(alpha: 0.58),
                        ),
                      ),
                      TextSpan(
                        text: specialty,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kPrimary.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 6),
              _SpecialtyChipIcon(
                specialty: specialty,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny icon matched to Firestore specialty (tooth for dental, etc.).
class _SpecialtyChipIcon extends StatelessWidget {
  const _SpecialtyChipIcon({
    required this.specialty,
    required this.color,
  });

  final String specialty;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final key = specialtyFirestoreToKey(specialty.trim());
    if (key == 'dentist_specialty') {
      return FaIcon(
        FontAwesomeIcons.tooth,
        size: 9.5,
        color: color,
      );
    }
    final IconData data = key == null
        ? Icons.medical_information_outlined
        : iconForSpecialtyCategoryKey(key);
    return Icon(
      data,
      size: 10,
      color: color,
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: _kLuxGold.withValues(alpha: 0.22),
              blurRadius: 8,
              spreadRadius: -1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_r),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _kLuxGold,
                  _kLuxGoldMid,
                  _kLuxGoldLight.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
              border: Border.all(
                color: _kLuxGold.withValues(alpha: 0.55),
                width: 0.5,
              ),
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
