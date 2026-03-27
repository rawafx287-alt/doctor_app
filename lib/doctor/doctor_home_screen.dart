import 'package:flutter/material.dart';

import '../app_rtl.dart';
import '../auth/app_logout.dart';
import 'appointments_screen.dart';
import 'doctor_profile_screen.dart';
import 'patient_list_screen.dart';
import 'schedule_screen.dart';

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

  String _appBarTitle() {
    switch (_bottomNavIndex) {
      case 0:
        return 'نۆرەکان';
      case 1:
        return 'خشتەی کات';
      case 2:
        return 'پڕۆفایل';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF243B53),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          title: Text(
            _appBarTitle(),
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          actions: [
            if (_bottomNavIndex != 2) ...[
              IconButton(
                tooltip: 'لیستی نەخۆشەکان',
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
                tooltip: 'چوونەدەرەوە',
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _bottomNavIndex,
            children: const [
              AppointmentsScreen(embedded: true),
              ScheduleScreen(embedded: true),
              DoctorProfileScreen(),
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
            backgroundColor: const Color(0xFF243B53),
            selectedItemColor: const Color(0xFF2CB1BC),
            unselectedItemColor: const Color(0xFF829AB1),
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle:
                const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'نۆرەکان',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.schedule_rounded),
                label: 'خشتەی کات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'پڕۆفایل',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
