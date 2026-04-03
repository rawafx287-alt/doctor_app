import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import '../widgets/hr_nora_centered_wordmark.dart';
import '../auth/app_logout.dart';
import '../auth/doctor_session_cache.dart';
import '../auth/firestore_user_doc_id.dart';
import 'appointments_screen.dart';
import 'doctor_profile_screen.dart';
import 'patient_list_screen.dart';
import 'available_days_schedule_screen.dart';
import '../calendar/master_calendar_screen.dart';

/// Doctor shell: appointments, schedule (center gold FAB), profile — glass dock like patient.
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
    final fallback = firestoreUserDocId(FirebaseAuth.instance.currentUser).trim();
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
        return s.translate('schedule_screen_title');
      case 2:
        return s.translate('doctor_nav_profile');
      default:
        return '';
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final s = S.of(context);
    if (_bottomNavIndex == 2) {
      return AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kStaffPrimaryNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const HrNoraCenteredWordmark(fontSize: 19),
      );
    }
    return AppBar(
      backgroundColor: kStaffPrimaryNavy,
      foregroundColor: const Color(0xFFD9E2EC),
      elevation: 0,
      title: Text(
        _appBarTitle(context),
        style: staffAppBarTitleStyle().copyWith(
          color: const Color(0xFFD9E2EC),
        ),
      ),
      actions: [
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

    Widget scheduleCenterItem() {
      final selected = _bottomNavIndex == 1;
      const circle = 36.0;
      const iconSize = 18.0;

      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onBottomNavTap(1),
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    width: circle,
                    height: circle,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFD700),
                          Color(0xFFB8860B),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    s.translate('doctor_nav_schedule'),
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
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                child: Builder(
                  builder: (context) {
                    final isRtl =
                        Directionality.of(context) == TextDirection.rtl;
                    // LTR: profile (left) | schedule | appointments (right).
                    // RTL: reverse widget order so the same physical layout holds.
                    final sideWidgets = isRtl
                        ? <Widget>[
                            navItem(
                              index: 0,
                              icon: Icons.calendar_month_rounded,
                              label: s.translate('doctor_nav_appointments'),
                            ),
                            scheduleCenterItem(),
                            navItem(
                              index: 2,
                              icon: Icons.person_rounded,
                              label: s.translate('doctor_nav_profile'),
                            ),
                          ]
                        : <Widget>[
                            navItem(
                              index: 2,
                              icon: Icons.person_rounded,
                              label: s.translate('doctor_nav_profile'),
                            ),
                            scheduleCenterItem(),
                            navItem(
                              index: 0,
                              icon: Icons.calendar_month_rounded,
                              label: s.translate('doctor_nav_appointments'),
                            ),
                          ];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: sideWidgets,
                    );
                  },
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
        appBar: _buildAppBar(context),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _bottomNavIndex,
            children: [
              AppointmentsScreen(
                embedded: true,
                doctorUserId: _doctorUserId,
              ),
              AvailableDaysScheduleScreen(
                embedded: true,
                managedDoctorUserId: _doctorUserId,
              ),
              DoctorProfileScreen(doctorUserId: _doctorUserId),
            ],
          ),
        ),
        bottomNavigationBar: _buildGlassBottomNav(context),
      ),
    );
  }
}
