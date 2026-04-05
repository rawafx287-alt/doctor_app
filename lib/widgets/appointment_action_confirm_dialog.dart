import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';

/// Vibrant green (top of confirm gradient).
const Color kAppointmentConfirmCompleteGreen = Color(0xFF00C853);

/// Deeper green (bottom of confirm gradient).
const Color kAppointmentConfirmCompleteGreenDeep = Color(0xFF008A3E);

/// Bright red (top of reject gradient).
const Color kAppointmentConfirmRejectRed = Color(0xFFE53935);

/// Deep red (bottom of reject gradient).
const Color kAppointmentConfirmRejectRedDeep = Color(0xFF8B1010);

const double _kDialogRadius = 24;
const double _kGoldBorderWidth = 0.8;

/// Glass confirmation for marking an appointment completed or cancelled/rejected.
/// Returns `true` only when the user taps the colored confirm control.
Future<bool> showAppointmentActionConfirmDialog(
  BuildContext context, {
  required bool isCompleteAction,
  String? titleKey,
}) async {
  final barrierLabel =
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(
          child: Directionality(
            textDirection: AppLocaleScope.of(ctx).textDirection,
            child: _AppointmentActionConfirmPanel(
              isCompleteAction: isCompleteAction,
              titleKey: titleKey,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result == true;
}

class _AppointmentActionConfirmPanel extends StatelessWidget {
  const _AppointmentActionConfirmPanel({
    required this.isCompleteAction,
    this.titleKey,
  });

  final bool isCompleteAction;
  final String? titleKey;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final gold = kStaffLuxGold.withValues(alpha: 0.92);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_kDialogRadius),
      side: BorderSide(
        color: kStaffLuxGold.withValues(alpha: 0.65),
        width: _kGoldBorderWidth,
      ),
    );

    final confirmGradient = isCompleteAction
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kAppointmentConfirmCompleteGreen,
              kAppointmentConfirmCompleteGreenDeep,
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kAppointmentConfirmRejectRed,
              kAppointmentConfirmRejectRedDeep,
            ],
          );

    final shadowColor = (isCompleteAction
            ? kAppointmentConfirmCompleteGreen
            : kAppointmentConfirmRejectRed)
        .withValues(alpha: 0.42);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kDialogRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kStaffShellGradientTop.withValues(alpha: 0.96),
                    kStaffShellGradientMid.withValues(alpha: 0.94),
                    const Color(0xFF0A1628).withValues(alpha: 0.97),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 52,
                      color: gold,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.translate(titleKey ?? 'appt_action_confirm_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        height: 1.35,
                        letterSpacing: -0.2,
                        color: Color(0xFFF2F6FA),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _GradientConfirmButton(
                      gradient: confirmGradient,
                      shadowColor: shadowColor,
                      label: s.translate('appt_action_confirm_yes'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.88),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 0.9,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          s.translate('appt_action_confirm_no'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
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
    );
  }
}

class _GradientConfirmButton extends StatelessWidget {
  const _GradientConfirmButton({
    required this.gradient,
    required this.shadowColor,
    required this.label,
    required this.onPressed,
  });

  final LinearGradient gradient;
  final Color shadowColor;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withValues(alpha: 0.18),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.white,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
