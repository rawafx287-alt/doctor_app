import 'package:flutter/material.dart';

/// Internal glossy gradients and overlays for calendar cells — no outer [BoxShadow].
abstract final class CalendarCrystalSurfaces {
  static const LinearGradient greenCrystalBase = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00E676),
      Color(0xFF00C853),
      Color(0xFF008122),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient redCrystalBase = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF5252),
      Color(0xFFD50000),
      Color(0xFF8B0000),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Fully booked (master calendar) — same polish, amber family.
  static const LinearGradient amberCrystalBase = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFE082),
      Color(0xFFF59E0B),
      Color(0xFFB45309),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color greenCrystalEdge = Color(0xFF006B47);
  static const Color redCrystalEdge = Color(0xFF7A0000);
  static const Color amberCrystalEdge = Color(0xFF92400E);

  /// Large panels (e.g. schedule “today”) — polished emerald sheet.
  static const LinearGradient scheduleTodayOpenPanelGradient = greenCrystalBase;

  static const LinearGradient scheduleTodayClosedPanelGradient = redCrystalBase;

  /// Specular highlight: top fade + diagonal sweep (inside cell only).
  static Widget glossOverlay({
    required BorderRadius borderRadius,
    double highlightStrength = 1.0,
  }) {
    final h = highlightStrength.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.52,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.30 * h),
                      Colors.white.withValues(alpha: 0.07 * h),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-0.9, -1.0),
                end: const Alignment(0.45, 0.25),
                colors: [
                  Colors.white.withValues(alpha: 0.22 * h),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.52],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lighter gloss for selected navy / neutral “gem” tiles.
  static Widget glossOverlaySubtle({required BorderRadius borderRadius}) {
    return glossOverlay(
      borderRadius: borderRadius,
      highlightStrength: 0.38,
    );
  }
}
