import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import '../auth/app_logout.dart';
import '../auth/doctor_session_cache.dart';
import '../auth/firestore_user_doc_id.dart';
import 'appointments_screen.dart';
import 'doctor_patient_archive_screen.dart';
import 'doctor_profile_screen.dart';
import '../schedule/schedule_management_screen.dart';
import 'doctor_premium_shell.dart';
import '../widgets/pressable_scale.dart';

/// Doctor shell: profile / history / schedule / appointments (gold FAB + label).
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  /// 0 = appointments (gold FAB), 1 = schedule, 2 = history/archive, 3 = profile
  int _bottomNavIndex = 0;
  String? _doctorUserId;

  /// Muted label/icon when tab is inactive (soft white/gray).
  static const Color _navInactiveMuted = Color(0xFFB8C0CC);

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
    if (index == _bottomNavIndex) return;
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
        return s.translate('doctor_nav_history');
      case 3:
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
    const barRadius = 32.0;
    const barHeight = 82.0;
    const labelStyle = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );

    TextStyle labelFor(bool selected) => labelStyle.copyWith(
          color: selected ? kStaffLuxGold : _navInactiveMuted,
        );

    Widget navItem({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final selected = _bottomNavIndex == index;
      final gold = kStaffLuxGold;
      final inactive = _navInactiveMuted;

      final iconCore = Icon(
        icon,
        size: 22,
        color: selected ? gold : inactive,
      );

      return Expanded(
        child: PressableScale(
          onTap: () => _onBottomNavTap(index),
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    child: Center(child: iconCore),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? gold : Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 2),
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

    /// Gold circle FAB + dot + label (نۆرەکان).
    Widget appointmentsPrimaryFab() {
      const index = 0;
      final selected = _bottomNavIndex == index;
      final gold = kStaffLuxGold;
      return Expanded(
        child: PressableScale(
          scale: 0.94,
          onTap: () => _onBottomNavTap(index),
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: kStaffGoldActionGradient,
                      border: Border.all(
                        color: selected ? kStaffLuxGoldLight : kStaffSilverBorder,
                        width: selected ? 2.4 : 1.1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: kStaffLuxGold.withValues(alpha: 0.28),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: kStaffOnGoldText,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? gold : Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.translate('doctor_nav_appointments'),
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
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(barRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: kStaffLuxGold.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(barRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border(
                    top: BorderSide(
                      color: kStaffLuxGold.withValues(alpha: 0.78),
                      width: 1,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(barRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Builder(
                    builder: (context) {
                      final isRtl =
                          Directionality.of(context) == TextDirection.rtl;
                      final appointmentsFab = appointmentsPrimaryFab();
                      final schedule = navItem(
                        index: 1,
                        icon: Icons.calendar_view_month_rounded,
                        label: s.translate('doctor_nav_schedule'),
                      );
                      final history = navItem(
                        index: 2,
                        icon: Icons.manage_history_rounded,
                        label: s.translate('doctor_nav_history'),
                      );
                      final profile = navItem(
                        index: 3,
                        icon: Icons.person_rounded,
                        label: s.translate('doctor_nav_profile'),
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: isRtl
                            ? <Widget>[
                                appointmentsFab,
                                schedule,
                                history,
                                profile,
                              ]
                            : <Widget>[
                                profile,
                                history,
                                schedule,
                                appointmentsFab,
                              ],
                      );
                    },
                  ),
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
    final doctorId = _doctorUserId;
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
                sizing: StackFit.expand,
                children: [
                  _DoctorTabKeepAlive(
                    child: AppointmentsScreen(
                      embedded: true,
                      doctorUserId: doctorId,
                    ),
                  ),
                  _DoctorTabKeepAlive(
                    child: ScheduleManagementScreen(
                      embedded: true,
                      managedDoctorUserId: doctorId,
                    ),
                  ),
                  _DoctorTabKeepAlive(
                    child: DoctorPatientArchiveScreen(
                      embedded: true,
                      doctorUserId: doctorId ?? '',
                    ),
                  ),
                  _DoctorTabKeepAlive(
                    child: DoctorProfileScreen(doctorUserId: doctorId),
                  ),
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

/// Keeps scroll/state inside each doctor shell tab under [IndexedStack].
class _DoctorTabKeepAlive extends StatefulWidget {
  const _DoctorTabKeepAlive({required this.child});

  final Widget child;

  @override
  State<_DoctorTabKeepAlive> createState() => _DoctorTabKeepAliveState();
}

class _DoctorTabKeepAliveState extends State<_DoctorTabKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
