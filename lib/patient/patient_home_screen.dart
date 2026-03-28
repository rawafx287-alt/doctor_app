import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../specialty_categories.dart';
import 'contact_support_screen.dart';
import 'doctor_details_screen.dart';
import 'my_appointments_screen.dart';
import 'patient_profile_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Bottom nav: 0 = home, 1 = appointments, 2 = profile
  int _bottomNavIndex = 0;

  String _selectedCategory = kPatientSpecialtyAllKey;

  /// Single subscription: all approved doctors (filter locally for category + search).
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _approvedDoctorsStream =
      FirebaseFirestore.instance
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
      final name = (data['fullName'] ?? '').toString().toLowerCase();
      final spec = (data['specialty'] ?? '').toString().toLowerCase();
      return name.contains(lower) || spec.contains(lower);
    }).toList();
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
                ? S.of(context).translate('home')
                : _bottomNavIndex == 1
                    ? S.of(context).translate('appointments')
                    : S.of(context).translate('profile'),
            style: const TextStyle(
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
            if (_bottomNavIndex != 2)
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
            selectedLabelStyle: const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_filled),
                label: S.of(context).translate('home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month),
                label: S.of(context).translate('appointments'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: S.of(context).translate('profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Doctor list tab (search, categories, list).
  Widget _buildHomeContent() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (uid != null)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, snap) {
                    final name = (snap.data?.data()?['fullName'] ??
                            S.of(context).translate('patient_default'))
                        .toString();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          S.of(context)
                              .translate('welcome_user', params: {'name': name}),
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            color: Color(0xFFD9E2EC),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontFamily: 'KurdishFont',
                    ),
                    decoration: InputDecoration(
                      hintText: S.of(context).translate('search_doctors_hint'),
                      hintStyle: const TextStyle(
                        color: Color(0xFF829AB1),
                        fontFamily: 'KurdishFont',
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF42A5F5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    S.of(context).translate('specialties'),
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontFamily: 'KurdishFont',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: patientSpecialtyFilterCategoryKeys.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final catKey = patientSpecialtyFilterCategoryKeys[index];
                    final selected = _selectedCategory == catKey;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategory = catKey),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF42A5F5).withOpacity(0.22)
                                : const Color(0xFF1D1E33),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? const Color(0xFF42A5F5) : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection:
                                AppLocaleScope.of(context).textDirection,
                            children: [
                              Icon(
                                iconForSpecialtyCategoryKey(catKey),
                                size: 20,
                                color: selected
                                    ? const Color(0xFF42A5F5)
                                    : const Color(0xFF829AB1),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                S.of(context).translate(catKey),
                                style: TextStyle(
                                  fontFamily: 'KurdishFont',
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                  fontSize: 14,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
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
                        color: const Color(0xFF829AB1).withOpacity(0.9),
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _approvedDoctorsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              S.of(context).translate(
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
                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              S.of(context).translate('doctors_empty_search'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF829AB1),
                                fontFamily: 'KurdishFont',
                                fontSize: 16,
                              ),
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
                          final specialtyRaw = (data['specialty'] ?? '—').toString();
                          final specialty =
                              translatedSpecialtyForFirestore(context, specialtyRaw);
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
                ),
              ),
            ],
    );
  }
}

/// First tab body for [PatientHomeScreen] (doctors search & list).
class PatientHomeContent extends StatelessWidget {
  const PatientHomeContent._(this._state);

  final _PatientHomeScreenState _state;

  @override
  Widget build(BuildContext context) => _state._buildHomeContent();
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.name,
    required this.specialty,
    required this.onOpenDetails,
  });

  final String name;
  final String specialty;
  final VoidCallback onOpenDetails;

  /// Standard doctor avatar (no Firebase Storage).
  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  static const TextStyle _labelStyle = TextStyle(
    color: Color(0xFF829AB1),
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFamily: 'KurdishFont',
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
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
                    border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      _placeholderImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF1D1E33),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Color(0xFF42A5F5),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).translate('field_name'),
                        textAlign: TextAlign.start,
                        style: _labelStyle,
                      ),
                      Text(
                        name,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: Color(0xFFD9E2EC),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'KurdishFont',
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        S.of(context).translate('field_specialty'),
                        textAlign: TextAlign.start,
                        style: _labelStyle,
                      ),
                      Text(
                        specialty,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: Color(0xFF829AB1),
                          fontSize: 15,
                          fontFamily: 'KurdishFont',
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                textDirection: Directionality.of(context),
                children: [
                  Text(
                    S.of(context).translate('click_for_details'),
                    style: TextStyle(
                      color: const Color(0xFF829AB1).withOpacity(0.95),
                      fontFamily: 'KurdishFont',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: const Color(0xFF42A5F5).withOpacity(0.9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
