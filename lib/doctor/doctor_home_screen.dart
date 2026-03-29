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
              ),
            ),
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
