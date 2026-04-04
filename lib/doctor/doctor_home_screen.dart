import 'dart:ui' show ImageFilter;

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
    const barHeight = 64.0;
    const labelStyle = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );

    TextStyle labelFor(bool selected) => labelStyle.copyWith(
      color: selected ? kStaffLuxGold : _navInactiveMuted,
      shadows: selected
          ? <Shadow>[
              Shadow(
                color: kStaffLuxGold.withValues(alpha: 0.75),
                blurRadius: 8,
              ),
            ]
          : null,
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onBottomNavTap(index),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: gold.withValues(alpha: 0.55),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: iconCore,
                    )
                  else
                    iconCore,
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? gold : Colors.transparent,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.65),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: SizedBox(
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Builder(
                            builder: (context) {
                              final isRtl =
                                  Directionality.of(context) ==
                                  TextDirection.rtl;
                              // RTL: start = right → appointments first; LTR: profile first = left.
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
                                    ? <Widget>[appt, hole, profile]
                                    : <Widget>[profile, hole, appt],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 36,
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
                                alpha: _bottomNavIndex == 1 ? 0.55 : 0.32,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
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
