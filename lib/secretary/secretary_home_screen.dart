import 'package:flutter/material.dart';

import '../calendar/master_calendar_screen.dart';
import '../locale/app_locale.dart';

/// Secretary home: master month calendar with doctor selector (Firestore role: `Secretary`).
class SecretaryHomeScreen extends StatelessWidget {
  const SecretaryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: const MasterCalendarScreen(
        showDoctorPicker: true,
        canManage: true,
        isRootShell: true,
      ),
    );
  }
}
