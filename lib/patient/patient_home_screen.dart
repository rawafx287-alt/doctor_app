import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/app_logout.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../specialty_categories.dart';
import 'contact_support_screen.dart';
import 'doctor_details_screen.dart';
import 'patient_doctor_booking_screen.dart';
import 'patient_doctor_card.dart';
import 'patient_profile_screen.dart';
import 'patient_scroll_physics.dart';
import '../theme/patient_premium_theme.dart';
import 'my_appointments_screen.dart';

/// Sticky header heights for [SliverPersistentHeader] (keep in sync with widgets).
const double _kHomeSearchHeaderExtent = 48;
const double _kHomeSpecialtiesHeaderExtent = 122;

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
      return const Color(0xFF00796B);
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
      return const Color(0xFF2E7D32);
    default:
      return const Color(0xFF1976D2);
  }
}

/// Sky blue glass patient shell.
const Color _kSkyTop = kPatientSkyTop;
const Color _kSkyBottom = kPatientSkyBottom;
const Color _kCharcoal = Color(0xFF333333);
const Color _kDarkBlue = Color(0xFF0D47A1);
const Color _kMutedGrey = Color(0xFF546E7A);
const Color _kVibrantBlue = Color(0xFF1976D2);
/// Matches doctor card border ([PatientDoctorCard]).
const Color _kPremiumDeepBlue = Color(0xFF1A237E);
/// Same as doctor name text on cards ([PatientDoctorCard]).
const Color _kDoctorNameNavy = Color(0xFF0D2137);
const Color _kPremiumBlueMid = Color(0xFF1565C0);
const Color _kIconGradientLight = Color(0xFF90CAF9);

/// Near-clear crystal: barely-there blur (sigma 0.5 — tiny glass hint).
const double _kPopupMenuBlurSigma = 0.5;

/// Readable label on very light glass (darker for contrast).
const Color _kMenuPopupText = Color(0xFF0D1117);

/// Deep red frame: menu outline, logout side stripe, and logout icon (Material Red 700).
const Color _kMenuPopupDeepRed = Color(0xFFD32F2F);
/// Crisp outline on crystal-clear glass (readable shape).
const double _kMenuPopupFrameWidth = 2.0;

