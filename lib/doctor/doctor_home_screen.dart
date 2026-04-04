import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import '../auth/app_logout.dart';
import '../auth/doctor_session_cache.dart';
import '../auth/firestore_user_doc_id.dart';
import 'appointments_screen.dart';
import 'doctor_profile_screen.dart';
import 'patient_list_screen.dart';
import '../calendar/master_calendar_screen.dart';
import '../schedule/schedule_management_screen.dart';
import 'doctor_premium_shell.dart';

/// Doctor shell: appointments + schedule (center gold) + profile.
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  /// 0 = appointments, 1 = schedule, 2 = profile
  int _bottomNavIndex = 0;
  String? _doctorUserId;

  /// Premium gold for active nav icon + label (staff spec).
  static const Color _navActiveGold = Color(0xFFD4A373);
  static const Color _navInactiveGrey = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    final fallback = firestoreUserDocId(
      FirebaseAuth.instance.currentUser,
    ).trim();
    if (fallback.isNotEmpty) {
      _doctorUserId = fallback;
    }
    _loadDoctorUserIdFromCache();
  }

  Future<void> _loadDoctorUserIdFromCache() async {
    final cached = await DoctorSessionCache.readDoctorRefId();
    if (!mounted) return;
    final id = (cached ?? '').trim();
    if (id.isEmpty) return;
    setState(() => _doctorUserId = id);
  }

  Future<void> _logout() async {
    await performAppLogout(context);
  }

  void _onBottomNavTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _bottomNavIndex = index);
  }

  String _appBarTitle(BuildContext context) {
    final s = S.of(context);
    switch (_bottomNavIndex) {
      case 0:
        return s.translate('doctor_nav_appointments');
      case 1:
        return s.translate('doctor_nav_schedule');
      case 2:
        return s.translate('doctor_nav_profile');
      default:
        return '';
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final s = S.of(context);
    return doctorPremiumAppBar(
      automaticallyImplyLeading: false,
      title: Text(
        _appBarTitle(context),
        style: const TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: 17,
        ),
      ),
      actions: [
        if (_bottomNavIndex != 1)
          IconButton(
            tooltip: s.translate('master_calendar_tooltip'),
            onPressed: () {
              final uid = (_doctorUserId ?? '').trim();
              if (uid.isEmpty) return;
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => MasterCalendarScreen(
                    doctorId: uid,
                    canManage: true,
                    useStaffShellTheme: true,
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
    );
  }

  Widget _buildGlassBottomNav(BuildContext context) {
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

    Widget navItem({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final selected = _bottomNavIndex == index;
      final color = selected ? _navActiveGold : _navInactiveGrey;

      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onBottomNavTap(index),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 4),
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
          height: 72,
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
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                          top: 18,
                          bottom: 6,
                        ),
                        child: Builder(
                          builder: (context) {
                            final isRtl =
                                Directionality.of(context) == TextDirection.rtl;
                            final appt = navItem(
                              index: 0,
                              icon: Icons.calendar_month_rounded,
                              label: s.translate('doctor_nav_appointments'),
                            );
                            final profile = navItem(
                              index: 2,
                              icon: Icons.person_rounded,
                              label: s.translate('doctor_nav_profile'),
                            );
                            const hole = SizedBox(width: 76);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: isRtl
                                  ? <Widget>[profile, hole, appt]
                                  : <Widget>[appt, hole, profile],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 34,
                child: Tooltip(
                  message: s.translate('doctor_nav_schedule'),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _onBottomNavTap(1),
                      child: Ink(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: kStaffGoldActionGradient,
                          border: Border.all(
                            color: _bottomNavIndex == 1
                                ? kStaffLuxGoldLight
                                : kStaffSilverBorder,
                            width: _bottomNavIndex == 1 ? 2.4 : 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kStaffLuxGold.withValues(
                                alpha: _bottomNavIndex == 1 ? 0.5 : 0.3,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(
                            Icons.event_available_rounded,
                            color: kStaffOnGoldText,
                            size: 26,
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
        extendBodyBehindAppBar: true,
        backgroundColor: kDoctorPremiumGradientBottom,
        appBar: _buildAppBar(context),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DoctorPremiumBackground(),
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _bottomNavIndex,
                children: [
                  AppointmentsScreen(
                    embedded: true,
                    doctorUserId: _doctorUserId,
                  ),
                  ScheduleManagementScreen(
                    embedded: true,
                    managedDoctorUserId: _doctorUserId,
                  ),
                  DoctorProfileScreen(doctorUserId: _doctorUserId),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildGlassBottomNav(context),
      ),
    );
  }
}
