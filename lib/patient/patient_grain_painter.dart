import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Very subtle film grain for glass surfaces (doctor cards, sticky headers).
class PatientSubtleGrainPainter extends CustomPainter {
  PatientSubtleGrainPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final p = Paint();
    for (var i = 0; i < 150; i++) {
      p.color = Colors.white.withValues(
        alpha: 0.028 + rnd.nextDouble() * 0.045,
      );
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 0.85 + 0.22,
        p,
      );
    }
    for (var i = 0; i < 70; i++) {
      p.color = Colors.black.withValues(
        alpha: 0.012 + rnd.nextDouble() * 0.028,
      );
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 0.75 + 0.18,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PatientSubtleGrainPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
