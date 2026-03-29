import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../specialty_categories.dart';
import 'patient_available_days_list.dart';

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
    required this.doctorData,
  });

  final String doctorId;
  final Map<String, dynamic> doctorData;

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  final GlobalKey _bookingSectionKey = GlobalKey();

  String get _doctorUid => widget.doctorId.trim();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final appTextDir = AppLocaleScope.of(context).textDirection;
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    var doctorName = localizedDoctorFullName(widget.doctorData, lang);
    if (doctorName.isEmpty) {
      doctorName =
          (widget.doctorData['fullName'] ?? s.translate('doctor_default'))
              .toString();
    }
    final specialty = (widget.doctorData['specialty'] ?? '—').toString();

    return Directionality(
      textDirection: appTextDir,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: s.translate('tooltip_back'),
          ),
          title: Text(
            doctorName,
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_doctorUid)
              .snapshots(),
          builder: (context, snap) {
            final merged = <String, dynamic>{
              ...widget.doctorData,
              if (snap.data?.data() != null) ...snap.data!.data()!,
            };
            final mergedSpecialty = (merged['specialty'] ?? specialty)
                .toString();
            var doctorDisplayName = localizedDoctorFullName(merged, lang);
            if (doctorDisplayName.isEmpty) {
              doctorDisplayName = (merged['fullName'] ?? doctorName).toString();
            }
            final profileImageUrl = (merged['profileImageUrl'] ?? '')
                .toString()
                .trim();
            return uid == null
                ? Center(
                    child: Text(
                      s.translate('login_required'),
                      style: const TextStyle(
                        color: Color(0xFF829AB1),
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                  )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid.trim())
                        .snapshots(),
                    builder: (context, patientSnap) {
                      final patientWaiting =
                          patientSnap.connectionState ==
                              ConnectionState.waiting &&
                          !patientSnap.hasData;
                      final patientName = patientWaiting
                          ? s.translate('patient_default')
                          : (patientSnap.data?.data()?['fullName'] ??
                                    s.translate('patient_default'))
                                .toString();

                      final lang = AppLocaleScope.of(context).effectiveLanguage;
                      final bio = localizedDoctorField(
                        merged,
                        lang,
                        baseKey: 'bio',
                        legacyKeys: const ['biography', 'about'],
                      );
                      final hospital = localizedDoctorField(
                        merged,
                        lang,
                        baseKey: 'hospital_name',
                        legacyKeys: const ['clinicName', 'hospitalName'],
                      );
                      final address = localizedDoctorField(
                        merged,
                        lang,
                        baseKey: 'address',
                        legacyKeys: const ['clinicAddress'],
                      );
                      var experienceText = localizedDoctorField(
                        merged,
                        lang,
                        baseKey: 'experience',
                        legacyKeys: const [],
                      );
                      if (experienceText.isEmpty) {
                        final rawY = merged['yearsExperience'];
                        int? yi;
                        if (rawY is int) {
                          yi = rawY;
                        } else if (rawY is num) {
                          yi = rawY.toInt();
                        } else {
                          yi = int.tryParse(rawY?.toString() ?? '');
                        }
                        if (yi != null && yi > 0) {
                          experienceText = s.translate(
                            'doctor_experience_years',
                            params: {'years': '$yi'},
                          );
                        }
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D1E33),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                textDirection: appTextDir,
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF42A5F5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        profileImageUrl.isNotEmpty
                                            ? profileImageUrl
                                            : _placeholderImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (
                                              context,
                                              error,
                                              stackTrace,
                                            ) => Container(
                                              color: const Color(0xFF1D1E33),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.medical_services_rounded,
                                                color: Color(0xFF42A5F5),
                                                size: 28,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      s.translate(
                                        'specialty_colon',
                                        params: {
                                          'value':
                                              translatedSpecialtyForFirestore(
                                                context,
                                                mergedSpecialty,
                                              ),
                                        },
                                      ),
                                      textAlign: TextAlign.start,
                                      style: const TextStyle(
                                        color: Color(0xFF829AB1),
                                        fontSize: 15,
                                        fontFamily: 'KurdishFont',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (bio.isNotEmpty) ...[
                              Text(
                                s.translate('doctor_profile_about'),
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: Color(0xFFD9E2EC),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'KurdishFont',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                bio,
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: Color(0xFF9FB3C8),
                                  fontSize: 15,
                                  fontFamily: 'KurdishFont',
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            if (experienceText.isNotEmpty) ...[
                              Text(
                                s.translate('doctor_profile_experience'),
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: Color(0xFFD9E2EC),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'KurdishFont',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                experienceText,
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: Color(0xFF9FB3C8),
                                  fontSize: 15,
                                  fontFamily: 'KurdishFont',
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            if (hospital.isNotEmpty || address.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D1E33),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.translate('doctor_profile_location'),
                                      textAlign: TextAlign.start,
                                      style: const TextStyle(
                                        color: Color(0xFFD9E2EC),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'KurdishFont',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (hospital.isNotEmpty) ...[
                                      Text(
                                        s.translate(
                                          'doctor_profile_hospital_label',
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF829AB1),
                                          fontSize: 12,
                                          fontFamily: 'KurdishFont',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        hospital,
                                        textAlign: TextAlign.start,
                                        style: const TextStyle(
                                          color: Color(0xFF9FB3C8),
                                          fontSize: 15,
                                          fontFamily: 'KurdishFont',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    if (address.isNotEmpty) ...[
                                      Text(
                                        s.translate(
                                          'doctor_profile_address_label',
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF829AB1),
                                          fontSize: 12,
                                          fontFamily: 'KurdishFont',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        address,
                                        textAlign: TextAlign.start,
                                        style: const TextStyle(
                                          color: Color(0xFF9FB3C8),
                                          fontSize: 15,
                                          fontFamily: 'KurdishFont',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final ctx = _bookingSectionKey.currentContext;
                                  if (ctx != null) {
                                    Scrollable.ensureVisible(
                                      ctx,
                                      duration: const Duration(
                                        milliseconds: 420,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      alignment: 0.12,
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.event_available_rounded,
                                  color: Color(0xFF42A5F5),
                                ),
                                label: Text(
                                  s.translate('book_now'),
                                  style: const TextStyle(
                                    fontFamily: 'KurdishFont',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF42A5F5),
                                  side: const BorderSide(
                                    color: Color(0xFF42A5F5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            KeyedSubtree(
                              key: _bookingSectionKey,
                              child: PatientAvailableDaysList(
                                doctorId: _doctorUid,
                                patientName: patientName,
                                doctorDisplayName: doctorDisplayName,
                                mergedDoctorData: merged,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
          },
        ),
      ),
    );
  }
}

