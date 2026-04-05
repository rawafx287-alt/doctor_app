import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/app_logout.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import '../doctor/doctor_premium_shell.dart';
import '../calendar/master_calendar_screen.dart';
import 'add_doctor_screen.dart';
import 'admin_ads_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_hospital_management_screen.dart';
import 'approval_list_screen.dart';
import 'doctor_management_screen.dart';

/// Secondary / hint text — light silver with gold tint.
const Color _kAdminSubtitleMuted = Color(0xFFC9C4B0);

/// Subtle medical cross / plus grid at ~5% opacity.
class _MedicalVeilPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.05);
    const step = 52.0;
    const arm = 7.0;
    const thick = 2.2;
    for (var y = -step; y < size.height + step; y += step) {
      final row = ((y + step) / step).round();
      for (var x = -step; x < size.width + step; x += step) {
        final shift = row.isOdd ? step * 0.5 : 0.0;
        final c = Offset(x + shift + step * 0.5, y + step * 0.5);
        final h = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: arm * 2, height: thick),
          const Radius.circular(1.5),
        );
        final v = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: thick, height: arm * 2),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(h, p);
        canvas.drawRRect(v, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdminAction {
  const _AdminAction({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
  });

  final String titleKey;
  final String subtitleKey;
  final IconData icon;
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  List<_AdminAction> _actions() {
    return const [
      _AdminAction(
        titleKey: 'master_calendar_tooltip',
        subtitleKey: 'master_calendar_subtitle',
        icon: Icons.calendar_month_rounded,
      ),
      _AdminAction(
        titleKey: 'admin_card_feedback_title',
        subtitleKey: 'admin_card_feedback_subtitle',
        icon: Icons.feedback_outlined,
      ),
      _AdminAction(
        titleKey: 'admin_card_hospitals_title',
        subtitleKey: 'admin_card_hospitals_subtitle',
        icon: Icons.local_hospital_rounded,
      ),
      _AdminAction(
        titleKey: 'admin_card_approvals_title',
        subtitleKey: 'admin_card_approvals_subtitle',
        icon: Icons.inbox_rounded,
      ),
      _AdminAction(
        titleKey: 'admin_card_doctors_title',
        subtitleKey: 'admin_card_doctors_subtitle',
        icon: Icons.groups_rounded,
      ),
      _AdminAction(
        titleKey: 'admin_card_add_doctor_title',
        subtitleKey: 'admin_card_add_doctor_subtitle',
        icon: Icons.person_add_alt_1_rounded,
      ),
      _AdminAction(
        titleKey: 'admin_card_ads_title',
        subtitleKey: 'admin_card_ads_subtitle',
        icon: Icons.campaign_rounded,
      ),
    ];
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const MasterCalendarScreen(
              showDoctorPicker: true,
              canManage: true,
            ),
          ),
        );
        break;
      case 1:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const AdminFeedbackScreen(),
          ),
        );
        break;
      case 2:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const AdminHospitalManagementScreen(),
          ),
        );
        break;
      case 3:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const ApprovalListScreen(),
          ),
        );
        break;
      case 4:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const DoctorManagementScreen(),
          ),
        );
        break;
      case 5:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const AddDoctorScreen(),
          ),
        );
        break;
      case 6:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => const AdminAdsScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dir = AppLocaleScope.of(context).textDirection;
    final actions = _actions();
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final nf = NumberFormat.decimalPattern('en_US');
    final weekday = DateFormat('EEEE', 'en_US').format(now);
    final dateLine =
        '$weekday — \u200E${nf.format(now.year)} / ${nf.format(now.month)} / ${nf.format(now.day)}';

    return Directionality(
      textDirection: dir,
      child: Scaffold(
        backgroundColor: kDoctorPremiumGradientBottom,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.health_and_safety_rounded,
                color: kStaffLuxGold,
                size: 30,
                shadows: [
                  Shadow(
                    color: kStaffLuxGold.withValues(alpha: 0.45),
                    blurRadius: 12,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  s.translate('admin_dashboard_page_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kStaffLuxGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    fontFamily: kPatientPrimaryFont,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: kDoctorPremiumGradientDecoration,
            ),
            Positioned.fill(child: CustomPaint(painter: _MedicalVeilPainter())),
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: _WelcomeAdminHeader(
                        welcomeTitle: s.translate('admin_dashboard_welcome'),
                        welcomeHint: s.translate(
                          'admin_dashboard_welcome_hint',
                        ),
                        dateLine: dateLine,
                        user: user,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          const gap = 12.0;
                          final half = (w - gap) / 2;
                          final left = <Widget>[];
                          final right = <Widget>[];
                          for (var i = 0; i < actions.length; i++) {
                            final card = SizedBox(
                              width: half,
                              child: _GlassDashboardCard(
                                title: s.translate(actions[i].titleKey),
                                subtitle: s.translate(actions[i].subtitleKey),
                                icon: actions[i].icon,
                                onTap: () {
                                  _navigate(context, i);
                                },
                              ),
                            );
                            if (i.isEven) {
                              left.add(card);
                              if (i < actions.length - 2) {
                                left.add(const SizedBox(height: gap));
                              }
                            } else {
                              right.add(card);
                              if (i < actions.length - 2) {
                                right.add(const SizedBox(height: gap));
                              }
                            }
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(children: left)),
                              SizedBox(width: gap),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 22),
                                  child: Column(children: right),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: StaffGoldGradientButton(
                            label: s.translate('admin_logout'),
                            onPressed: () async => performAppLogout(context),
                            fontSize: 16,
                            borderRadius: 16,
                            minHeight: 52,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final url = user?.photoURL?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    return CircleAvatar(
      backgroundColor: kDoctorPremiumGradientMid,
      foregroundImage: hasPhoto ? NetworkImage(url) : null,
      child: hasPhoto
          ? null
          : const Icon(
              Icons.admin_panel_settings_rounded,
              size: 34,
              color: kStaffLuxGold,
            ),
    );
  }
}

class _WelcomeAdminHeader extends StatelessWidget {
  const _WelcomeAdminHeader({
    required this.welcomeTitle,
    required this.welcomeHint,
    required this.dateLine,
    required this.user,
  });

  final String welcomeTitle;
  final String welcomeHint;
  final String dateLine;
  final User? user;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: kStaffGoldActionGradient,
            boxShadow: [
              BoxShadow(
                color: kStaffLuxGold.withValues(alpha: 0.4),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: kDoctorPremiumGradientTop,
            ),
            child: _AdminAvatar(user: user),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                welcomeTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1.15,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                welcomeHint,
                style: TextStyle(
                  color: _kAdminSubtitleMuted.withValues(alpha: 0.95),
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Text(
                  dateLine,
                  style: TextStyle(
                    color: kStaffLuxGold.withValues(alpha: 0.72),
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassDashboardCard extends StatefulWidget {
  const _GlassDashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlassDashboardCard> createState() => _GlassDashboardCardState();
}

class _GlassDashboardCardState extends State<_GlassDashboardCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: kStaffLuxGold.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: -1,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: kStaffLuxGoldLight.withValues(alpha: 0.22),
                    blurRadius: 26,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                splashColor: kStaffLuxGold.withValues(alpha: 0.18),
                highlightColor: kStaffLuxGold.withValues(alpha: 0.06),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: _pressed ? 0.22 : 0.14),
                    border: Border.all(
                      color: kStaffSilverBorder,
                      width: kStaffCardOutlineWidth,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 4,
                          color: kStaffAccentSlateBlue,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 14, 8, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.icon,
                                  color: kStaffLuxGold,
                                  size: 28,
                                  shadows: [
                                    Shadow(
                                      color: kStaffLuxGold.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        widget.subtitle,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _kAdminSubtitleMuted
                                              .withValues(alpha: 0.92),
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11.5,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: kStaffLuxGold.withValues(alpha: 0.75),
                                  size: 24,
                                ),
                              ],
                            ),
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
}