/// One overflow menu row: light blur, gradient strip, [accentBorder] on start edge.
Widget _patientOverflowMenuTile({
  required Color accentBorder,
  required IconData iconData,
  required Color iconColor,
  required String text,
}) {
  return Material(
    type: MaterialType.transparency,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _kPopupMenuBlurSigma,
          sigmaY: _kPopupMenuBlurSigma,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                Colors.white.withValues(alpha: 0.02),
                Colors.transparent,
              ],
            ),
            border: BorderDirectional(
              start: BorderSide(color: accentBorder, width: 3),
            ),
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.25,
                    color: _kMenuPopupText,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.65),
                        blurRadius: 1.5,
                        offset: const Offset(0, 0.5),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  /// Bottom nav: 0 home, 1 appointments, 2 profile
  int _bottomNavIndex = 0;

  /// Full-screen frosted dim behind the overflow menu.
  late final AnimationController _menuDimController;
  late final Animation<double> _menuDimCurve;

  String _selectedCategory = kPatientSpecialtyAllKey;

  /// Single subscription: all approved doctors (filter locally for category + search).
  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _approvedDoctorsStream = FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'Doctor')
      .where('isApproved', isEqualTo: true)
      .snapshots();

  /// Maps selected chip key ([kPatientSpecialtyAllKey] or translation key) to Firestore `specialty` string.
  String _firestoreValueForSelectedCategory() {
    for (final d in kDoctorSpecialtyDefinitions) {
      if (d.translationKey == _selectedCategory) return d.firestoreValue;
    }
    return _selectedCategory;
  }

  /// Local filter: specialty chip, then name/specialty search.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

    if (_selectedCategory != kPatientSpecialtyAllKey) {
      final firestoreValue = _firestoreValueForSelectedCategory();
      list = list.where((d) {
        final spec = (d.data()['specialty'] ?? '').toString().trim();
        return spec == firestoreValue;
      }).toList();
    }

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
    const radius = 20.0;
    const borderW = 0.8;
    final innerRadius = radius - borderW;
    const hintGrey = Color(0xFF455A64);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF90CAF9).withValues(alpha: 0.16),
                  blurRadius: 20,
                  spreadRadius: 3,
                  offset: const Offset(0, 10),
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
                      onChanged: (_) => setState(() {}),
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        color: _kCharcoal,
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w600,
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
                          fontFamily: 'KurdishFont',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.2,
                          letterSpacing: 0.18,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _kDoctorNameNavy,
                          size: 20,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 32,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
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

  Widget _buildPinnedSpecialtiesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              S.of(context).translate('specialties'),
              style: const TextStyle(
                color: _kDarkBlue,
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 74,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            physics: patientPlatformScrollPhysics,
            itemCount: patientSpecialtyFilterCategoryKeys.isEmpty
                ? 0
                : patientSpecialtyFilterCategoryKeys.length * 2 - 1,
            itemBuilder: (context, index) {
              if (index.isOdd) {
                return const SizedBox(width: 8);
              }
              final catKey =
                  patientSpecialtyFilterCategoryKeys[index ~/ 2];
              final selected = _selectedCategory == catKey;
              final soft = _categorySoftTint(catKey);
              final acc = _categoryAccentIcon(catKey);
              return InkWell(
                onTap: () => setState(() => _selectedCategory = catKey),
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 58,
                  child: Column(
                    children: [
                      _CategoryGlassOrb(
                        icon: iconForSpecialtyCategoryKey(catKey),
                        selected: selected,
                        softTint: soft,
                        accent: acc,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        S.of(context).translate(catKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 9.5,
                          height: 1.15,
                          color: selected ? acc : _kMutedGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
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
                  fontFamily: 'KurdishFont',
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

    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.of(context).translate('recommended_doctors'),
              textAlign: TextAlign.start,
              style: const TextStyle(
                color: _kDarkBlue,
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              S.of(context).translate('recommended_doctors_sub'),
              textAlign: TextAlign.start,
              style: TextStyle(
                color: _kMutedGrey.withValues(alpha: 0.95),
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (filtered.isEmpty) {
      return [
        header,
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, padBottom),
            child: Text(
              S.of(context).translate('doctors_empty_search'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kMutedGrey,
                fontFamily: 'KurdishFont',
                fontSize: 16,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      header,
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, padBottom),
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
  }

  @override
  void dispose() {
    _menuDimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _dismissMenuDim() {
    if (_menuDimController.isDismissed) return;
    _menuDimController.reverse();
  }

  Future<void> _logout() async {
    await performAppLogout(context);
  }

  /// Centered app title + overflow menu (profile / feedback / sign out).
  Widget _buildAppTopBar(BuildContext context) {
    final s = S.of(context);
    final title = s.translate('app_display_name');
    final titleStyle = GoogleFonts.poppins(
      fontWeight: FontWeight.w900,
      fontSize: 22,
      letterSpacing: 0.2,
      color: _kDarkBlue,
    );

    // Snug to the ⋮; small negative dx keeps the panel near the right edge; dy aligns
    // vertically so it reads as opening from the icon.
    const menuOffset = Offset(-10, 45);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 12, 6),
      child: Row(
        // LTR keeps "HR Nora" on the left and the ⋮ menu on the right in RTL apps.
        textDirection: TextDirection.ltr,
        children: [
          Text(title, style: titleStyle),
          const Spacer(),
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: Colors.transparent,
                elevation: 12,
                surfaceTintColor: Colors.transparent,
                shadowColor: _kMenuPopupDeepRed.withValues(alpha: 0.42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: _kMenuPopupDeepRed,
                    width: _kMenuPopupFrameWidth,
                  ),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              tooltip: '',
              color: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 12,
              shadowColor: _kMenuPopupDeepRed.withValues(alpha: 0.42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: _kMenuPopupDeepRed,
                  width: _kMenuPopupFrameWidth,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 232),
              offset: menuOffset,
              icon: const Icon(Icons.more_vert_rounded, color: _kDarkBlue),
              onOpened: () {
                _menuDimController.forward();
              },
              onCanceled: _dismissMenuDim,
              onSelected: (value) async {
                _dismissMenuDim();
                if (!context.mounted) return;
                if (value == 'profile') {
                  setState(() => _bottomNavIndex = 2);
                } else if (value == 'feedback') {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const ContactSupportScreen(),
                    ),
                  );
                } else if (value == 'logout') {
                  await _logout();
                }
              },
              itemBuilder: (ctx) {
                return [
                  PopupMenuItem<String>(
                    value: 'profile',
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: _patientOverflowMenuTile(
                      accentBorder: Colors.blueAccent,
                      iconData: Icons.person_rounded,
                      iconColor: Colors.blueAccent,
                      text: s.translate('profile'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'feedback',
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: _patientOverflowMenuTile(
                      accentBorder: Colors.tealAccent,
                      iconData: Icons.feedback_outlined,
                      iconColor: Colors.tealAccent,
                      text: s.translate('patient_home_menu_feedback'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'logout',
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: _patientOverflowMenuTile(
                      accentBorder: _kMenuPopupDeepRed,
                      iconData: Icons.logout_rounded,
                      iconColor: _kMenuPopupDeepRed,
                      text: s.translate('logout'),
                    ),
                  ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBottomNav(BuildContext context) {
    final s = S.of(context);
    const dockRadius = 30.0;

    Widget navIcon(IconData iconData, bool selected) {
      const size = 23.0;
      if (!selected) {
        return Icon(
          iconData,
          size: size,
          color: _kMutedGrey,
        );
      }
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _kIconGradientLight,
              _kPremiumDeepBlue,
            ],
          ).createShader(bounds);
        },
        child: Icon(
          iconData,
          size: size,
          color: Colors.white,
        ),
      );
    }

    Widget item(int index, IconData icon, String label) {
      final selected = _bottomNavIndex == index;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _bottomNavIndex = index),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 8,
                    child: selected
                        ? Center(
                            child: Container(
                              width: 24,
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    _kIconGradientLight,
                                    _kPremiumDeepBlue,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kIconGradientLight.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 4,
                                    spreadRadius: 0,
                                  ),
                                  BoxShadow(
                                    color: _kPremiumDeepBlue.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  navIcon(icon, selected),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'KurdishFont',
                      fontSize: 10,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: selected ? 0.25 : 0.12,
                      color: selected
                          ? _kPremiumDeepBlue
                          : _kMutedGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.92),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    children: [
                      item(0, Icons.home_rounded, s.translate('home')),
                      item(
                        1,
                        Icons.calendar_month_rounded,
                        s.translate('appointments'),
                      ),
                      item(2, Icons.person_rounded, s.translate('profile')),
                    ],
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
        backgroundColor: _kSkyTop,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kSkyTop, _kSkyBottom],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
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
                  _buildGlassBottomNav(context),
                ],
              ),
<<<<<<< HEAD
<<<<<<< HEAD
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final selected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'KurdishFont',
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? const Color(0xFF102A43) : const Color(0xFFD9E2EC),
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: const Color(0xFF2CB1BC),
                      backgroundColor: const Color(0xFF1D1E33),
                      side: BorderSide(color: selected ? const Color(0xFF2CB1BC) : Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    );
                  },
                ),
=======
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _bottomNavIndex,
            onTap: (index) => setState(() => _bottomNavIndex = index),
            backgroundColor: const Color(0xFF1A237E),
            selectedItemColor: const Color(0xFF42A5F5),
            unselectedItemColor: const Color(0xFF829AB1),
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontFamily: 'KurdishFont',
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'KurdishFont',
              fontSize: 12,
            ),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_filled),
                label: S.of(context).translate('home'),
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month),
                label: S.of(context).translate('appointments'),
              ),
<<<<<<< HEAD
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      // تەنها پزیشکە ڕەسەنەکراوەکان (قبوڵکراون لەلایەن بەڕێوەبەر)
                      .where('role', isEqualTo: 'Doctor')
                      .where('isApproved', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF2CB1BC)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'هەڵە لە بارکردنی لیست (${snapshot.error})',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontFamily: 'KurdishFont',
                            ),
                          ),
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    final filtered = _filterDocs(docs);
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'هیچ پزیشکێک نەدۆزرایەوە',
                          style: TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'KurdishFont',
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();
                        final name = (data['fullName'] ?? '—').toString();
                        final specialty = (data['specialty'] ?? '—').toString();
                        return _DoctorCard(
                          name: name,
                          specialty: specialty,
                          onOpenDetails: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DoctorDetailsScreen(
                                  doctorId: doc.id,
                                  doctorData: Map<String, dynamic>.from(data),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
=======
              BottomNavigationBarItem(
                icon: const Icon(Icons.local_hospital_rounded),
                label: S.of(context).translate('hospitals_section'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: S.of(context).translate('profile'),
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
=======
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
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Single [CustomScrollView]: pinned headers + doctor slivers (no nested scroll overflow).
  Widget _buildHomeContent() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _approvedDoctorsStream,
      builder: (context, snapshot) {
        return CustomScrollView(
          key: const ValueKey<String>('home_doctors_scroll'),
          physics: patientHomePrimaryScrollPhysics,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySectionDelegate(
                extent: _kHomeSearchHeaderExtent,
                builder: (context, shrinkOffset, overlapsContent) {
                  return Material(
                    color: _kSkyTop,
                    surfaceTintColor: Colors.transparent,
                    elevation: overlapsContent ? 2 : 0,
                    shadowColor: Colors.black26,
                    child: _buildThinSearchBar(context),
                  );
                },
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySectionDelegate(
                extent: _kHomeSpecialtiesHeaderExtent,
                builder: (context, shrinkOffset, overlapsContent) {
                  return Material(
                    color: _kSkyTop,
                    surfaceTintColor: Colors.transparent,
                    elevation: overlapsContent ? 2 : 0,
                    shadowColor: Colors.black26,
                    child: _buildPinnedSpecialtiesSection(context),
                  );
                },
              ),
            ),
            ..._buildDoctorSlivers(context, snapshot),
          ],
        );
      },
    );
  }
}

/// Fixed-height pinned block for [SliverPersistentHeader].
class _StickySectionDelegate extends SliverPersistentHeaderDelegate {
  _StickySectionDelegate({required this.extent, required this.builder});

  final double extent;
  final Widget Function(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  )
  builder;

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
      child: builder(context, shrinkOffset, overlapsContent),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySectionDelegate oldDelegate) => true;
}

/// Home tab body for [PatientHomeScreen] (doctors browse only).
class PatientHomeContent extends StatelessWidget {
  const PatientHomeContent._(this._state);

  final _PatientHomeScreenState _state;

  @override
  Widget build(BuildContext context) => _state._buildHomeContent();
}

/// Circular glass orb with per-category soft tint (hairline white rim + selected glow).
class _CategoryGlassOrb extends StatelessWidget {
  const _CategoryGlassOrb({
    required this.icon,
    required this.selected,
    required this.softTint,
    required this.accent,
  });

  final IconData icon;
  final bool selected;
  final Color softTint;
  final Color accent;

  static const double _orbSize = 48;
  static const double _iconSize = 23;

  @override
  Widget build(BuildContext context) {
    final fill = Color.alphaBlend(
      softTint.withValues(alpha: selected ? 0.26 : 0.16),
      Colors.white.withValues(alpha: selected ? 0.38 : 0.28),
    );
    return SizedBox(
      width: _orbSize,
      height: _orbSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.48),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: 3,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: Border.all(
                  color: selected
                      ? accent
                      : Colors.white.withValues(alpha: 0.88),
                  width: selected ? 2.25 : 0.9,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: _iconSize,
                  color: selected ? accent : _kMutedGrey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

