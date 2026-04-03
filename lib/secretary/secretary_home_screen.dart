import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calendar/master_calendar_screen.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
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

  static const Color _navActiveGold = Color(0xFFD4A373);
  static const Color _navInactiveGrey = Color(0xFF9CA3AF);

  void _onNavTap(int i) {
    HapticFeedback.lightImpact();
    setState(() => _index = i);
  }

  Widget _buildCompactBottomNav(BuildContext context) {
    final s = S.of(context);
    const topRadius = 24.0;
    const labelStyle = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );

    TextStyle labelFor(bool selected) => labelStyle.copyWith(
          color: selected ? _navActiveGold : _navInactiveGrey,
        );

    Widget item({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final selected = _index == index;
      final color = selected ? _navActiveGold : _navInactiveGrey;

      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onNavTap(index),
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 50,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelFor(selected),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    const dockBg = Color(0xFFF0F7FC);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(topRadius),
              topRight: Radius.circular(topRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, -2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(topRadius),
              topRight: Radius.circular(topRadius),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: dockBg,
                border: Border(
                  top: BorderSide(
                    color: kStaffSilverBorder,
                    width: kStaffCardOutlineWidth,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    item(
                      index: 0,
                      icon: Icons.calendar_month_rounded,
                      label: s.translate('secretary_nav_calendar'),
                    ),
                    item(
                      index: 1,
                      icon: Icons.event_available_rounded,
                      label: s.translate('secretary_nav_available_days'),
                    ),
                    item(
                      index: 2,
                      icon: Icons.list_alt_rounded,
                      label: s.translate('secretary_nav_bookings'),
                    ),
                    item(
                      index: 3,
                      icon: Icons.apartment_rounded,
                      label: s.translate('secretary_nav_clinic'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        extendBody: true,
        backgroundColor: kStaffShellBackground,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
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
        ),
        bottomNavigationBar: _buildCompactBottomNav(context),
      ),
    );
  }
}
