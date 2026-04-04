import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
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
    this.receiptImageUrl,
    this.paymentMethodRaw = '',
    this.paymentStatusRaw = '',
    this.onVerifyPayment,
  });

  final String patientName;
  final String queueEn;
  final String phoneDisplay;
  final String statusRaw;
  final bool busy;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancelled;
  final int animationIndex;

  /// HTTPS URL from [AppointmentFields.receiptImageUrl] / legacy [receiptUrl].
  final String? receiptImageUrl;

  /// Raw [AppointmentFields.paymentMethod] (`Cash`, `FIB`, `FastPay`, `FIB_FastPay`, …).
  final String paymentMethodRaw;

  /// Raw [AppointmentFields.paymentStatus].
  final String paymentStatusRaw;

  /// When [paymentStatusRaw] is `pending_verification`, secretary can confirm payment.
  final Future<void> Function()? onVerifyPayment;

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

  bool get _hasReceiptUrl {
    final u = widget.receiptImageUrl?.trim() ?? '';
    return u.isNotEmpty;
  }

  bool get _hasPaymentMethodField =>
      widget.paymentMethodRaw.trim().isNotEmpty;

  /// FIB / FastPay / legacy digital — blue eye opens receipt bottom sheet.
  bool get _isDigitalPaymentMethod {
    final p = widget.paymentMethodRaw.toLowerCase().trim();
    if (p.isEmpty || p == 'cash') return false;
    return p == 'fib' ||
        p == 'fastpay' ||
        p.contains('fib') ||
        p.contains('fastpay') ||
        p == 'digital';
  }

  String _paymentMethodValueForLabel() {
    final t = widget.paymentMethodRaw.trim();
    return t.isEmpty ? '—' : t;
  }

  bool get _canVerifyPayment {
    final ps = widget.paymentStatusRaw.toLowerCase().trim();
    return ps == 'pending_verification' && widget.onVerifyPayment != null;
  }

  static const Color _kReceiptEyeBlue = Color(0xFF1E88E5);

  Future<void> _openReceiptViewer(BuildContext context) async {
    final s = S.of(context);
    final url = widget.receiptImageUrl?.trim() ?? '';
    if (url.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('secretary_receipt_need_image'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final h = MediaQuery.sizeOf(sheetCtx).height * 0.9;
        return Directionality(
          textDirection: AppLocaleScope.of(sheetCtx).textDirection,
          child: Container(
            height: h,
            margin: const EdgeInsets.only(top: 8),
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Color(0xFF0A1628),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.translate('secretary_receipt_view_tooltip'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (c, _) => const Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: kStaffLuxGold),
                          ),
                          errorWidget: (c, _, err) => Icon(
                            Icons.broken_image_outlined,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_canVerifyPayment)
                  SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.busy
                            ? null
                            : () async {
                                await widget.onVerifyPayment!.call();
                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: kStaffLuxGold,
                          foregroundColor: const Color(0xFF102A43),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          s.translate('secretary_verify_payment'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
                    if (_hasPaymentMethodField) ...[
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            _isDigitalPaymentMethod
                                ? Icons.account_balance_wallet_rounded
                                : Icons.payments_rounded,
                            size: 14,
                            color: kStaffLuxGold.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              s.translate(
                                'secretary_payment_route_label',
                                params: {
                                  'method': _paymentMethodValueForLabel(),
                                },
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                height: 1.2,
                                color: Color(0xFFB8C9D9),
                              ),
                            ),
                          ),
                          if (_isDigitalPaymentMethod)
                            Tooltip(
                              message:
                                  s.translate('secretary_receipt_view_tooltip'),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.busy
                                      ? null
                                      : () => _openReceiptViewer(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Icon(
                                      Icons.visibility_rounded,
                                      size: 22,
                                      color: _hasReceiptUrl
                                          ? _kReceiptEyeBlue
                                          : _kReceiptEyeBlue
                                              .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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
                      onPressed:
                          widget.busy ? null : widget.onCompleted,
                    ),
                    const SizedBox(height: 6),
                    _DoneRejectCircle(
                      fill: const Color(0xFFDC2626),
                      icon: Icons.close_rounded,
                      tooltip: s.translate('secretary_action_cancel'),
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
  });

  final Color fill;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

typedef AppointmentCard = SecretaryAppointmentCard;
