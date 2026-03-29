import 'package:flutter/material.dart';

import '../calendar/master_calendar_screen.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import 'secretary_available_days_screen.dart';

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
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 72,
          backgroundColor: const Color(0xFF1D1E33),
          indicatorColor: const Color(0xFF42A5F5).withValues(alpha: 0.35),
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
          ],
        ),
      ),
    );
  }
}
