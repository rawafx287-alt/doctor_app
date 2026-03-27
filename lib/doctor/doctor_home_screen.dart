import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../baxerhatn_login/login.dart';
import 'appointments_screen.dart';
import 'patient_list_screen.dart';
import 'profile_settings_screen.dart';
import 'schedule_screen.dart';

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF243B53),
          elevation: 0,
          title: const Text(
            'تەختەی کارکردنی پزیشک',
            style: TextStyle(
              color: Color(0xFFD9E2EC),
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'ڕێکخستنەکان',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileSettingsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.settings_rounded),
            ),
            IconButton(
              tooltip: 'چوونەدەرەوە',
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF1D1E33),
          child: SafeArea(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.medical_services_rounded, color: Color(0xFF2CB1BC)),
                  title: Text(
                    'پانێڵی پزیشک',
                    style: TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text(
                    'چوونەدەرەوە',
                    style: TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _logout(context);
                  },
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 380 ? 1 : 2;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: user == null
                          ? null
                          : FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        final doctorName = (data?['fullName'] ?? 'پزیشک').toString();

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1E33),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'بەخێربێیتەوە،',
                                style: TextStyle(
                                  color: Color(0xFF829AB1),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'KurdishFont',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                doctorName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD9E2EC),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26,
                                  fontFamily: 'KurdishFont',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.28,
                      children: [
                        _DashboardCard(
                          title: 'نۆرەکانی من',
                          subtitle: 'بینین و ڕێکخستن',
                          icon: Icons.calendar_month_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AppointmentsScreen(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          title: 'لیستی نەخۆشەکان',
                          subtitle: 'گەڕان بەناو نەخۆشەکاندا',
                          icon: Icons.groups_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PatientListScreen(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          title: 'خشتەی کاتەکان',
                          subtitle: 'دیاریکردنی کاتی دەوام',
                          icon: Icons.schedule_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ScheduleScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF2CB1BC).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2CB1BC)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD9E2EC),
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF829AB1),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'KurdishFont',
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
