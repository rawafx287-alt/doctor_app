import 'package:flutter/material.dart';

import '../calendar/master_calendar_screen.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import 'secretary_available_days_screen.dart';
import 'secretary_bookings_dashboard_screen.dart';
import 'secretary_clinic_settings_screen.dart';

/// Secretary home: calendar + available-days slot view (Firestore role: `Secretary`).
class SecretaryHomeScreen extends StatefulWidget {
  const SecretaryHomeScreen({super.key});

  @override
  State<SecretaryHomeScreen> createState() => _SecretaryHomeScreenState();
}

class _SecretaryHomeScreenState extends State<SecretaryHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            MasterCalendarScreen(
              showDoctorPicker: true,
              canManage: true,
              isRootShell: true,
            ),
            SecretaryAvailableDaysScreen(),
            SecretaryBookingsDashboardScreen(),
            SecretaryClinicSettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: const Color(0xFFB8860B).withValues(alpha: 0.32),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final sel = states.contains(WidgetState.selected);
              return TextStyle(
                fontFamily: 'NRT',
                fontSize: 11.5,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel
                    ? const Color(0xFFD4AF37)
                    : const Color(0xFF829AB1),
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final sel = states.contains(WidgetState.selected);
              return IconThemeData(
                color: sel ? const Color(0xFFD4AF37) : const Color(0xFF829AB1),
                size: 24,
              );
            }),
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: const Color(0xFF1D1E33),
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_rounded),
                selectedIcon: const Icon(Icons.calendar_month),
                label: s.translate('secretary_nav_calendar'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.event_available_outlined),
                selectedIcon: const Icon(Icons.event_available),
                label: s.translate('secretary_nav_available_days'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.list_alt_outlined),
                selectedIcon: const Icon(Icons.list_alt_rounded),
                label: s.translate('secretary_nav_bookings'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.apartment_outlined),
                selectedIcon: const Icon(Icons.apartment_rounded),
                label: s.translate('secretary_nav_clinic'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
