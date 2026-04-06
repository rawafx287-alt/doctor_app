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

  static const Color _navStrip = Color(0xFF0E1628);

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
        style: const TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: 17,
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

    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _navStrip,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 76,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = _doctorUserId;
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        extendBody: false,
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

  static const Color _inactiveIcon = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final gold = kStaffLuxGold;
    final iconColor = selected ? gold : _inactiveIcon;
    final textColor = selected ? gold : const Color(0xFF9CA8B8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: gold.withValues(alpha: 0.12),
        highlightColor: gold.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 8,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: selected ? 5 : 0,
                    height: selected ? 5 : 0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? gold : Colors.transparent,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.55),
                                blurRadius: 8,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
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
