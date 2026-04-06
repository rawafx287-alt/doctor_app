import 'dart:ui' show ImageFilter, MaskFilter, Path, PathOperation;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../auth/app_logout.dart';
import '../auth/firestore_user_doc_id.dart';
import '../push/patient_push_registration.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../models/doctor_profile_fields.dart';
import '../specialty_categories.dart';
import '../theme/hr_nora_colors.dart';
import '../theme/patient_premium_theme.dart';
import 'contact_support_screen.dart';
import 'doctor_details_screen.dart';
import 'patient_doctor_booking_screen.dart';
import 'patient_doctor_card.dart';
import 'patient_profile_screen.dart';
import 'patient_scroll_physics.dart';
import 'my_appointments_screen.dart';
import 'patient_notifications_screen.dart';
import 'patient_recipient_keys.dart';
import '../firestore/root_notifications_firestore.dart';
import 'home_ad_carousel.dart';

/// Search bar height (fixed below city selector).
const double _kHomeSearchHeaderExtent = 44;

/// Soft tinted glass per specialty chip (distinct hue, still frosted).
Color _categorySoftTint(String catKey) {
  switch (catKey) {
    case kPatientSpecialtyAllKey:
      return const Color(0xFF80CBC4);
    case 'dentist_specialty':
      return const Color(0xFF90CAF9);
    case 'cardiology_specialty':
      return const Color(0xFFEF9A9A);
    case 'orthopedics_specialty':
      return const Color(0xFFFFCC80);
    case 'pediatrics_specialty':
      return const Color(0xFFF48FB1);
    case 'ent_specialty':
      return const Color(0xFFCE93D8);
    case 'ophthalmology_specialty':
      return const Color(0xFF9FA8DA);
    case 'dermatology_specialty':
      return const Color(0xFFF8BBD9);
    case 'neurology_specialty':
      return const Color(0xFFB39DDB);
    case 'obgyn_specialty':
      return const Color(0xFFFFAB91);
    case 'gastroenterology_specialty':
      return const Color(0xFFA5D6A7);
    default:
      return const Color(0xFFB3E5FC);
  }
}

Color _categoryAccentIcon(String catKey) {
  switch (catKey) {
    case kPatientSpecialtyAllKey:
      return HrNoraColors.openDayFill;
    case 'dentist_specialty':
      return const Color(0xFF1565C0);
    case 'cardiology_specialty':
      return const Color(0xFFC62828);
    case 'orthopedics_specialty':
      return const Color(0xFFEF6C00);
    case 'pediatrics_specialty':
      return const Color(0xFFAD1457);
    case 'ent_specialty':
      return const Color(0xFF6A1B9A);
    case 'ophthalmology_specialty':
      return const Color(0xFF283593);
    case 'dermatology_specialty':
      return const Color(0xFFC2185B);
    case 'neurology_specialty':
      return const Color(0xFF4527A0);
    case 'obgyn_specialty':
      return const Color(0xFFD84315);
    case 'gastroenterology_specialty':
      return HrNoraColors.openDayFill;
    default:
      return const Color(0xFF1976D2);
  }
}

const Color _kCharcoal = Color(0xFF333333);
const Color _kMutedGrey = Color(0xFF546E7A);
const Color _kVibrantBlue = Color(0xFF1976D2);
const Color _kDarkBlue = Color(0xFF0D47A1);
/// Matches doctor card border ([PatientDoctorCard]).
const Color _kPremiumDeepBlue = Color(0xFF1A237E);
/// Classic blue/gold accents (CTAs, rules, cross).
const Color _kBrandLuxGold = Color(0xFFD4AF37);
const Color _kBrandLuxGoldLight = Color(0xFFF6E7A6);
/// Same as doctor name text on cards ([PatientDoctorCard]).
const Color _kDoctorNameNavy = Color(0xFF0D2137);
const Color _kPremiumBlueMid = Color(0xFF1565C0);
const Color _kSpecialtyGlass = Color(0x0DFFFFFF);

