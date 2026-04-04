import 'package:flutter/material.dart';

import 'staff_premium_theme.dart' show kStaffLuxGold, kStaffShellGradientTop;
import 'patient_premium_theme.dart' show kPatientPrimaryFont;

/// Vibrant emerald for selected AM/PM (matches crystal open-day accent).
const Color kStaffTimePickerEmerald = Color(0xFF00C853);

/// Semi-transparent deep indigo for unselected day-period segment.
const Color kStaffTimePickerDayPeriodUnselected = Color(0x661A237E);

/// Deep navy glass surface for the time picker dialog body.
Color get kStaffTimePickerDialogSurface =>
    kStaffShellGradientTop.withValues(alpha: 0.94);

/// Theme merged into [Theme.of(context)] for [showTimePicker] only.
ThemeData staffTimePickerDialogTheme(ThemeData base) {
  final navy = kStaffTimePickerDialogSurface;
  final goldBorder = BorderSide(
    color: kStaffLuxGold.withValues(alpha: 0.5),
    width: 0.5,
  );
  final dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: goldBorder,
  );

  final cs = base.colorScheme.copyWith(
    brightness: Brightness.dark,
    primary: kStaffTimePickerEmerald,
    onPrimary: Colors.white,
    secondary: kStaffTimePickerEmerald,
    onSecondary: Colors.white,
    surface: navy,
    onSurface: Colors.white,
    onSurfaceVariant: Colors.white,
    surfaceContainerHighest: kStaffTimePickerDayPeriodUnselected,
    surfaceContainerHigh: kStaffTimePickerDayPeriodUnselected,
    primaryContainer: kStaffTimePickerDayPeriodUnselected,
    onPrimaryContainer: Colors.white,
    secondaryContainer: kStaffTimePickerDayPeriodUnselected,
    onSecondaryContainer: Colors.white,
    outline: kStaffLuxGold.withValues(alpha: 0.45),
  );

  final goldTextButton = ButtonStyle(
    foregroundColor: WidgetStateProperty.all(kStaffLuxGold),
    textStyle: WidgetStateProperty.all(
      const TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: cs,
    dialogTheme: DialogThemeData(
      backgroundColor: navy,
      shape: dialogShape,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: navy,
      shape: dialogShape,
      hourMinuteTextColor: Colors.white,
      dayPeriodTextColor: Colors.white,
      helpTextStyle: const TextStyle(
        fontFamily: kPatientPrimaryFont,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      hourMinuteTextStyle: const TextStyle(
        fontFamily: kPatientPrimaryFont,
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 22,
      ),
      cancelButtonStyle: goldTextButton,
      confirmButtonStyle: goldTextButton,
    ),
    textButtonTheme: TextButtonThemeData(style: goldTextButton),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.07),
      labelStyle: const TextStyle(
        fontFamily: kPatientPrimaryFont,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        fontFamily: kPatientPrimaryFont,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        fontFamily: kPatientPrimaryFont,
        color: Colors.white.withValues(alpha: 0.45),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: kStaffLuxGold.withValues(alpha: 0.92),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: kStaffLuxGold.withValues(alpha: 0.65),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: kStaffLuxGold.withValues(alpha: 0.92),
          width: 2,
        ),
      ),
    ),
  );
}
