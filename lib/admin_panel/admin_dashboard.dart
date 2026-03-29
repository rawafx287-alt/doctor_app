import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../auth/app_logout.dart';
import 'add_doctor_screen.dart';
import 'approval_list_screen.dart';
import 'admin_feedback_screen.dart';
import 'doctor_management_screen.dart';
import 'admin_hospital_management_screen.dart';
import '../calendar/master_calendar_screen.dart';
import '../locale/app_localizations.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'پەڕەی ئەدمین',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'چوونەدەرەوە',
            onPressed: () async => performAppLogout(context),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _DashboardCard(
                title: S.of(context).translate('master_calendar_tooltip'),
                subtitle: S.of(context).translate('master_calendar_subtitle'),
                icon: Icons.calendar_month_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const MasterCalendarScreen(
                        showDoctorPicker: true,
                        canManage: true,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _DashboardCard(
                title: 'بۆچوونەکان',
                subtitle: 'بۆچوون و پێشنیارەکانی نەخۆشەکان',
                icon: Icons.feedback_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminFeedbackScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _DashboardCard(
                title: 'نەخۆشخانەکان',
                subtitle: 'زیادکردن و سڕینەوەی نەخۆشخانە لە داتابەیس',
                icon: Icons.local_hospital_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const AdminHospitalManagementScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _DashboardCard(
                title: 'داواکارییەکان',
                subtitle: 'پزیشکەکان کە چاوەڕێی قبوڵکردنن',
                icon: Icons.inbox_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApprovalListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _DashboardCard(
                title: 'لیستی پزیشکان',
                subtitle: 'پزیشکە قبوڵکراوەکان و سڕینەوە',
                icon: Icons.groups_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DoctorManagementScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _DashboardCard(
                title: 'زیادکردنی پزیشک',
                subtitle: 'زیادکردنی پزیشک بە دەستی',
                icon: Icons.person_add_alt_1_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddDoctorScreen(),
                    ),
                  );
                },
              ),
            ],
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
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                ),
                child: Icon(icon, color: Colors.blueAccent, size: 56),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

