import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

/// Sticky header heights for [NestedScrollView] + [SliverPersistentHeader].
const double _kHomeSearchHeaderExtent = 56;
const double _kHomeSpecialtiesHeaderExtent = 104;

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
    this.blurSigma = 22,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: patientSpecialtyFilterCategoryKeys.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final catKey = patientSpecialtyFilterCategoryKeys[index];
              final selected = _selectedCategory == catKey;
              const accent = _kVibrantBlue;
              return InkWell(
                onTap: () => setState(() => _selectedCategory = catKey),
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      _CategoryGlassOrb(
                        icon: iconForSpecialtyCategoryKey(catKey),
                        selected: selected,
                        accent: accent,
                      ),
                      const SizedBox(height: 6),
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
                          fontSize: 10,
                          color: selected ? _kDarkBlue : _kMutedGrey,
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

  Widget _buildPatientWelcomeHeader(BuildContext context) {
    final docId = firestoreUserDocId(FirebaseAuth.instance.currentUser);
    if (docId.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(docId).snapshots(),
        builder: (context, snap) {
          final first = _firstNameFromProfile(snap.data?.data());
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  S.of(context).translate(
                    'patient_home_greeting',
                    params: {'name': first},
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kDarkBlue,
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: 0.15,
                    height: 1.2,
                  ),
                ),
              ),
              IconButton(
                tooltip: S.of(context).translate('tooltip_support'),
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const ContactSupportScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.chat_outlined,
                  color: _kVibrantBlue,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _bottomNavIndex = 2),
                  borderRadius: BorderRadius.circular(28),
                  child: _GlassPanel(
                    borderRadius: BorderRadius.circular(28),
                    blurSigma: 18,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.person_rounded,
                        color: _kVibrantBlue,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: S.of(context).translate('tooltip_logout'),
                onPressed: _logout,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: _kMutedGrey,
                ),
              ),
            ],
          );
        },
      ),
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
              child: _bottomNavIndex == 0
                  ? _buildPatientWelcomeHeader(context)
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: IndexedStack(
                index: _bottomNavIndex,
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

/// Circular glass orb (same language-flag language as language picker).
class _CategoryGlassOrb extends StatelessWidget {
  const _CategoryGlassOrb({
    required this.icon,
    required this.selected,
    required this.accent,
  });

  final IconData icon;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.35),
              border: Border.all(
                color: selected ? accent : _kGlassBorder,
                width: selected ? 2 : 0.5,
              ),
            ),
            child: Icon(
              icon,
              size: 26,
              color: selected ? accent : _kMutedGrey,
            ),
          ),
        ),
      ),
    );
  }
}

