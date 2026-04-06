import 'package:flutter/material.dart';

import '../theme/staff_premium_theme.dart';

/// Same tokens as [kStaffShellGradient*] — doctor / admin / secretary shells.
const Color kDoctorPremiumGradientTop = kStaffShellGradientTop;
const Color kDoctorPremiumGradientMid = kStaffShellGradientMid;
const Color kDoctorPremiumGradientBottom = kStaffShellGradientBottom;

const BoxDecoration kDoctorPremiumGradientDecoration =
    kStaffShellGradientDecoration;

/// Subtle cross grid at low opacity (matches admin dashboard veil).
class DoctorMedicalVeilPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.05);
    const step = 52.0;
    const arm = 7.0;
    const thick = 2.2;
    for (var y = -step; y < size.height + step; y += step) {
      final row = ((y + step) / step).round();
      for (var x = -step; x < size.width + step; x += step) {
        final shift = row.isOdd ? step * 0.5 : 0.0;
        final c = Offset(x + shift + step * 0.5, y + step * 0.5);
        final h = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: arm * 2, height: thick),
          const Radius.circular(1.5),
        );
        final v = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: thick, height: arm * 2),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(h, p);
        canvas.drawRRect(v, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-screen gradient + medical veil for doctor flows.
class DoctorPremiumBackground extends StatelessWidget {
  const DoctorPremiumBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: kDoctorPremiumGradientDecoration),
        Positioned.fill(
          child: CustomPaint(painter: DoctorMedicalVeilPainter()),
        ),
      ],
    );
  }
}

/// Transparent [AppBar] for use over [DoctorPremiumBackground].
PreferredSizeWidget doctorPremiumAppBar({
  required Widget title,
  List<Widget>? actions,
  Widget? leading,
  bool centerTitle = true,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: centerTitle,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    title: DefaultTextStyle(
      style: const TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        fontSize: 17,
      ),
      child: title,
    ),
    iconTheme: const IconThemeData(color: kStaffLuxGold),
    actionsIconTheme: const IconThemeData(color: kStaffLuxGold),
    actions: actions,
  );
}
