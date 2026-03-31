import 'package:flutter/material.dart';

/// Light sky blue shell used across patient Home, Profile, Booking, Details.
const Color kPatientSkyTop = Color(0xFFE1F5FE);
const Color kPatientSkyBottom = Color(0xFFB3E5FC);

/// Primary UI font (Kurdish + Latin) — set on [TextStyle] via [patientBoldTextStyle].
const String kPatientPrimaryFont = 'KurdishFont';

const Color kPatientNavyText = Color(0xFF0D2137);
const Color kPatientDeepBlue = Color(0xFF1A237E);

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
}) {
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
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.88),
      width: borderWidth,
    ),
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
