import 'package:flutter/material.dart';

/// HR Nora — medical blue brand palette.
abstract final class HrNoraColors {
  /// Primary actions, key UI (Material Blue 900).
  static const Color primary = Color(0xFF0D47A1);

  /// Surfaces, app bars (Indigo 900).
  static const Color primaryDeep = Color(0xFF1A237E);

  /// Icons, highlights, selected states on dark backgrounds.
  static const Color accentLight = Color(0xFF64B5F6);

  static const Color scaffoldDark = Color(0xFF0A0E21);
  static const Color textSoft = Color(0xFFD9E2EC);
  static const Color textMuted = Color(0xFF829AB1);

  /// Closed / off days, non-working calendar cells, “busy” slot accents — deep maroon (use white numerals on fill).
  static const Color closedDayFill = Color(0xFF730000);

  /// Darker maroon edge for closed cells when unselected (selected cells use gold ring elsewhere).
  static const Color closedDayBorder = Color(0xFF4D0000);

  /// Open / available calendar days, “on” clinic state, completed / active greens — deep teal (white numerals on fill).
  static const Color openDayFill = Color(0xFF004D40);

  /// Darker forest edge for open cells and depth (pairs with [openDayFill]).
  static const Color openDayBorder = Color(0xFF00332E);

  /// Lighter teal for gradients and highlights (e.g. “today” panels).
  static const Color openDayGradientLight = Color(0xFF00695C);

  /// Large “today / shifts” summary cards — premium depth vs flat bright green.
  static const LinearGradient openDayTodayPanelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [openDayGradientLight, openDayFill],
  );
}
