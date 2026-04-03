import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../doctor/available_days_schedule_screen.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';

/// Secretary: doctor picker + same [TableCalendar] as doctor (managed doctor uid).
class SecretaryAvailableDaysScreen extends StatefulWidget {
  const SecretaryAvailableDaysScreen({super.key});

  @override
  State<SecretaryAvailableDaysScreen> createState() =>
      _SecretaryAvailableDaysScreenState();
}

class _SecretaryAvailableDaysScreenState
    extends State<SecretaryAvailableDaysScreen> {
  String? _pickedDoctorId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          title: Text(
            s.translate('secretary_available_days_title'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
          actions: [
            IconButton(
              tooltip: s.translate('tooltip_logout'),
              onPressed: () => performAppLogout(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'Doctor')
                      .where('isApproved', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const LinearProgressIndicator(minHeight: 2);
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Text(
                        s.translate('master_calendar_no_doctors'),
                        style: const TextStyle(
                          color: Color(0xFF829AB1),
                          fontFamily: 'NRT',
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _pickedDoctorId != null &&
                              docs.any((d) => d.id == _pickedDoctorId)
                          ? _pickedDoctorId
                          : null,
                      dropdownColor: const Color(0xFF1D1E33),
                      decoration: InputDecoration(
                        labelText: s.translate('master_calendar_pick_doctor'),
                        labelStyle: const TextStyle(
                          color: Color(0xFF829AB1),
                          fontFamily: 'NRT',
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1D1E33),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      items: docs
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                localizedDoctorFullName(
                                  d.data(),
                                  AppLocaleScope.of(context).effectiveLanguage,
                                ),
                                style: const TextStyle(
                                  fontFamily: 'NRT',
                                  color: Color(0xFFD9E2EC),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _pickedDoctorId = v),
                    );
                  },
                ),
              ),
              Expanded(
                child: _pickedDoctorId == null
                    ? Center(
                        child: Text(
                          s.translate('master_calendar_pick_doctor'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'NRT',
                          ),
                        ),
                      )
                    : AvailableDaysScheduleScreen(
                        embedded: true,
                        managedDoctorUserId: _pickedDoctorId,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
