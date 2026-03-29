import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../auth/app_logout.dart';
import 'appointments_screen.dart';
import 'doctor_profile_screen.dart';
import 'patient_list_screen.dart';
import 'available_days_schedule_screen.dart';
import '../calendar/master_calendar_screen.dart';

/// Doctor shell: 3 tabs (appointments, schedule, profile) with [IndexedStack].
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  /// 0 = appointments, 1 = schedule, 2 = profile
  int _bottomNavIndex = 0;

  Future<void> _logout() async {
    await performAppLogout(context);
  }

  String _appBarTitle(BuildContext context) {
    final s = S.of(context);
    switch (_bottomNavIndex) {
      case 0:
        return s.translate('doctor_nav_appointments');
      case 1:
        return s.translate('schedule_screen_title');
      case 2:
        return s.translate('doctor_nav_profile');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          title: Text(
            _appBarTitle(context),
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          actions: [
            if (_bottomNavIndex != 2) ...[
              IconButton(
                tooltip: s.translate('master_calendar_tooltip'),
                onPressed: () {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => MasterCalendarScreen(
                        doctorId: uid,
                        canManage: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_view_month_rounded),
              ),
              IconButton(
                tooltip: s.translate('doctor_tooltip_patient_list'),
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const PatientListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.groups_rounded),
              ),
              IconButton(
                tooltip: s.translate('tooltip_logout'),
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ],
        ),
<<<<<<< HEAD
        drawer: Drawer(
          backgroundColor: const Color(0xFF1D1E33),
          child: SafeArea(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFF2CB1BC),
                  ),
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
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
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
                      : FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final doctorName = (data?['fullName'] ?? 'پزیشک')
                        .toString();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 380 ? 1 : 2;
                    return GridView.count(
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
                                builder: (context) =>
                                    const AppointmentsScreen(),
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

  static const Color _surface = Color(0xFF1D1E33);
  static const Color _accent = Color(0xFF2CB1BC);

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
=======
        body: SafeArea(
          child: IndexedStack(
            index: _bottomNavIndex,
            children: [
              const AppointmentsScreen(embedded: true),
              const AvailableDaysScheduleScreen(embedded: true),
              const DoctorProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: const Color(0xFF829AB1).withValues(alpha: 0.35),
                width: 0.5,
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
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
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _bottomNavIndex,
            onTap: (index) {
              setState(() => _bottomNavIndex = index);
            },
            backgroundColor: const Color(0xFF1A237E),
            selectedItemColor: const Color(0xFF42A5F5),
            unselectedItemColor: const Color(0xFF829AB1),
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle:
                const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month),
                label: s.translate('doctor_nav_appointments'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.schedule_rounded),
                label: s.translate('doctor_nav_schedule'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: s.translate('doctor_nav_profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
