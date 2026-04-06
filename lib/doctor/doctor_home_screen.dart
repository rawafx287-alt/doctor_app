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
<<<<<<< HEAD
<<<<<<< HEAD
        drawer: Drawer(
          backgroundColor: const Color(0xFF1D1E33),
          child: SafeArea(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFF2CB1BC),
                  ),
                  title: Text(
                    'پانێڵی پزیشک',
                    style: TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'چوونەدەرەوە',
                    style: TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _logout(context);
                  },
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: user == null
                      ? null
                      : FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final doctorName = (data?['fullName'] ?? 'پزیشک')
                        .toString();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'بەخێربێیتەوە،',
                            style: TextStyle(
                              color: Color(0xFF829AB1),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'KurdishFont',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctorName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD9E2EC),
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              fontFamily: 'KurdishFont',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth < 380 ? 1 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: crossAxisCount == 1 ? 0.92 : 0.88,
                      children: [
                        _DashboardCard(
                          title: 'نۆرەکانی من',
                          subtitle: 'بینین و ڕێکخستن',
                          icon: Icons.calendar_month_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AppointmentsScreen(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          title: 'لیستی نەخۆشەکان',
                          subtitle: 'گەڕان بەناو نەخۆشەکاندا',
                          icon: Icons.groups_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PatientListScreen(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          title: 'خشتەی کاتەکان',
                          subtitle: 'دیاریکردنی کاتی دەوام',
                          icon: Icons.schedule_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ScheduleScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
=======
        bottomNavigationBar: _buildDoctorBottomNav(context),
>>>>>>> main
      ),
    );
  }
}

<<<<<<< HEAD
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  static const Color _surface = Color(0xFF1D1E33);
  static const Color _accent = Color(0xFF2CB1BC);

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
=======
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

>>>>>>> main
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
<<<<<<< HEAD
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
=======
        body: SafeArea(
          child: IndexedStack(
            index: _bottomNavIndex,
            children: [
              const AppointmentsScreen(embedded: true),
              const AvailableDaysScheduleScreen(embedded: true),
              const DoctorProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: const Color(0xFF829AB1).withValues(alpha: 0.35),
                width: 0.5,
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.2),
                ),
                child: Icon(icon, color: _accent, size: 56),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD9E2EC),
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  fontFamily: 'KurdishFont',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  fontFamily: 'KurdishFont',
                ),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _bottomNavIndex,
            onTap: (index) {
              setState(() => _bottomNavIndex = index);
            },
            backgroundColor: const Color(0xFF1A237E),
            selectedItemColor: const Color(0xFF42A5F5),
            unselectedItemColor: const Color(0xFF829AB1),
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle:
                const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month),
                label: s.translate('doctor_nav_appointments'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.schedule_rounded),
                label: s.translate('doctor_nav_schedule'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: s.translate('doctor_nav_profile'),
=======
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
>>>>>>> main
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
