import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../specialty_categories.dart';
import 'contact_support_screen.dart';
import 'doctor_details_screen.dart';
import 'my_appointments_screen.dart';
import 'patient_doctor_card.dart';
import 'patient_hospitals_browse_tab.dart';
import 'patient_profile_screen.dart';

/// Sticky header heights for [NestedScrollView] + [SliverPersistentHeader].
const double _kHomeSearchHeaderExtent = 56;
const double _kHomeSpecialtiesHeaderExtent = 92;

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Bottom nav: 0 home, 1 appointments, 2 hospitals, 3 profile
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

  /// Slim search field used under the app bar (sticky).
  Widget _buildThinSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15182C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          textAlign: TextAlign.start,
          style: const TextStyle(
            color: Color(0xFFD9E2EC),
            fontFamily: 'KurdishFont',
            fontSize: 14,
            height: 1.2,
          ),
          cursorColor: const Color(0xFF42A5F5),
          decoration: InputDecoration(
            isDense: true,
            hintText: S.of(context).translate('search_doctors_hint'),
            hintStyle: TextStyle(
              color: const Color(0xFF829AB1).withValues(alpha: 0.9),
              fontFamily: 'KurdishFont',
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF42A5F5),
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
                color: Color(0xFFD9E2EC),
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: patientSpecialtyFilterCategoryKeys.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final catKey = patientSpecialtyFilterCategoryKeys[index];
              final selected = _selectedCategory == catKey;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedCategory = catKey),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF42A5F5).withValues(alpha: 0.22)
                          : const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF42A5F5)
                            : Colors.white24,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: AppLocaleScope.of(context).textDirection,
                      children: [
                        Icon(
                          iconForSpecialtyCategoryKey(catKey),
                          size: 18,
                          color: selected
                              ? const Color(0xFF42A5F5)
                              : const Color(0xFF829AB1),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          S.of(context).translate(catKey),
                          style: TextStyle(
                            fontFamily: 'KurdishFont',
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            fontSize: 13,
                            color: selected
                                ? const Color(0xFFD9E2EC)
                                : const Color(0xFF829AB1),
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
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDoctorsListBody(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _approvedDoctorsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
          );
        }
        final docs = snapshot.data?.docs ?? [];
        final filtered = _applyLocalFilters(docs);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
          separatorBuilder: (context, index) {
            if (index == 0) return const SizedBox(height: 8);
            return const SizedBox(height: 12);
          },
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    S.of(context).translate('recommended_doctors'),
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
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
                      color: const Color(0xFF829AB1).withValues(alpha: 0.9),
                      fontFamily: 'KurdishFont',
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }
            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  S.of(context).translate('doctors_empty_search'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                    fontSize: 16,
                  ),
                ),
              );
            }
            final doc = filtered[index - 1];
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
            return PatientDoctorCard(
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
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await performAppLogout(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          title: Text(
            _bottomNavIndex == 0
                ? S.of(context).translate('app_display_name')
                : _bottomNavIndex == 1
                ? S.of(context).translate('appointments')
                : _bottomNavIndex == 2
                ? S.of(context).translate('hospitals_section')
                : S.of(context).translate('profile'),
            style: _bottomNavIndex == 0
                ? const TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    letterSpacing: 0.35,
                  )
                : const TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                  ),
          ),
          actions: [
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
              icon: const Icon(Icons.chat_outlined),
            ),
            if (_bottomNavIndex != 3)
              IconButton(
                tooltip: S.of(context).translate('tooltip_logout'),
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _bottomNavIndex,
            children: [
              PatientHomeContent._(this),
              const PatientAppointmentsScreen(embedded: true),
              const PatientHospitalsBrowseTab(),
              const PatientProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: const Color(0xFF829AB1).withValues(alpha: 0.35),
                width: 0.5,
              ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sticky search + specialties; doctor list scrolls below.
  Widget _buildHomeContent() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickySectionDelegate(
              extent: _kHomeSearchHeaderExtent,
              builder: (context, shrinkOffset, overlapsContent) {
                return Material(
                  color: const Color(0xFF0A0E21),
                  surfaceTintColor: Colors.transparent,
                  elevation: overlapsContent ? 3 : 0,
                  shadowColor: Colors.black54,
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
                  color: const Color(0xFF0A0E21),
                  surfaceTintColor: Colors.transparent,
                  elevation: overlapsContent ? 2 : 0,
                  shadowColor: Colors.black45,
                  child: _buildPinnedSpecialtiesSection(context),
                );
              },
            ),
          ),
        ];
      },
      body: KeyedSubtree(
        key: const ValueKey<String>('home_doctors_list'),
        child: _buildDoctorsListBody(context),
      ),
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
