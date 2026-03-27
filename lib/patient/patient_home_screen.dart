import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_rtl.dart';
import '../baxerhatn_login/login.dart';
import 'doctor_details_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'هەموو';

  static const List<String> _categories = [
    'هەموو',
    'دڵ',
    'چاو',
    'ددان',
    'منداڵان',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      final lower = q.toLowerCase();
      list = list.where((d) {
        final data = d.data();
        final name = (data['fullName'] ?? '').toString().toLowerCase();
        final spec = (data['specialty'] ?? '').toString().toLowerCase();
        return name.contains(lower) || spec.contains(lower);
      }).toList();
    }
    if (_selectedCategory != 'هەموو') {
      list = list.where((d) {
        final spec = (d.data()['specialty'] ?? '').toString();
        return spec.contains(_selectedCategory);
      }).toList();
    }
    return list;
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF243B53),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          title: const Text(
            'سەرەتا',
            style: TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'چوونەدەرەوە',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (uid != null)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, snap) {
                    final name =
                        (snap.data?.data()?['fullName'] ?? 'نەخۆش').toString();
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
                          'بەخێربێیت، $name',
                          textAlign: TextAlign.right,
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
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontFamily: 'KurdishFont',
                    ),
                    decoration: const InputDecoration(
                      hintText: 'گەڕان بە پزیشک یان پسپۆڕی...',
                      hintStyle: TextStyle(
                        color: Color(0xFF829AB1),
                        fontFamily: 'KurdishFont',
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF2CB1BC)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
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
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'پزیشکە پەسەندکراوەکان',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Color(0xFFD9E2EC),
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'پزیشکەکان کە لەلایەن بەڕێوەبەرەوە قبوڵکراون',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Color(0xFF829AB1).withOpacity(0.9),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
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
              textDirection: kRtlTextDirection,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2CB1BC).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFF2CB1BC),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ناو',
                        textAlign: TextAlign.right,
                        style: _labelStyle,
                      ),
                      Text(
                        name,
                        textAlign: TextAlign.right,
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
                        'پسپۆڕی',
                        textAlign: TextAlign.right,
                        style: _labelStyle,
                      ),
                      Text(
                        specialty,
                        textAlign: TextAlign.right,
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
                children: [
                  Text(
                    'کرتە بکە بۆ نۆرە ووردەکاری',
                    style: TextStyle(
                      color: const Color(0xFF829AB1).withOpacity(0.95),
                      fontFamily: 'KurdishFont',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: const Color(0xFF2CB1BC).withOpacity(0.9),
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