double _inlineSpanLineWidth(InlineSpan span) {
  final painter = TextPainter(
    text: span,
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Always puts **HR** first and the rest as the second segment (handles "Nora HR" in strings).
(String hr, String rest) _brandTitleHrFirst(String translatedTitle) {
  final tokens = translatedTitle
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) {
    return ('HR', 'Nora');
  }
  final hrIndex = tokens.indexWhere((t) => t.toUpperCase() == 'HR');
  if (hrIndex >= 0) {
    final hrToken = tokens[hrIndex];
    final restTokens = [...tokens]..removeAt(hrIndex);
    return (hrToken, restTokens.join(' '));
  }
  return (tokens.first, tokens.length > 1 ? tokens.sublist(1).join(' ') : '');
}

/// Overflow menu row label (neutral charcoal).
const Color _kGlassMenuCharcoal = Color(0xFF37474F);

/// One row in the glass overflow menu (icon color + charcoal text).
Widget _patientGlassMenuInkRow({
  required BuildContext menuContext,
  required IconData icon,
  required Color iconColor,
  required String label,
  required String value,
  bool showUnreadDot = false,
}) {
  return InkWell(
    onTap: () => Navigator.pop(menuContext, value),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: iconColor),
                if (showUnreadDot)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.25,
                color: _kGlassMenuCharcoal,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Staggered hamburger for patient home overflow; gold glow on press (matches medical +).
class _StaggeredPopupMenuTrigger extends StatefulWidget {
  const _StaggeredPopupMenuTrigger();

  @override
  State<_StaggeredPopupMenuTrigger> createState() =>
      _StaggeredPopupMenuTriggerState();
}

class _StaggeredPopupMenuTriggerState extends State<_StaggeredPopupMenuTrigger> {
  bool _pressed = false;

  static const double _lineH = 5;
  static const double _lineR = 5;
  static const double _diameter = 42;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.82),
          border: Border.all(
            color: const Color(0xFFE8EEF4).withValues(alpha: 0.95),
            width: 0.75,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: _kBrandLuxGold.withValues(alpha: 0.48),
                    blurRadius: 14,
                    spreadRadius: 0.6,
                  ),
                  BoxShadow(
                    color: _kBrandLuxGoldLight.withValues(alpha: 0.32),
                    blurRadius: 10,
                    spreadRadius: -1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _staggeredMenuLine(22),
              const SizedBox(height: 3.5),
              _staggeredMenuLine(16),
              const SizedBox(height: 3.5),
              _staggeredMenuLine(11),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staggeredMenuLine(double width) {
    return Container(
      width: width,
      height: _lineH,
      decoration: BoxDecoration(
        color: _kPremiumDeepBlue,
        borderRadius: BorderRadius.circular(_lineR),
      ),
    );
  }
}

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// Bottom nav: 0 home, 1 appointments, 2 profile
  int _bottomNavIndex = 0;

  /// Full-screen frosted dim behind the overflow menu.
  late final AnimationController _menuDimController;
  late final Animation<double> _menuDimCurve;
  late final AnimationController _homeFabIntroController;
  late final Animation<double> _homeFabFade;
  late final Animation<Offset> _homeFabSlide;

  String _selectedCategory = kPatientSpecialtyAllKey;

  /// Firestore `city` filter; [kPatientCityFilterAll] shows every city.
  String _selectedCity = kPatientCityFilterAll;

  late final Future<Set<String>> _patientRecipientKeysFuture =
      resolvePatientRecipientKeys();

  /// Maps selected chip key ([kPatientSpecialtyAllKey] or translation key) to Firestore `specialty` string.
  String _firestoreValueForSelectedCategory() {
    for (final d in kDoctorSpecialtyDefinitions) {
      if (d.translationKey == _selectedCategory) return d.firestoreValue;
    }
    return _selectedCategory;
  }

  /// Firestore: approved doctors, optionally filtered by [city] and/or [specialty] (both from UI chips).
  Query<Map<String, dynamic>> _approvedDoctorsQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Doctor')
        .where('isApproved', isEqualTo: true);
    if (_selectedCity != kPatientCityFilterAll) {
      q = q.where(kDoctorCityField, isEqualTo: _selectedCity);
    }
    if (_selectedCategory != kPatientSpecialtyAllKey) {
      q = q.where(
        'specialty',
        isEqualTo: _firestoreValueForSelectedCategory(),
      );
    }
    return q;
  }

  /// Client-side only: search text on name/specialty (Firestore already narrowed city + specialty).
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

    final q = _searchController.text.trim();
    if (q.isEmpty) return list;
    final lower = q.toLowerCase();
    return list.where((d) {
      final data = d.data();
      final nameBlob = doctorNameSearchBlob(data);
      final spec = (data['specialty'] ?? '').toString().toLowerCase();
      return nameBlob.contains(lower) || spec.contains(lower);
    }).toList();
  }

  Widget _buildThinSearchBar(BuildContext context) {
    const radius = 18.0;
    const borderW = 0.8;
    final innerRadius = radius - borderW;
    const hintGrey = Color(0xFF455A64);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 3),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF90CAF9).withValues(alpha: 0.2),
                  blurRadius: 22,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [
                  _kPremiumDeepBlue,
                  _kPremiumDeepBlue.withValues(alpha: 0.35),
                  _kPremiumDeepBlue.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.18, 0.42, 0.72],
              ),
            ),
              padding: const EdgeInsets.all(borderW),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerRadius),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.97),
                                const Color(0xFFEEF2F6),
                                const Color(0xFFE2EAF0),
                              ],
                              stops: const [0.0, 0.48, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.92),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _kDoctorNameNavy.withValues(alpha: 0.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (_) => setState(() {}),
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: _kCharcoal,
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.2,
                        letterSpacing: 0.22,
                      ),
                      cursorColor: _kPremiumBlueMid,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText:
                            S.of(context).translate('search_doctors_hint'),
                        hintStyle: const TextStyle(
                          color: hintGrey,
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.2,
                          letterSpacing: 0.18,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _kDoctorNameNavy,
                          size: 18,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 28,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
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
    );
  }

  /// Horizontal filter chips (YouTube/Airbnb-style). Non-pinned [SliverToBoxAdapter] — scrolls away.
  Widget _buildCitySelectorStrip(BuildContext context) {
    final s = S.of(context);
    final entries = <(String, String)>[
      (kPatientCityFilterAll, s.translate('patient_home_city_all')),
      for (final c in kPatientHomeModalCityIds) (c, c),
    ];
    return Material(
      color: kPatientSkyTop,
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 3),
              child: Text(
                s.translate('patient_home_cities_title'),
                style: TextStyle(
                  color: _kDarkBlue.withValues(alpha: 0.88),
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1.0,
                ),
              ),
            ),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                clipBehavior: Clip.none,
                itemCount: entries.length,
                separatorBuilder: (context, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final cityId = entries[index].$1;
                  final label = entries[index].$2;
                  final selected = _selectedCity == cityId;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCity = cityId);
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? _kDarkBlue
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? _kDarkBlue
                                : const Color(0xFFE0E4EB),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected) ...[
                              const Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                height: 1.05,
                                letterSpacing: 0.1,
                                color: selected
                                    ? Colors.white
                                    : _kDoctorNameNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ad carousel + gap — scrolls away inside [CustomScrollView].
  Widget _buildHomeAdBannerBlock(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: HomeAdCarousel(height: homeAdBannerHeight(context)),
        ),
        const SizedBox(height: kHomeAdBannerGap),
      ],
    );
  }

  /// Specialties title + horizontal chips — used inside pinned [SliverPersistentHeader].
  Widget _buildSpecialtiesStickyStrip(
    BuildContext context, {
    required bool overlapsContent,
  }) {
    final scrollableCategoryKeys = patientSpecialtyFilterCategoryKeys
        .where((k) => k != kPatientSpecialtyAllKey)
        .toList();

    Widget specialtyTile({
      required String catKey,
      required bool selected,
      required Color soft,
      required Color acc,
      bool floating = false,
    }) {
      return SizedBox(
        width: 56,
        height: 96,
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedScale(
            scale: selected ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                _CategoryGlassOrb(
                  categoryKey: catKey,
                  selected: selected,
                  softTint: soft,
                  accent: acc,
                  floating: floating,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 54,
                  height: 28,
                  child: Text(
                    S.of(context).translate(catKey),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.bold,
                      fontSize: 9.5,
                      height: 1.1,
                      color: selected
                          ? _categoryLabelDark(catKey)
                          : _categoryLabelDark(catKey).withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: kPatientSkyTop,
      surfaceTintColor: Colors.transparent,
      elevation: overlapsContent ? 3.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  S.of(context).translate('specialties'),
                  style: const TextStyle(
                    color: _kDarkBlue,
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: 104,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: ColoredBox(
                    color: kPatientSkyTop.withValues(alpha: 0.82),
                    child: ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        8,
                        5,
                        14,
                        4,
                      ),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      clipBehavior: Clip.none,
                      itemCount: scrollableCategoryKeys.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final catKey = scrollableCategoryKeys[index];
                        final selected = _selectedCategory == catKey;
                        final soft = _categorySoftTint(catKey);
                        final acc = _categoryAccentIcon(catKey);
                        return InkWell(
                          onTap: () =>
                              setState(() => _selectedCategory = catKey),
                          borderRadius: BorderRadius.circular(22),
                          child: specialtyTile(
                            catKey: catKey,
                            selected: selected,
                            soft: soft,
                            acc: acc,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
      ),
    );
  }

  /// Doctor section as slivers (single scroll with pinned headers — avoids bottom overflow).
  List<Widget> _buildDoctorSlivers(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _kVibrantBlue),
            ),
          ),
        ),
      ];
    }
    if (snapshot.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                S
                    .of(context)
                    .translate(
                      'doctors_load_error_detail',
                      params: {'error': '${snapshot.error}'},
                    ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ];
    }
    final docs = snapshot.data?.docs ?? [];
    final filtered = _applyLocalFilters(docs);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final padBottom = 24.0 + bottomInset + 8;

    if (filtered.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, padBottom),
            child: Text(
              S.of(context).translate('doctors_empty_search'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kMutedGrey,
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, padBottom),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            addRepaintBoundaries: false,
            (context, index) {
              final doc = filtered[index];
              final data = doc.data();
              final lang = AppLocaleScope.of(context).effectiveLanguage;
              var name = localizedDoctorFullName(data, lang);
              if (name.isEmpty) {
                name = (data['fullName'] ?? '—').toString();
              }
              final specialtyRaw = (data['specialty'] ?? '—').toString();
              final specialty = translatedSpecialtyForFirestore(
                context,
                specialtyRaw,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0) ...[
                    const SizedBox(height: 8),
                    const DoctorCardGradientDivider(),
                    const SizedBox(height: 8),
                  ],
                  PatientDoctorCard(
                    name: name,
                    specialty: specialty,
                    profileImageUrl:
                        (data['profileImageUrl'] ?? '').toString(),
                    onBook: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => PatientDoctorBookingScreen(
                            doctorId: doc.id,
                            doctorData: Map<String, dynamic>.from(data),
                          ),
                        ),
                      );
                    },
                    onOpenDetails: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => DoctorDetailsScreen(
                            doctorId: doc.id,
                            doctorData: Map<String, dynamic>.from(data),
                            showBookingSection: false,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
            childCount: filtered.length,
          ),
        ),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _menuDimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _menuDimCurve = CurvedAnimation(
      parent: _menuDimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _homeFabIntroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _homeFabFade = CurvedAnimation(
      parent: _homeFabIntroController,
      curve: Curves.easeOut,
    );
    _homeFabSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _homeFabIntroController,
        curve: Curves.easeOutBack,
      ),
    );
    _homeFabIntroController.forward();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PatientPushRegistration.registerForCurrentUser();
    });
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _menuDimController.dispose();
    _homeFabIntroController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onBottomNavTap(int index) {
    HapticFeedback.lightImpact();
    if (index != 0) {
      _searchFocusNode.unfocus();
    }
    setState(() => _bottomNavIndex = index);
  }

  void _dismissMenuDim() {
    if (_menuDimController.isDismissed) return;
    _menuDimController.reverse();
  }

  Future<void> _logout() async {
    await performAppLogout(context);
  }

  /// **HR + Nora** wordmark (start-aligned) + overflow menu (profile / feedback / sign out).
  Widget _buildAppTopBar(BuildContext context) {
    final s = S.of(context);
    final title = s.translate('app_display_name');
    final (hrRaw, noraRaw) = _brandTitleHrFirst(title);
    final hrPart = hrRaw.isEmpty ? 'HR' : hrRaw;
    final noraPart = noraRaw.trim().isEmpty ? 'Nora' : noraRaw.trim();

    const titleBlue = _kPremiumDeepBlue;
    const tightKern = -0.18;
    const titleShadow = <Shadow>[
      Shadow(
        color: Color(0x1F000000),
        offset: Offset(0, 1.25),
        blurRadius: 4.5,
      ),
    ];

    final hrStyle = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontSize: 22,
      letterSpacing: tightKern,
      fontWeight: FontWeight.bold,
      color: titleBlue,
      height: 1.0,
      shadows: titleShadow,
    );
    final noraStyle = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontSize: 22,
      letterSpacing: tightKern,
      fontWeight: FontWeight.bold,
      color: titleBlue,
      height: 1.0,
      shadows: titleShadow,
    );

    const crossSize = 27.0;
    const crossPadH = 8.0;
    final hrW = _inlineSpanLineWidth(TextSpan(text: hrPart, style: hrStyle));
    final noraW = _inlineSpanLineWidth(TextSpan(text: noraPart, style: noraStyle));
    final crossSectionW = crossPadH + crossSize + crossPadH;
    final formulaWidth = hrW + crossSectionW + noraW;
    final crossCenterT = (hrW + crossSectionW / 2) / formulaWidth;

    // Snug to the ⋮; small negative dx keeps the panel near the right edge; dy aligns
    // vertically so it reads as opening from the icon.
    const menuOffset = Offset(-10, 45);

    final user = FirebaseAuth.instance.currentUser;
    final inboxDocId =
        user != null ? firestoreUserDocId(user).trim() : '';

    Widget topBarShell({required bool hasUnreadNotifications}) {
      return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
      child: Row(
        // LTR keeps the title on the left and the ⋮ menu on the right in RTL apps.
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(hrPart, style: hrStyle),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: crossPadH),
                        child: _BrandTitleMedicalCross(size: crossSize),
                      ),
                      Text(noraPart, style: noraStyle),
                    ],
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: formulaWidth,
                    height: 2.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [
                            0.0,
                            (crossCenterT - 0.24).clamp(0.04, 0.45),
                            (crossCenterT - 0.08).clamp(0.08, 0.48),
                            crossCenterT.clamp(0.12, 0.88),
                            (crossCenterT + 0.08).clamp(0.52, 0.92),
                            (crossCenterT + 0.24).clamp(0.55, 0.96),
                            1.0,
                          ],
                          colors: [
                            _kBrandLuxGold.withValues(alpha: 0.52),
                            _kBrandLuxGold.withValues(alpha: 0.78),
                            _kBrandLuxGoldLight.withValues(alpha: 0.92),
                            _kBrandLuxGoldLight,
                            _kBrandLuxGoldLight.withValues(alpha: 0.92),
                            _kBrandLuxGold.withValues(alpha: 0.78),
                            _kBrandLuxGold.withValues(alpha: 0.52),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: const PopupMenuThemeData(
                color: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              tooltip: '',
              padding: EdgeInsets.zero,
              color: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              constraints: const BoxConstraints(minWidth: 232),
              offset: menuOffset,
              onOpened: () {
                _menuDimController.forward();
              },
              onCanceled: _dismissMenuDim,
              onSelected: (value) async {
                _dismissMenuDim();
                if (!context.mounted) return;
                if (value.isEmpty) return;
                if (value == 'profile') {
                  setState(() => _bottomNavIndex = 2);
                } else if (value == 'feedback') {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const ContactSupportScreen(),
                    ),
                  );
                } else if (value == 'notifications') {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const PatientNotificationsScreen(),
                    ),
                  );
                } else if (value == 'logout') {
                  await _logout();
                }
              },
              itemBuilder: (ctx) {
                const profileBlue = Color(0xFF1565C0);
                const feedbackTeal = Color(0xFF00897B);
                const notificationsIndigo = Color(0xFF5C6BC0);
                const logoutCoral = Color(0xFFE57373);
                final dividerColor = Colors.grey.withValues(alpha: 0.15);
                return [
                  PopupMenuItem<String>(
                    padding: EdgeInsets.zero,
                    value: '',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 248,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.1),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _patientGlassMenuInkRow(
                                menuContext: ctx,
                                icon: Icons.person_rounded,
                                iconColor: profileBlue,
                                label: s.translate('profile'),
                                value: 'profile',
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 14,
                                endIndent: 14,
                                color: dividerColor,
                              ),
                              _patientGlassMenuInkRow(
                                menuContext: ctx,
                                icon: Icons.feedback_outlined,
                                iconColor: feedbackTeal,
                                label: s.translate('patient_home_menu_feedback'),
                                value: 'feedback',
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 14,
                                endIndent: 14,
                                color: dividerColor,
                              ),
                              _patientGlassMenuInkRow(
                                menuContext: ctx,
                                icon: Icons.notifications_none_rounded,
                                iconColor: notificationsIndigo,
                                label:
                                    s.translate('patient_home_menu_notifications'),
                                value: 'notifications',
                                showUnreadDot: hasUnreadNotifications,
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 14,
                                endIndent: 14,
                                color: dividerColor,
                              ),
                              _patientGlassMenuInkRow(
                                menuContext: ctx,
                                icon: Icons.logout_rounded,
                                iconColor: logoutCoral,
                                label: s.translate('logout'),
                                value: 'logout',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              child: const _StaggeredPopupMenuTrigger(),
            ),
          ),
        ],
      ),
    );
    }

    Widget withInboxAndRoot(bool rootUnread) {
      if (inboxDocId.isEmpty) {
        return topBarShell(hasUnreadNotifications: rootUnread);
      }
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(inboxDocId)
            .collection('notificationInbox')
            .where('read', isEqualTo: false)
            .limit(1)
            .snapshots(),
        builder: (context, inboxSnap) {
          final inboxUnread = inboxSnap.hasData &&
              (inboxSnap.data?.docs.isNotEmpty ?? false);
          return topBarShell(
            hasUnreadNotifications: inboxUnread || rootUnread,
          );
        },
      );
    }

    return FutureBuilder<Set<String>>(
      future: _patientRecipientKeysFuture,
      builder: (context, keySnap) {
        final keys = keySnap.data ?? {};
        if (keys.isEmpty) {
          return withInboxAndRoot(false);
        }
        return StreamBuilder<bool>(
          stream: watchHasUnreadRootNotificationAnyKey(keys),
          builder: (context, rootSnap) {
            final rootUnread = rootSnap.data ?? false;
            return withInboxAndRoot(rootUnread);
          },
        );
      },
    );
  }

  Widget _buildGlassBottomNav(BuildContext context) {
    final s = S.of(context);
    const dockRadius = 30.0;
    final hasActiveAppointments = _bottomNavIndex != 1;
    final glowColor = Colors.amber.withValues(alpha: 0.35);
    const activeIconColor = Color(0xFFB8860B);

    Widget navItem({
      required int index,
      required IconData icon,
      required String label,
      bool highlightGold = false,
      bool showDot = false,
      bool goldSilverActiveAccent = false,
    }) {
      final selected = _bottomNavIndex == index;
      final targetColor = selected ? activeIconColor : _kMutedGrey;
      final iconShadows = selected
          ? (goldSilverActiveAccent
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFC0C0C0).withValues(alpha: 0.52),
                    blurRadius: 14,
                    spreadRadius: 1.2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.32),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : <BoxShadow>[
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 10.0,
                    spreadRadius: 2.0,
                  ),
                ])
          : const <BoxShadow>[];
      return SizedBox(
        width: 86,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onBottomNavTap(index),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: iconShadows,
                        ),
                        child: AnimatedScale(
                          scale: selected ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: targetColor),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedColor, _) {
                              return Icon(
                                icon,
                                size: selected ? 23 : 21,
                                color: animatedColor ?? targetColor,
                              );
                            },
                          ),
                        ),
                      ),
                      if (showDot && hasActiveAppointments)
                        PositionedDirectional(
                          top: 8,
                          end: 7,
                          child: Container(
                            width: 7.5,
                            height: 7.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: highlightGold
                                  ? _kBrandLuxGold
                                  : const Color(0xFFE53935),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      if (selected && goldSilverActiveAccent)
                        Positioned(
                          bottom: -1,
                          child: Container(
                            height: 2.5,
                            width: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFE8E8E8),
                                  Color(0xFFC0C0C0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: targetColor),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedColor, _) {
                      return Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: animatedColor ?? _kMutedGrey,
                          height: 1.1,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget homeFabItem() {
      final selected = _bottomNavIndex == 0;
      return SizedBox(
        width: 86,
        child: FadeTransition(
          opacity: _homeFabFade,
          child: SlideTransition(
            position: _homeFabSlide,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _onBottomNavTap(0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFB8860B),
                              ],
                            ),
                          ),
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              opacity: selected ? 1.0 : 0.6,
                              child: Icon(
                                Icons.home_rounded,
                                size: selected ? 23 : 21,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFFF5E7A6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.translate('home'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: selected ? const Color(0xFFB8860B) : _kMutedGrey,
                          height: 1.1,
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dockRadius),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(dockRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.64),
                  border: Border(
                    top: BorderSide(
                      color: _kBrandLuxGoldLight.withValues(alpha: 0.65),
                      width: 1,
                    ),
                    left: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 0.7,
                    ),
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 0.7,
                    ),
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 0.6,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Builder(
                    builder: (context) {
                      final isRtl =
                          Directionality.of(context) == TextDirection.rtl;
                      // LTR: profile (left) | home | appointments (right).
                      // RTL: reverse children so physical positions match.
                      final children = isRtl
                          ? <Widget>[
                              navItem(
                                index: 1,
                                icon: Icons.calendar_month_rounded,
                                label: s.translate('appointments'),
                                highlightGold: true,
                                showDot: true,
                              ),
                              homeFabItem(),
                              navItem(
                                index: 2,
                                icon: Icons.person_rounded,
                                label: s.translate('profile'),
                                goldSilverActiveAccent: true,
                              ),
                            ]
                          : <Widget>[
                              navItem(
                                index: 2,
                                icon: Icons.person_rounded,
                                label: s.translate('profile'),
                                goldSilverActiveAccent: true,
                              ),
                              homeFabItem(),
                              navItem(
                                index: 1,
                                icon: Icons.calendar_month_rounded,
                                label: s.translate('appointments'),
                                highlightGold: true,
                                showDot: true,
                              ),
                            ];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: children,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: kPatientSkyTop,
        body: DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PatientSubtleGeometricPatternPainter(),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SafeArea(
                    bottom: false,
                    child: _buildAppTopBar(context),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _bottomNavIndex,
                      sizing: StackFit.expand,
                      children: [
                        PatientHomeContent._(this),
                        const PatientAppointmentsScreen(embedded: true),
                        const PatientProfileScreen(),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: _searchFocusNode.hasFocus && _bottomNavIndex == 0
                        ? const SizedBox.shrink()
                        : _buildGlassBottomNav(context),
                  ),
                ],
              ),
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _menuDimController,
                  builder: (context, _) {
                    return IgnorePointer(
                      ignoring: _menuDimController.value < 0.001,
                      child: FadeTransition(
                        opacity: _menuDimCurve,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.2),
                            child: const SizedBox.expand(),
                          ),
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
    );
  }

  /// Home: fixed search bar; [CustomScrollView] with city (scrolls), ad, pinned specialties, doctors.
  Widget _buildHomeContent() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: ValueKey<String>('doctors_${_selectedCity}_$_selectedCategory'),
      stream: _approvedDoctorsQuery().snapshots(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: kPatientSkyTop,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              shadowColor: Colors.black26,
              child: SizedBox(
                height: _kHomeSearchHeaderExtent,
                child: _buildThinSearchBar(context),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                key: const ValueKey<String>('home_doctors_scroll'),
                physics: patientHomePrimaryScrollPhysics,
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildCitySelectorStrip(context),
                  ),
                  SliverToBoxAdapter(
                    child: _buildHomeAdBannerBlock(context),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PatientSpecialtiesPinnedDelegate(
                      extent: kHomeSpecialtiesBlockExtent,
                      selectedCategory: _selectedCategory,
                      selectedCity: _selectedCity,
                      builder: (ctx, overlaps) =>
                          _buildSpecialtiesStickyStrip(
                        ctx,
                        overlapsContent: overlaps,
                      ),
                    ),
                  ),
                  ..._buildDoctorSlivers(context, snapshot),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Pinned specialties strip below the scrolling city row (sticks while doctors scroll).
class _PatientSpecialtiesPinnedDelegate extends SliverPersistentHeaderDelegate {
  _PatientSpecialtiesPinnedDelegate({
    required this.extent,
    required this.selectedCategory,
    required this.selectedCity,
    required this.builder,
  });

  final double extent;
  final String selectedCategory;
  final String selectedCity;
  final Widget Function(BuildContext context, bool overlapsContent) builder;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: extent,
      width: double.infinity,
      child: ClipRect(
        child: builder(context, overlapsContent),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PatientSpecialtiesPinnedDelegate oldDelegate) {
    return oldDelegate.extent != extent ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.selectedCity != selectedCity;
  }
}

/// Home tab body for [PatientHomeScreen] (doctors browse only).
class PatientHomeContent extends StatelessWidget {
  const PatientHomeContent._(this._state);

  final _PatientHomeScreenState _state;

  @override
  Widget build(BuildContext context) => _state._buildHomeContent();
}

/// Frosted-glass tile with deep-gold medical cross (app bar mark).
class _BrandTitleMedicalCross extends StatelessWidget {
  const _BrandTitleMedicalCross({required this.size});

  final double size;

  static const double _glassRadius = 12;
  static const double _armCorner = 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_glassRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            spreadRadius: 1.2,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: _kBrandLuxGold.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_glassRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            CustomPaint(
              painter: _GoldMedicalCrossPainter(armCornerRadius: _armCorner),
              size: Size(size, size),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_glassRadius),
                    border: Border.all(
                      color: Color.alphaBlend(
                        _kBrandLuxGold.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.62),
                      ),
                      width: 0.9,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldMedicalCrossPainter extends CustomPainter {
  const _GoldMedicalCrossPainter({required this.armCornerRadius});

  final double armCornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final armW = size.width * 0.31;
    final armLen = size.width * 0.9;
    final r = Radius.circular(armCornerRadius.clamp(1.0, 6.0));

    final vPath = Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: armW, height: armLen),
            r,
          ),
        );
    final hPath = Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: armLen, height: armW),
            r,
          ),
        );
    final crossPath =
        Path.combine(PathOperation.union, vPath, hPath);

    final rect = Offset.zero & size;
    // Brighter inner glow (matches lux light) so the symbol pops on glass
    canvas.drawPath(
      crossPath,
      Paint()
        ..color = _kBrandLuxGoldLight.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      crossPath,
      Paint()
        ..color = _kBrandLuxGold.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1)
        ..style = PaintingStyle.fill,
    );

    // Same horizontal lux gradient as «نۆرە بگرە» (full opacity for vibrancy)
    final shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        _kBrandLuxGold,
        _kBrandLuxGoldLight,
        _kBrandLuxGold,
      ],
    ).createShader(rect);

    canvas.drawPath(
      crossPath,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldMedicalCrossPainter oldDelegate) =>
      oldDelegate.armCornerRadius != armCornerRadius;
}

