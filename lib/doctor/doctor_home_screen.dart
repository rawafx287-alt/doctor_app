import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_rtl.dart';
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
      textDirection: kRtlTextDirection,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: user == null
                      ? null
                      : FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final doctorName = (data?['fullName'] ?? 'پزیشک').toString();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'بەخێربێیتەوە،',
                            style: TextStyle(
                              color: Color(0xFF829AB1),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'KurdishFont',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctorName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD9E2EC),
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              fontFamily: 'KurdishFont',
                            ),
                          ),
<<<<<<< HEAD
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
                      childAspectRatio: crossAxisCount == 1 ? 0.92 : 0.88,
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
=======
                        ],
                      ),
                    );
                  },
>>>>>>> 19b5e8db7f46545d607efa3593b4bf4f10a921fc
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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

<<<<<<< HEAD
  static const Color _surface = Color(0xFF1D1E33);
  static const Color _accent = Color(0xFF2CB1BC);
=======
  static const double _cardHeight = 128;
>>>>>>> 19b5e8db7f46545d607efa3593b4bf4f10a921fc

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.2),
                ),
                child: Icon(icon, color: _accent, size: 56),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD9E2EC),
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  fontFamily: 'KurdishFont',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  fontFamily: 'KurdishFont',
                ),
=======
    return SizedBox(
      width: double.infinity,
      height: _cardHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                textDirection: kRtlTextDirection,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2CB1BC).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFF2CB1BC), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFFD9E2EC),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.3,
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
>>>>>>> 19b5e8db7f46545d607efa3593b4bf4f10a921fc
              ),
            ),
          ),
        ),
      ),
    );
  }
}
