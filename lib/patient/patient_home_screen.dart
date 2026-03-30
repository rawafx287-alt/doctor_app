import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/app_logout.dart';
import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../specialty_categories.dart';
import 'contact_support_screen.dart';
import 'doctor_details_screen.dart';
import 'patient_doctor_card.dart';
import 'patient_profile_screen.dart';
import 'my_appointments_screen.dart';

/// Sticky header heights for [SliverPersistentHeader].
const double _kHomeSearchHeaderExtent = 56;
const double _kHomeSpecialtiesHeaderExtent = 110;

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
const Color _kSkyTop = Color(0xFFE1F5FE);
const Color _kSkyBottom = Color(0xFFB3E5FC);
const Color _kCharcoal = Color(0xFF333333);
const Color _kDarkBlue = Color(0xFF0D47A1);
const Color _kMutedGrey = Color(0xFF546E7A);
const Color _kGlassWhite = Color(0x66FFFFFF);
const Color _kGlassBorder = Color(0xE6FFFFFF);
const Color _kVibrantBlue = Color(0xFF1976D2);

/// Frosted glass: blur + semi-transparent fill + hairline white border.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.borderRadius,
    required this.child,
  });

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _kGlassWhite,
            borderRadius: borderRadius,
            border: Border.all(color: _kGlassBorder, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Bottom nav: 0 home, 1 appointments, 2 profile
  int _bottomNavIndex = 0;

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _GlassPanel(
            borderRadius: BorderRadius.circular(14),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.start,
              style: const TextStyle(
                color: _kCharcoal,
                fontFamily: 'KurdishFont',
                fontSize: 14,
                height: 1.2,
              ),
              cursorColor: _kVibrantBlue,
              decoration: InputDecoration(
                isDense: true,
                hintText: S.of(context).translate('search_doctors_hint'),
                hintStyle: TextStyle(
                  color: _kMutedGrey.withValues(alpha: 0.9),
                  fontFamily: 'KurdishFont',
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _kVibrantBlue,
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 36,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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
        const SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: patientSpecialtyFilterCategoryKeys.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final catKey = patientSpecialtyFilterCategoryKeys[index];
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
                      const SizedBox(height: 4),
                      Text(
                        S.of(context).translate(catKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'KurdishFont',
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 9,
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
        const SizedBox(height: 8),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
            const SizedBox(height: 4),
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
            const SizedBox(height: 8),
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
              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                child: PatientDoctorCard(
                  name: name,
                  specialty: specialty,
                  onOpenDetails: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => DoctorDetailsScreen(
                          doctorId: doc.id,
                          doctorData: Map<String, dynamic>.from(data),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            childCount: filtered.length,
          ),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await performAppLogout(context);
  }

  String _firstNameFromProfile(Map<String, dynamic>? data) {
    if (data == null) return '—';
    final first = (data['firstName'] ?? '').toString().trim();
    if (first.isNotEmpty) return first;
    final full = (data['fullName'] ?? '').toString().trim();
    if (full.isEmpty) return '—';
    final parts = full.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '—';
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

    Widget menuRow({
      required IconData icon,
      required String text,
      required Color iconColor,
      required Color textColor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 12, 6),
      child: Row(
        children: [
          Text(title, style: titleStyle),
          const Spacer(),
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: Colors.white.withValues(alpha: 0.92),
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Colors.black.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: _kDarkBlue),
              offset: const Offset(0, 46),
              onSelected: (value) async {
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
              itemBuilder: (ctx) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  padding: EdgeInsets.zero,
                  child: menuRow(
                    icon: Icons.person_rounded,
                    text: s.translate('profile'),
                    iconColor: _kDarkBlue,
                    textColor: _kDarkBlue,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'feedback',
                  padding: EdgeInsets.zero,
                  child: menuRow(
                    icon: Icons.feedback_outlined,
                    text: s.translate('patient_home_menu_feedback'),
                    iconColor: _kDarkBlue,
                    textColor: _kDarkBlue,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  padding: EdgeInsets.zero,
                  child: menuRow(
                    icon: Icons.logout_rounded,
                    text: s.translate('logout'),
                    iconColor: const Color(0xFFB91C1C),
                    textColor: const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Greeting above search (scrolls with home content).
  Widget _buildHomeGreetingBanner(BuildContext context) {
    final docId = firestoreUserDocId(FirebaseAuth.instance.currentUser);
    if (docId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .snapshots(),
      builder: (context, snap) {
        final first = _firstNameFromProfile(snap.data?.data());
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              S.of(context).translate(
                'patient_home_greeting',
                params: {'name': first},
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kCharcoal,
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1.25,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassBottomNav(BuildContext context) {
    final s = S.of(context);
    Widget item(int index, IconData icon, String label) {
      final selected = _bottomNavIndex == index;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _bottomNavIndex = index),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 26,
                    color: selected ? _kVibrantBlue : _kMutedGrey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'KurdishFont',
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? _kDarkBlue : _kMutedGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.85),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  item(0, Icons.home_rounded, s.translate('home')),
                  item(1, Icons.calendar_month_rounded, s.translate('appointments')),
                  item(2, Icons.person_rounded, s.translate('profile')),
                ],
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
          child: Column(
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHomeGreetingBanner(context)),
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

/// Circular glass orb with per-category soft tint.
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

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.withValues(alpha: selected ? 0.4 : 0.26);
    final fill = Color.alphaBlend(
      softTint.withValues(alpha: selected ? 0.48 : 0.34),
      base,
    );
    return SizedBox(
      width: 44,
      height: 44,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: selected ? accent : _kGlassBorder,
                width: selected ? 2 : 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected ? accent : _kMutedGrey,
            ),
          ),
        ),
      ),
    );
  }
}