/// Vertical glass card with premium mesh-gradient icon and active gold pop state.
class _CategoryGlassOrb extends StatelessWidget {
  const _CategoryGlassOrb({
    required this.categoryKey,
    required this.selected,
    required this.softTint,
    required this.accent,
    this.floating = false,
  });

  final String categoryKey;
  final bool selected;
  final Color softTint;
  final Color accent;
  final bool floating;

  static const double _cardW = 45;
  static const double _cardH = 44;
  static const double _iconContainer = 23;
  static const double _iconSize = 11;

  @override
  Widget build(BuildContext context) {
    final visual = _specialtyVisual(categoryKey);
    final baseFill = Color.alphaBlend(softTint.withValues(alpha: 0.18), _kSpecialtyGlass);

    return SizedBox(
      width: _cardW,
      height: _cardH,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? accent
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.65 : 0.65,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    baseFill,
                  ],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(0.85),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      visual.border.withValues(alpha: 0.88),
                      visual.border.withValues(alpha: 0.35),
                    ],
                  ),
                ),
                child: Container(
                  margin: EdgeInsets.all(
                    _isAllCategory(categoryKey) ? 2.1 : 1.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Container(
                      width: _iconContainer,
                      height: _iconContainer,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.35),
                          radius: 1.12,
                          colors: [
                            visual.meshA.withValues(alpha: selected ? 1.0 : 0.98),
                            visual.meshB.withValues(alpha: selected ? 1.0 : 0.95),
                            visual.meshC.withValues(alpha: selected ? 0.95 : 0.82),
                          ],
                          stops: const [0.04, 0.58, 1.0],
                        ),
                      ),
                      child: Center(
                        child: visual.svgAsset != null
                            ? SvgPicture.asset(
                                visual.svgAsset!,
                                width: selected ? _iconSize + 3 : _iconSize + 1.5,
                                height: selected ? _iconSize + 3 : _iconSize + 1.5,
                                colorFilter: ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              )
                            : FaIcon(
                                visual.icon,
                                size: selected ? _iconSize + 1.5 : _iconSize,
                                color: Colors.white,
                              ),
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

class _SpecialtyVisual {
  const _SpecialtyVisual({
    this.icon,
    this.svgAsset,
    required this.meshA,
    required this.meshB,
    required this.meshC,
    required this.glow,
    required this.border,
    required this.darkLabel,
  });

  final FaIconData? icon;
  final String? svgAsset;
  final Color meshA;
  final Color meshB;
  final Color meshC;
  final Color glow;
  final Color border;
  final Color darkLabel;
}

_SpecialtyVisual _specialtyVisual(String categoryKey) {
  switch (categoryKey) {
    case 'cardiology_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.heartPulse,
        meshA: Color(0xFFE53935),
        meshB: Color(0xFFC2185B),
        meshC: Color(0xFF7A1F4A),
        glow: Color(0xFFFF6B81),
        border: Color(0xFFE57373),
        darkLabel: Color(0xFF5B1125),
      );
    case 'dentist_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.tooth,
        meshA: Color(0xFF42A5F5),
        meshB: Color(0xFF26C6DA),
        meshC: Color(0xFF26A69A),
        glow: Color(0xFF4DD0E1),
        border: Color(0xFF80DEEA),
        darkLabel: Color(0xFF0F3B6D),
      );
    case 'pediatrics_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.baby,
        meshA: Color(0xFFB388FF),
        meshB: Color(0xFFE91E63),
        meshC: Color(0xFFF48FB1),
        glow: Color(0xFFF48FB1),
        border: Color(0xFFE1BEE7),
        darkLabel: Color(0xFF5E2D79),
      );
    case 'ophthalmology_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.eye,
        meshA: Color(0xFF1E88E5),
        meshB: Color(0xFF42A5F5),
        meshC: Color(0xFF81D4FA),
        glow: Color(0xFF64B5F6),
        border: Color(0xFF90CAF9),
        darkLabel: Color(0xFF0E3569),
      );
    case kPatientSpecialtyAllKey:
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.tableCellsLarge,
        meshA: Color(0xFF2F6BFF),
        meshB: Color(0xFF283593),
        meshC: Color(0xFF1A237E),
        glow: Color(0xFF4A6CFF),
        border: Color(0xFF7B8DFF),
        darkLabel: Color(0xFF1A2A6A),
      );
    case 'orthopedics_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.personWalking,
        meshA: Color(0xFFFFA000),
        meshB: Color(0xFFFB8C00),
        meshC: Color(0xFFFFB74D),
        glow: Color(0xFFFF9800),
        border: Color(0xFFFFCC80),
        darkLabel: Color(0xFF6A3B07),
      );
    case 'ent_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.earListen,
        meshA: Color(0xFF8E24AA),
        meshB: Color(0xFFAB47BC),
        meshC: Color(0xFFCE93D8),
        glow: Color(0xFFBA68C8),
        border: Color(0xFFD1C4E9),
        darkLabel: Color(0xFF4A1E62),
      );
    case 'dermatology_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.handSparkles,
        meshA: Color(0xFFE91E63),
        meshB: Color(0xFFEC407A),
        meshC: Color(0xFFF8BBD0),
        glow: Color(0xFFF06292),
        border: Color(0xFFF48FB1),
        darkLabel: Color(0xFF6A1B3E),
      );
    case 'neurology_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.brain,
        meshA: Color(0xFF5E35B1),
        meshB: Color(0xFF7E57C2),
        meshC: Color(0xFFB39DDB),
        glow: Color(0xFF9575CD),
        border: Color(0xFFB39DDB),
        darkLabel: Color(0xFF341B63),
      );
    case 'obgyn_specialty':
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.personPregnant,
        meshA: Color(0xFFF4511E),
        meshB: Color(0xFFFF7043),
        meshC: Color(0xFFFFAB91),
        glow: Color(0xFFFF8A65),
        border: Color(0xFFFFAB91),
        darkLabel: Color(0xFF6D2A12),
      );
    case 'gastroenterology_specialty':
      return const _SpecialtyVisual(
        svgAsset: 'assets/images/stomach_medical.svg',
        meshA: Color(0xFF43A047),
        meshB: Color(0xFF66BB6A),
        meshC: Color(0xFFA5D6A7),
        glow: Color(0xFF81C784),
        border: Color(0xFFA5D6A7),
        darkLabel: Color(0xFF234B1E),
      );
    default:
      return const _SpecialtyVisual(
        icon: FontAwesomeIcons.stethoscope,
        meshA: Color(0xFF1E88E5),
        meshB: Color(0xFF26C6DA),
        meshC: Color(0xFF80DEEA),
        glow: Color(0xFF4DD0E1),
        border: Color(0xFF80DEEA),
        darkLabel: Color(0xFF123C66),
      );
  }
}

Color _categoryLabelDark(String categoryKey) => _specialtyVisual(categoryKey).darkLabel;
bool _isAllCategory(String categoryKey) => categoryKey == kPatientSpecialtyAllKey;
