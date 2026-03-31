import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firestore/hospital_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../models/hospital_localized_content.dart';
import '../specialty_categories.dart';
import 'doctor_details_screen.dart';
import 'patient_doctor_booking_screen.dart';
import 'patient_doctor_card.dart';
import 'patient_scroll_physics.dart';

/// Hospital header + doctors with `users.hospitalId` == [hospitalId].
class HospitalDoctorsScreen extends StatelessWidget {
  const HospitalDoctorsScreen({
    super.key,
    required this.hospitalId,
    required this.initialHospitalData,
  });

  final String hospitalId;
  final Map<String, dynamic> initialHospitalData;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    final dir = AppLocaleScope.of(context).textDirection;

    return Directionality(
      textDirection: dir,
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
            localizedHospitalName(initialHospitalData, lang),
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(HospitalFields.collection)
              .doc(hospitalId)
              .snapshots(),
          builder: (context, hospSnap) {
            final hospData = hospSnap.data?.data() != null
                ? Map<String, dynamic>.from(hospSnap.data!.data()!)
                : Map<String, dynamic>.from(initialHospitalData);

            final name = localizedHospitalName(hospData, lang);
            final desc = localizedHospitalDescription(hospData, lang);
            final location = (hospData['location'] ?? '').toString().trim();
            final logoUrl = (hospData['logoUrl'] ?? '').toString().trim();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: dir,
                      children: [
                        _HospitalLogo(logoUrl: logoUrl),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Color(0xFFD9E2EC),
                                  fontFamily: 'KurdishFont',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    color: Color(0xFF9FB3C8),
                                    fontFamily: 'KurdishFont',
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.place_outlined,
                                      size: 16,
                                      color: Color(0xFF42A5F5),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: const TextStyle(
                                          color: Color(0xFF829AB1),
                                          fontFamily: 'KurdishFont',
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    s.translate('hospital_doctors_section'),
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontFamily: 'KurdishFont',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: approvedDoctorsAtHospitalQuery(hospitalId).snapshots(),
                    builder: (context, docSnap) {
                      if (docSnap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              s.translate(
                                'hospital_doctors_load_error',
                                params: {'error': '${docSnap.error}'},
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontFamily: 'KurdishFont',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }
                      if (docSnap.connectionState == ConnectionState.waiting &&
                          !docSnap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                        );
                      }
                      final docs = docSnap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              s.translate('hospital_doctors_empty'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF829AB1),
                                fontFamily: 'KurdishFont',
                                fontSize: 15,
                              ),
                            ),
                          ),
                        );
                      }
                      final n = docs.length;
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        physics: patientPlatformScrollPhysics,
                        itemCount: n == 0 ? 0 : n * 2 - 1,
                        itemBuilder: (context, index) {
                          if (index.isOdd) {
                            return const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: 8),
                                DoctorCardGradientDivider(),
                                SizedBox(height: 8),
                              ],
                            );
                          }
                          final docIndex = index ~/ 2;
                          final doc = docs[docIndex];
                          final data = doc.data();
                          var dname = localizedDoctorFullName(data, lang);
                          if (dname.isEmpty) {
                            dname = (data['fullName'] ?? '—').toString();
                          }
                          final specialtyRaw =
                              (data['specialty'] ?? '—').toString();
                          final specialty = translatedSpecialtyForFirestore(
                            context,
                            specialtyRaw,
                          );
                          return PatientDoctorCard(
                            name: dname,
                            specialty: specialty,
                            profileImageUrl:
                                (data['profileImageUrl'] ?? '').toString(),
                            onBook: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      PatientDoctorBookingScreen(
                                    doctorId: doc.id,
                                    doctorData:
                                        Map<String, dynamic>.from(data),
                                  ),
                                ),
                              );
                            },
                            onOpenDetails: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => DoctorDetailsScreen(
                                    doctorId: doc.id,
                                    doctorData:
                                        Map<String, dynamic>.from(data),
                                    showBookingSection: false,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HospitalLogo extends StatelessWidget {
  const _HospitalLogo({required this.logoUrl});

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF12152A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isEmpty
          ? const Icon(Icons.local_hospital_rounded, color: Color(0xFF42A5F5), size: 32)
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              memCacheWidth: 128,
              memCacheHeight: 128,
              fadeInDuration: Duration.zero,
              errorWidget: (context, url, error) => const Icon(
                Icons.local_hospital_rounded,
                color: Color(0xFF42A5F5),
                size: 32,
              ),
            ),
    );
  }
}
