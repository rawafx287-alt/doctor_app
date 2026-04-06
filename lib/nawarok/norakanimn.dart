import 'package:flutter/material.dart';

import '../locale/app_localizations.dart';
import '../patient/my_appointments_screen.dart';

/// Patient appointments tab (نۆرەکانم) — live Firestore list, today-only by default.
class NorekaniMinScreen extends StatelessWidget {
  const NorekaniMinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: Text(
          S.of(context).translate('appointments'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            fontFamily: 'NRT',
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: const Color(0xFFD9E2EC),
        elevation: 0,
      ),
      body: const PatientAppointmentsScreen(embedded: true),
    );
  }
}
