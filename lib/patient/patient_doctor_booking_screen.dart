import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../theme/patient_premium_theme.dart';
import 'doctor_details_screen.dart' show honorificDoctorDisplayName;
import 'patient_available_days_list.dart';

const Color _kSkyTop = kPatientSkyTop;
const Color _kDoctorNameNavy = Color(0xFF0D2137);

/// Patient: pick a date — calendar first, same data as [DoctorDetailsScreen] booking section.
class PatientDoctorBookingScreen extends StatelessWidget {
  const PatientDoctorBookingScreen({
    super.key,
    required this.doctorId,
    required this.doctorData,
  });

  final String doctorId;
  final Map<String, dynamic> doctorData;

  String get _doctorUid {
    final direct = doctorId.trim();
    if (direct.isNotEmpty) return direct;
    final fallback = (doctorData['uid'] ??
            doctorData['doctorId'] ??
            doctorData['id'] ??
            '')
        .toString()
        .trim();
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final appTextDir = AppLocaleScope.of(context).textDirection;
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    var doctorName = localizedDoctorFullName(doctorData, lang);
    if (doctorName.isEmpty) {
      doctorName =
          (doctorData['fullName'] ?? s.translate('doctor_default')).toString();
    }

    return Directionality(
      textDirection: appTextDir,
      child: Scaffold(
        backgroundColor: _kSkyTop,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          foregroundColor: _kDoctorNameNavy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: s.translate('tooltip_back'),
          ),
          title: Text(
            honorificDoctorDisplayName(doctorName),
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: _kDoctorNameNavy,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: _doctorUid.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                )
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_doctorUid)
                .snapshots(),
            builder: (context, snap) {
              final merged = <String, dynamic>{
                ...doctorData,
                if (snap.data?.data() != null) ...snap.data!.data()!,
              };
              var doctorDisplayName = localizedDoctorFullName(merged, lang);
              if (doctorDisplayName.isEmpty) {
                doctorDisplayName = (merged['fullName'] ?? doctorName).toString();
              }
              if (uid == null) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: PatientAvailableDaysList(
                    doctorId: _doctorUid,
                    patientName: s.translate('patient_default'),
                    doctorDisplayName: doctorDisplayName,
                    mergedDoctorData: merged,
                  ),
                );
              }
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid.trim())
                    .snapshots(),
                builder: (context, patientSnap) {
                  final patientWaiting =
                      patientSnap.connectionState == ConnectionState.waiting &&
                      !patientSnap.hasData;
                  final patientName = patientWaiting
                      ? s.translate('patient_default')
                      : (patientSnap.data?.data()?['fullName'] ??
                              s.translate('patient_default'))
                          .toString();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: PatientAvailableDaysList(
                      doctorId: _doctorUid,
                      patientName: patientName,
                      doctorDisplayName: doctorDisplayName,
                      mergedDoctorData: merged,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
