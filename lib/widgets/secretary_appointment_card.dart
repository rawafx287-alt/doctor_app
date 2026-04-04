import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';

/// Secretary queue card: ticket # (gold circle), patient name (bold gold), phone + icon, Done/Reject.
class SecretaryAppointmentCard extends StatefulWidget {
  const SecretaryAppointmentCard({
    super.key,
    required this.patientName,
    required this.queueEn,
    required this.phoneDisplay,
    required this.statusRaw,
    required this.busy,
    required this.onCompleted,
    required this.onCancelled,
    this.animationIndex = 0,
  });

  final String patientName;
  final String queueEn;
  final String phoneDisplay;
  final String statusRaw;
  final bool busy;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancelled;
  final int animationIndex;

  @override
  State<SecretaryAppointmentCard> createState() =>
      _SecretaryAppointmentCardState();
}

class _SecretaryAppointmentCardState extends State<SecretaryAppointmentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entrance;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  static const double _radius = 14;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    ));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOut,
    ));
    final delayMs = 32 + widget.animationIndex * 40;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _launchTel(String raw) async {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).translate('doctor_appt_call_failed'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).translate('doctor_appt_call_failed'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = widget.statusRaw.trim().toLowerCase();
    final showPrimaryActions = st != 'completed' &&
        st != 'cancelled' &&
        st != 'canceled';
    final phoneDigits = widget.phoneDisplay.trim();
    final canDial = phoneDigits.isNotEmpty && phoneDigits != '—';

    final inner = BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1F3A).withValues(alpha: 0.52),
          border: Border.all(
            color: kStaffLuxGold.withValues(alpha: 0.38),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(_radius),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Directionality(
          textDirection: AppLocaleScope.of(context).textDirection,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label:
                    '${s.translate('secretary_ticket_number')} ${widget.queueEn}',
                child: _QueueGoldBadge(number: widget.queueEn),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.patientName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.15,
                        color: kStaffLuxGold.withValues(alpha: 0.98),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_in_talk_rounded,
                          size: 17,
                          color: canDial
                              ? kStaffLuxGold.withValues(alpha: 0.92)
                              : kStaffLuxGold.withValues(alpha: 0.32),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Directionality(
                            textDirection: ui.TextDirection.ltr,
                            child: Text(
                              phoneDigits.isEmpty ? '—' : phoneDigits,
                              style: TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: canDial
                                    ? const Color(0xFFE8F4F0)
                                    : Colors.white.withValues(alpha: 0.42),
                              ),
                            ),
                          ),
                        ),
                        if (canDial)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.busy
                                  ? null
                                  : () => _launchTel(phoneDigits),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.phone_rounded,
                                  size: 18,
                                  color: kStaffLuxGold.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showPrimaryActions) ...[
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DoneRejectCircle(
                      fill: const Color(0xFF16A34A),
                      icon: Icons.check_rounded,
                      tooltip: s.translate('secretary_action_completed'),
                      glow: true,
                      onPressed:
                          widget.busy ? null : widget.onCompleted,
                    ),
                    const SizedBox(height: 6),
                    _DoneRejectCircle(
                      fill: const Color(0xFFDC2626),
                      icon: Icons.close_rounded,
                      tooltip: s.translate('secretary_action_cancel'),
                      glow: false,
                      onPressed:
                          widget.busy ? null : widget.onCancelled,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: kStaffLuxGold.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: inner,
          ),
        ),
      ),
    );
  }
}

class _QueueGoldBadge extends StatelessWidget {
  const _QueueGoldBadge({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: kStaffGoldActionGradient,
        boxShadow: [
          BoxShadow(
            color: kStaffLuxGold.withValues(alpha: 0.32),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.6),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0B1F3A).withValues(alpha: 0.92),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            number,
            maxLines: 1,
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              fontSize: number.length > 2 ? 20 : 24,
              height: 1,
              color: kStaffLuxGold,
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneRejectCircle extends StatelessWidget {
  const _DoneRejectCircle({
    required this.fill,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.glow = false,
  });

  final Color fill;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              boxShadow: [
                if (glow)
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                    blurRadius: 14,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                BoxShadow(
                  color: fill.withValues(alpha: glow ? 0.22 : 0.32),
                  blurRadius: glow ? 9 : 7,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

typedef AppointmentCard = SecretaryAppointmentCard;
