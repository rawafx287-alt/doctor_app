import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../specialty_categories.dart';
import 'patient_available_days_list.dart';

const Color _kSkyTop = Color(0xFFE1F5FE);
const Color _kSkyBottom = Color(0xFFB3E5FC);
const Color _kDoctorNameNavy = Color(0xFF0D2137);
const Color _kPremiumDeepBlue = Color(0xFF1A237E);
const Color _kBodyGrey = Color(0xFF455A64);
const Color _kSectionTitle = Color(0xFF0D47A1);
const Color _kHonorificGlowGold = Color(0xFFC9A227);
const String _kDoctorHonorificPrefix = 'د. ';

/// Prefixes [_kDoctorHonorificPrefix] when the name has no doctor-style prefix yet.
String honorificDoctorDisplayName(String rawName) {
  var t = rawName.trim();
  if (t.isEmpty) return t;
  final lower = t.toLowerCase();
  if (lower.startsWith('د.') ||
      lower.startsWith('د .') ||
      lower.startsWith('dr.') ||
      lower.startsWith('dr ')) {
    return t;
  }
  return '$_kDoctorHonorificPrefix$t';
}

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
    required this.doctorData,
    this.showBookingSection = true,
  });

  final String doctorId;
  final Map<String, dynamic> doctorData;

  /// When `false`, only profile (bio, experience, location) — no calendar or book CTA.
  final bool showBookingSection;

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
        backgroundColor: _kSkyTop,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          foregroundColor: _kDoctorNameNavy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.black26,
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kSkyTop, _kSkyBottom],
            ),
          ),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                doctorDisplayName = (merged['fullName'] ?? doctorName)
                    .toString();
              }
              final profileImageUrl = (merged['profileImageUrl'] ?? '')
                  .toString()
                  .trim();
              return uid == null
                  ? Center(
                      child: Text(
                        s.translate('login_required'),
                        style: TextStyle(
                          color: _kBodyGrey.withValues(alpha: 0.9),
                          fontFamily: 'KurdishFont',
                          fontWeight: FontWeight.w600,
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

                        final lang = AppLocaleScope.of(
                          context,
                        ).effectiveLanguage;
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 16,
                                    sigmaY: 16,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.52,
                                      ),
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _kPremiumDeepBlue.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        26,
                                        24,
                                        26,
                                      ),
                                      child: Row(
                                        textDirection: appTextDir,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 76,
                                            height: 76,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF90CAF9,
                                                  ).withValues(alpha: 0.55),
                                                  blurRadius: 16,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3),
                                              child: DecoratedBox(
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0xFFE3F2FD),
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
                                                          color: const Color(
                                                            0xFFE3F2FD,
                                                          ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: const Icon(
                                                            Icons
                                                                .medical_services_rounded,
                                                            color: Color(
                                                              0xFF1565C0,
                                                            ),
                                                            size: 30,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 18),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: BackdropFilter(
                                                    filter: ImageFilter.blur(
                                                      sigmaX: 12,
                                                      sigmaY: 12,
                                                    ),
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.72,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.95,
                                                              ),
                                                          width: 1.2,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color:
                                                                _kHonorificGlowGold
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    ),
                                                            blurRadius: 18,
                                                            spreadRadius: 0,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  4,
                                                                ),
                                                          ),
                                                          BoxShadow(
                                                            color:
                                                                const Color(
                                                                  0xFF1565C0,
                                                                ).withValues(
                                                                  alpha: 0.22,
                                                                ),
                                                            blurRadius: 22,
                                                            spreadRadius: -2,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.05,
                                                                ),
                                                            blurRadius: 14,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  6,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 14,
                                                              vertical: 12,
                                                            ),
                                                        child: Row(
                                                          textDirection:
                                                              appTextDir,
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                honorificDoctorDisplayName(
                                                                  doctorDisplayName,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .start,
                                                                style: const TextStyle(
                                                                  color:
                                                                      _kDoctorNameNavy,
                                                                  fontSize: 22,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  fontFamily:
                                                                      'KurdishFont',
                                                                  height: 1.15,
                                                                  letterSpacing:
                                                                      0.4,
                                                                  shadows: [
                                                                    Shadow(
                                                                      color: Color(
                                                                        0x1AFFFFFF,
                                                                      ),
                                                                      blurRadius:
                                                                          6,
                                                                      offset:
                                                                          Offset(
                                                                            0,
                                                                            1,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Icon(
                                                              Icons
                                                                  .verified_user_rounded,
                                                              color:
                                                                  const Color(
                                                                    0xFF1565C0,
                                                                  ),
                                                              size: 26,
                                                              shadows: [
                                                                Shadow(
                                                                  color:
                                                                      Color(
                                                                        0xFF90CAF9,
                                                                      ).withValues(
                                                                        alpha:
                                                                            0.65,
                                                                      ),
                                                                  blurRadius: 8,
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 14),
                                                Align(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .centerStart,
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            24,
                                                          ),
                                                      gradient:
                                                          const LinearGradient(
                                                            begin: Alignment
                                                                .centerLeft,
                                                            end: Alignment
                                                                .centerRight,
                                                            colors: [
                                                              Color(0xFF1976D2),
                                                              Color(0xFF0D47A1),
                                                            ],
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color:
                                                              const Color(
                                                                0xFF1976D2,
                                                              ).withValues(
                                                                alpha: 0.28,
                                                              ),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 8,
                                                          ),
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
                                                        textAlign:
                                                            TextAlign.start,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontFamily:
                                                              'KurdishFont',
                                                          height: 1.25,
                                                          letterSpacing: 0.15,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (bio.isNotEmpty) ...[
                                Text(
                                  s.translate('doctor_profile_about'),
                                  textAlign: TextAlign.start,
                                  style: const TextStyle(
                                    color: _kSectionTitle,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'KurdishFont',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  bio,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    color: _kBodyGrey.withValues(alpha: 0.95),
                                    fontSize: 15,
                                    fontFamily: 'KurdishFont',
                                    fontWeight: FontWeight.w500,
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
                                    color: _kSectionTitle,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'KurdishFont',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  experienceText,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    color: _kBodyGrey.withValues(alpha: 0.95),
                                    fontSize: 15,
                                    fontFamily: 'KurdishFont',
                                    fontWeight: FontWeight.w500,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              if (hospital.isNotEmpty ||
                                  address.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 12,
                                      sigmaY: 12,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.48,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.75,
                                          ),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.translate(
                                                'doctor_profile_location',
                                              ),
                                              textAlign: TextAlign.start,
                                              style: const TextStyle(
                                                color: _kSectionTitle,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                fontFamily: 'KurdishFont',
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            if (hospital.isNotEmpty) ...[
                                              Text(
                                                s.translate(
                                                  'doctor_profile_hospital_label',
                                                ),
                                                style: TextStyle(
                                                  color: _kPremiumDeepBlue
                                                      .withValues(alpha: 0.75),
                                                  fontSize: 12,
                                                  fontFamily: 'KurdishFont',
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                hospital,
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  color: _kBodyGrey.withValues(
                                                    alpha: 0.95,
                                                  ),
                                                  fontSize: 15,
                                                  fontFamily: 'KurdishFont',
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                            if (address.isNotEmpty) ...[
                                              Text(
                                                s.translate(
                                                  'doctor_profile_address_label',
                                                ),
                                                style: TextStyle(
                                                  color: _kPremiumDeepBlue
                                                      .withValues(alpha: 0.75),
                                                  fontSize: 12,
                                                  fontFamily: 'KurdishFont',
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                address,
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  color: _kBodyGrey.withValues(
                                                    alpha: 0.95,
                                                  ),
                                                  fontSize: 15,
                                                  fontFamily: 'KurdishFont',
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              if (widget.showBookingSection) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 400,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            final ctx =
                                                _bookingSectionKey
                                                    .currentContext;
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
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                16,
                                              ),
                                              gradient: const LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: [
                                                  Color(0xFF1E88E5),
                                                  Color(0xFF1565C0),
                                                  Color(0xFF0D47A1),
                                                ],
                                                stops: [0.0, 0.45, 1.0],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(
                                                    0xFF1976D2,
                                                  ).withValues(alpha: 0.48),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 8),
                                                  spreadRadius: 0,
                                                ),
                                                BoxShadow(
                                                  color: Color(
                                                    0xFF42A5F5,
                                                  ).withValues(alpha: 0.22),
                                                  blurRadius: 28,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 16,
                                                horizontal: 18,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.calendar_month_rounded,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Flexible(
                                                    child: Text(
                                                      s.translate('book_now'),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            'KurdishFont',
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 15,
                                                        color: Colors.white,
                                                        height: 1.25,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
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
                            ],
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
