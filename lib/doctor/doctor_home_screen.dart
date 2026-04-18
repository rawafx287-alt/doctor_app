import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import '../auth/doctor_session_cache.dart';
import '../auth/firestore_user_doc_id.dart';
import 'appointments_screen.dart';
import 'doctor_patient_archive_screen.dart';
import 'doctor_profile_screen.dart';
import '../schedule/schedule_management_screen.dart';
import 'doctor_premium_shell.dart';

/// Doctor shell: profile / history / schedule / appointments.
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  /// 0 = appointments, 1 = schedule, 2 = history/archive, 3 = profile
  int _bottomNavIndex = 0;
  String? _doctorUserId;

  /// Reserve space so list content stays above the floating glass nav.
  static const double _kFloatingNavOuterHeight = 102;

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
    return doctorPremiumAppBar(
      automaticallyImplyLeading: false,
      title: Text(
        _appBarTitle(context),
        style: TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontSize: 19,
          height: 1.15,
          letterSpacing: -0.35,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
            Shadow(
              color: kStaffLuxGold.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
    );
  }

  /// LTR: profile → history → schedule → appointments. RTL: reversed.
  List<({int navIndex, IconData icon, String label})> _navSlots(
    BuildContext context,
    bool isRtl,
  ) {
    final s = S.of(context);
    if (isRtl) {
      return [
        (
          navIndex: 0,
          icon: Icons.calendar_view_month_rounded,
          label: s.translate('doctor_nav_appointments'),
        ),
        (
          navIndex: 1,
          icon: Icons.event_note_rounded,
          label: s.translate('doctor_nav_schedule'),
        ),
        (
          navIndex: 2,
          icon: Icons.manage_history_rounded,
          label: s.translate('doctor_nav_history'),
        ),
        (
          navIndex: 3,
          icon: Icons.person_rounded,
          label: s.translate('doctor_nav_profile'),
        ),
      ];
    }
    return [
      (
        navIndex: 3,
        icon: Icons.person_rounded,
        label: s.translate('doctor_nav_profile'),
      ),
      (
        navIndex: 2,
        icon: Icons.manage_history_rounded,
        label: s.translate('doctor_nav_history'),
      ),
      (
        navIndex: 1,
        icon: Icons.event_note_rounded,
        label: s.translate('doctor_nav_schedule'),
      ),
      (
        navIndex: 0,
        icon: Icons.calendar_view_month_rounded,
        label: s.translate('doctor_nav_appointments'),
      ),
    ];
  }

  Widget _buildDoctorBottomNav(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final slots = _navSlots(context, isRtl);
    const barRadius = 25.0;
    const hPad = 20.0;
    const vPad = 12.0;

    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, vPad),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barRadius + 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: kStaffLuxGold.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(barRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(barRadius),
                    color: const Color(0xFF1A1F3D).withValues(alpha: 0.9),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: SizedBox(
                    height: 78,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final slot in slots)
                          Expanded(
                            child: _DoctorBottomNavItem(
                              icon: slot.icon,
                              label: slot.label,
                              selected: _bottomNavIndex == slot.navIndex,
                              onTap: () => _onBottomNavTap(slot.navIndex),
                            ),
                          ),
                      ],
                    ),
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
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom +
                      _kFloatingNavOuterHeight,
                ),
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
            ),
          ],
        ),
        bottomNavigationBar: _buildDoctorBottomNav(context),
      ),
    );
  }
}

class _DoctorBottomNavItem extends StatelessWidget {
  const _DoctorBottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _inactiveIcon = Color(0xFF94A3B8);
  static const Color _inactiveLabel = Color(0xFFCBD5E1);
  static const Duration _kNavAnim = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final gold = kStaffLuxGold;
    final iconColor = selected ? gold : _inactiveIcon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: gold.withValues(alpha: 0.14),
        highlightColor: gold.withValues(alpha: 0.07),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 5,
                child: Center(
                  child: AnimatedContainer(
                    duration: _kNavAnim,
                    curve: Curves.easeInOut,
                    width: selected ? 20 : 0,
                    height: selected ? 3 : 0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: gold,
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.65),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedScale(
                duration: _kNavAnim,
                curve: Curves.easeInOut,
                scale: selected ? 1.12 : 1.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: gold.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: gold.withValues(alpha: 0.2),
                              blurRadius: 28,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      icon,
                      size: 24,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: _kNavAnim,
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? gold : _inactiveLabel,
                  letterSpacing: selected ? -0.05 : -0.1,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
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
