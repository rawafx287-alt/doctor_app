import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calendar/master_calendar_screen.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import '../doctor/doctor_premium_shell.dart';
import 'secretary_bookings_dashboard_screen.dart';
import 'secretary_clinic_settings_screen.dart';
import 'secretary_schedule_screen.dart';

/// Secretary home: calendar, bookings, clinic (Firestore role: `Secretary`).
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
      fontSize: 9.5,
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SizedBox(
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
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
                      decoration: BoxDecoration(
                        color: kStaffNavDockBackground,
                        border: Border(
                          top: BorderSide(
                            color: kStaffAccentSlateBlue.withValues(alpha: 0.2),
                            width: kStaffCardOutlineWidth,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(2, 16, 2, 5),
                        child: Builder(
                          builder: (context) {
                            final isRtl =
                                Directionality.of(context) == TextDirection.rtl;
                            final cal = item(
                              index: 0,
                              icon: Icons.calendar_month_rounded,
                              label: s.translate('secretary_nav_calendar'),
                            );
                            final book = item(
                              index: 1,
                              icon: Icons.list_alt_rounded,
                              label: s.translate('secretary_nav_bookings'),
                            );
                            final clinic = item(
                              index: 3,
                              icon: Icons.apartment_rounded,
                              label: s.translate('secretary_nav_clinic'),
                            );
                            const hole = SizedBox(width: 64);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: isRtl
                                  ? <Widget>[clinic, hole, book, cal]
                                  : <Widget>[cal, book, hole, clinic],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                child: Tooltip(
                  message: s.translate('secretary_nav_schedule'),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _onNavTap(2),
                      child: Ink(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: kStaffGoldActionGradient,
                          border: Border.all(
                            color: _index == 2
                                ? kStaffLuxGoldLight
                                : kStaffSilverBorder,
                            width: _index == 2 ? 2.2 : 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kStaffLuxGold.withValues(
                                alpha: _index == 2 ? 0.48 : 0.28,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const SizedBox(
                          width: 54,
                          height: 54,
                          child: Icon(
                            Icons.event_available_rounded,
                            color: kStaffOnGoldText,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
        backgroundColor: kDoctorPremiumGradientBottom,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DoctorPremiumBackground(),
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _index,
                children: const [
                  MasterCalendarScreen(
                    showDoctorPicker: true,
                    canManage: true,
                    isRootShell: true,
                  ),
                  SecretaryBookingsDashboardScreen(),
                  SecretaryScheduleScreen(),
                  SecretaryClinicSettingsScreen(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildCompactBottomNav(context),
      ),
    );
  }
}
