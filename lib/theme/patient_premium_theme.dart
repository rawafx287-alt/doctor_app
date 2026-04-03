import 'package:flutter/material.dart';

import 'app_fonts.dart';

export 'app_fonts.dart' show kAppFontFamily;

/// Light sky blue shell used across patient Home, Profile, Booking, Details.
const Color kPatientSkyTop = Color(0xFFE1F5FE);
const Color kPatientSkyBottom = Color(0xFFB3E5FC);

/// Same as [kAppFontFamily] — NRT; prefer bold ([FontWeight.w700]) for Kurdish UI copy.
const String kPatientPrimaryFont = kAppFontFamily;

const Color kPatientNavyText = Color(0xFF0D2137);
const Color kPatientDeepBlue = Color(0xFF1A237E);

/// Professional appointment status pills — use across patient, doctor, secretary, previews.
const Color kAppointmentStatusCompletedBg = Color(0xFF2E7D32);
const Color kAppointmentStatusCompletedFg = Color(0xFFFFFFFF);

const Color kAppointmentStatusPendingBg = Color(0xFFEF6C00);
const Color kAppointmentStatusPendingFg = Color(0xFFFFFFFF);

/// Background + foreground for a rounded status pill.
(Color, Color) appointmentStatusBadgeColors(String rawStatus) {
  final s = rawStatus.trim().toLowerCase();
  switch (s) {
    case 'completed':
      return (kAppointmentStatusCompletedBg, kAppointmentStatusCompletedFg);
    case 'cancelled':
    case 'canceled':
      return (const Color(0xFFC62828), kAppointmentStatusPendingFg);
    case 'confirmed':
      return (const Color(0xFF283593), kAppointmentStatusPendingFg);
    case 'arrived':
      return (const Color(0xFF6D4C41), kAppointmentStatusPendingFg);
    case 'pending':
    default:
      return (kAppointmentStatusPendingBg, kAppointmentStatusPendingFg);
  }
}

/// Full-screen vertical gradient (Home, Profile, Booking, Details bodies).
BoxDecoration patientSkyGradientDecoration() => const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kPatientSkyTop, kPatientSkyBottom],
      ),
    );

/// Frosted glass panel: semi-transparent gradient + **0.5px white** border (no [BackdropFilter]).
Decoration patientFrostedGlassDecoration({
  double borderRadius = 16,
  double borderWidth = 0.5,
  List<Color>? gradientColors,
  /// When set (e.g. profile silver rim), replaces the default white glass border.
  Color? outlineColor,
  double outlineWidth = 1.5,
}) {
  final border = outlineColor != null
      ? Border.all(color: outlineColor, width: outlineWidth)
      : Border.all(
          color: Colors.white.withValues(alpha: 0.88),
          width: borderWidth,
        );
  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientColors ??
          [
            Colors.white.withValues(alpha: 0.52),
            Colors.white.withValues(alpha: 0.30),
            const Color(0xFFE3F2FD).withValues(alpha: 0.35),
          ],
    ),
    border: border,
    boxShadow: [
      BoxShadow(
        color: kPatientDeepBlue.withValues(alpha: 0.07),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

TextStyle patientBoldTextStyle({
  double fontSize = 15,
  FontWeight weight = FontWeight.w700,
  Color color = kPatientNavyText,
  double? height,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: kPatientPrimaryFont,
    fontWeight: weight,
    fontSize: fontSize,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Barely visible light-grey grid + diagonals (opacity 0.02) for main backgrounds.
class PatientSubtleGeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF757575).withValues(alpha: 0.02)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const step = 36.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final diag = Paint()
      ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.02)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (var i = -size.height; i < size.width + size.height; i += 52.0) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), diag);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
