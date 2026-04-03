import 'package:flutter/material.dart';

import 'patient_premium_theme.dart' show kPatientPrimaryFont;

export 'patient_premium_theme.dart' show kPatientPrimaryFont;

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
