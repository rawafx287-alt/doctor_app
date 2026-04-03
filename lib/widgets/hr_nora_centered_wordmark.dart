import 'package:flutter/material.dart';

import '../theme/patient_premium_theme.dart';
import '../theme/staff_premium_theme.dart';

/// Compact centered **HR** + gold medical mark + **Nora** for staff app bars.
class HrNoraCenteredWordmark extends StatelessWidget {
  const HrNoraCenteredWordmark({
    super.key,
    this.fontSize = 20,
  });

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: kPatientDeepBlue,
      height: 1,
      letterSpacing: -0.15,
      shadows: const [
        Shadow(
          color: Color(0x14000000),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );
    final iconBox = fontSize * 1.05;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        Text('HR', style: style),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: fontSize * 0.28),
          child: Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: kStaffGoldActionGradient,
              boxShadow: [
                BoxShadow(
                  color: kStaffLuxGold.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.medical_services_rounded,
              size: fontSize * 0.88,
              color: Colors.white,
            ),
          ),
        ),
        Text('Nora', style: style),
      ],
    );
  }
}
