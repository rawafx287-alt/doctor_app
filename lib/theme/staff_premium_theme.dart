import 'package:flutter/material.dart';

import 'patient_premium_theme.dart'
    show appointmentStatusBadgeColors, kPatientPrimaryFont;

export 'patient_premium_theme.dart' show kPatientPrimaryFont;

/// Admin / doctor / secretary background gradient (professional deep blue).
const Color kStaffShellGradientTop = Color(0xFF0A192F);
const Color kStaffShellGradientMid = Color(0xFF0E213E);
const Color kStaffShellGradientBottom = Color(0xFF112240);

const BoxDecoration kStaffShellGradientDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      kStaffShellGradientTop,
      kStaffShellGradientMid,
      kStaffShellGradientBottom,
    ],
    stops: [0.0, 0.48, 1.0],
  ),
);

/// Navy slate accent for staff strips and timeline (calendar “open” cells use [HrNoraColors] in those screens).
const Color kStaffAccentSlateBlue = Color(0xFF1E3A8A);

/// Bottom nav dock — cool tint that pairs with gold icons on blue shells.
const Color kStaffNavDockBackground = Color(0xFFEEF2FF);

/// Normalizes Eastern Arabic numerals to ASCII digits for time/date display.
String staffDigitsToEnglishAscii(String input) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in input.split('')) {
    final i = eastern.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

/// Doctor / secretary shell — authoritative navy, patient-aligned gold, light surfaces.
const Color kStaffPrimaryNavy = Color(0xFF1A237E);
const Color kStaffShellBackground = Color(0xFFF2F4F8);
const Color kStaffCardSurface = Color(0xFFFFFFFF);

/// Brand silver rim (dashboard cards), matches patient profile glass outline tone.
const Color kStaffSilverBorder = Color(0xFFC0C0C0);
const double kStaffCardOutlineWidth = 0.8;

/// Same lux gold family as patient home / booking CTAs ([_kBrandLuxGold] family).
const Color kStaffLuxGold = Color(0xFFD4AF37);
const Color kStaffLuxGoldLight = Color(0xFFF6E7A6);
const Color kStaffLuxGoldDark = Color(0xFFB8860B);

const LinearGradient kStaffGoldActionGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    kStaffLuxGoldLight,
    kStaffLuxGold,
    kStaffLuxGoldDark,
  ],
);

/// Status pill: completed = slate blue / white; cancelled = theme red; else gold gradient / dark text.
({BoxDecoration decoration, Color foreground}) staffAppointmentStatusBadgeStyle(
  String rawStatus,
) {
  final s = rawStatus.trim().toLowerCase();
  if (s == 'completed') {
    return (
      decoration: BoxDecoration(
        color: kStaffAccentSlateBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      foreground: Colors.white,
    );
  }
  if (s == 'cancelled' || s == 'canceled') {
    final c = appointmentStatusBadgeColors(rawStatus);
    return (
      decoration: BoxDecoration(
        color: c.$1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.75,
        ),
      ),
      foreground: c.$2,
    );
  }
  return (
    decoration: BoxDecoration(
      gradient: kStaffGoldActionGradient,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: kStaffLuxGold.withValues(alpha: 0.55),
        width: 0.75,
      ),
    ),
    foreground: const Color(0xFF102A43),
  );
}

const Color kStaffBodyText = Color(0xFF263238);
const Color kStaffMutedText = Color(0xFF546E7A);
const Color kStaffOnGoldText = Color(0xFF1A237E);

/// Dashboard / list cards: white tile + silver hairline + soft navy shadow.
BoxDecoration staffDashboardCardDecoration({double borderRadius = 14}) {
  return BoxDecoration(
    color: kStaffCardSurface,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: kStaffSilverBorder,
      width: kStaffCardOutlineWidth,
    ),
    boxShadow: [
      BoxShadow(
        color: kStaffPrimaryNavy.withValues(alpha: 0.07),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

TextStyle staffAppBarTitleStyle() => const TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w700,
      fontSize: 20,
    );

TextStyle staffHeaderTextStyle({
  double fontSize = 18,
  Color color = kStaffPrimaryNavy,
}) =>
    TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      color: color,
    );

TextStyle staffLabelTextStyle({
  double fontSize = 13,
  Color color = kStaffMutedText,
}) =>
    TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      color: color,
    );

/// Primary CTA (confirm appointment, add schedule, etc.).
class StaffGoldGradientButton extends StatelessWidget {
  const StaffGoldGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.fontSize = 12,
    this.borderRadius = 10,
    this.isLoading = false,
    this.minHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double borderRadius;
  final bool isLoading;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: disabled && !isLoading
                ? LinearGradient(
                    colors: [
                      kStaffMutedText.withValues(alpha: 0.35),
                      kStaffMutedText.withValues(alpha: 0.45),
                    ],
                  )
                : kStaffGoldActionGradient,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: kStaffLuxGold.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minHeight ?? 0,
                minWidth: 0,
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: kStaffOnGoldText,
                        ),
                      )
                    : Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: fontSize,
                          color: disabled
                              ? Colors.white.withValues(alpha: 0.85)
                              : kStaffOnGoldText,
                          height: 1.15,
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
