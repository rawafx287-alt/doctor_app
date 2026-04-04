import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/firestore_user_doc_id.dart';
import '../firestore/appointment_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import 'doctor_premium_shell.dart';

class _PatientEntry {
  const _PatientEntry({
    required this.patientId,
    required this.displayName,
    required this.lastVisitLabel,
  });

  final String patientId;
  final String displayName;
  final String lastVisitLabel;
}

/// Patients derived from this doctor's appointments (deduped by [patientId]).
class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static int _createdMs(Map<String, dynamic> data) {
    final c = data[AppointmentFields.createdAt];
    if (c is Timestamp) return c.millisecondsSinceEpoch;
    return 0;
  }

  static String? _lastVisitLine(
    Map<String, dynamic> data,
    AppLocalizations strings,
  ) {
    final day = _appointmentDayOnly(data[AppointmentFields.date]);
    if (day == null) return null;
    final nf = NumberFormat.decimalPattern('en_US');
    return strings.translate(
      'doctor_patients_last_visit',
      params: {
        'date':
            '\u200E${nf.format(day.year)} / ${nf.format(day.month)} / ${nf.format(day.day)}',
      },
    );
  }

  List<_PatientEntry> _dedupePatients(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    AppLocalizations strings,
  ) {
    final best = <String, ({int ts, String name, String? visit})>{};
    for (final d in docs) {
      final data = d.data();
      final pid = (data[AppointmentFields.patientId] ?? '').toString().trim();
      if (pid.isEmpty) continue;
      final name = (data[AppointmentFields.patientName] ?? '—').toString();
      final ts = _createdMs(data);
      final visit = _lastVisitLine(data, strings);
      final prev = best[pid];
      if (prev == null || ts >= prev.ts) {
        best[pid] = (ts: ts, name: name, visit: visit);
      }
    }
    final out = best.entries
        .map(
          (e) => _PatientEntry(
            patientId: e.key,
            displayName: e.value.name.trim().isEmpty ? '—' : e.value.name,
            lastVisitLabel:
                e.value.visit ?? strings.translate('doctor_patients_no_date'),
          ),
        )
        .toList();
    out.sort((a, b) => a.displayName.compareTo(b.displayName));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final docId = firestoreUserDocId(user).trim();

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: kDoctorPremiumGradientBottom,
        extendBodyBehindAppBar: true,
        appBar: doctorPremiumAppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: s.translate('tooltip_back'),
          ),
          title: Text(
            s.translate('doctor_patients_title'),
            style: const TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 17,
            ),
          ),
        ),
        body: docId.isEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  const DoctorPremiumBackground(),
                  Center(
                    child: Text(
                      s.translate('login_required'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  const DoctorPremiumBackground(),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(AppointmentFields.collection)
                        .where(AppointmentFields.doctorId, isEqualTo: docId)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '${snap.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFAB91),
                                fontFamily: kPatientPrimaryFont,
                              ),
                            ),
                          ),
                        );
                      }
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: kStaffLuxGold,
                          ),
                        );
                      }
                      final all = _dedupePatients(snap.data?.docs ?? [], s);
                      final q = _searchController.text.trim().toLowerCase();
                      final filtered = q.isEmpty
                          ? all
                          : all
                                .where(
                                  (p) =>
                                      p.displayName.toLowerCase().contains(q),
                                )
                                .toList();

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          children: [
                            _SearchField(
                              controller: _searchController,
                              hint: s.translate('doctor_patients_search_hint'),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: filtered.isEmpty
                                  ? Center(
                                      child: Text(
                                        s.translate('doctor_patients_empty'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.88,
                                          ),
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: filtered.length,
                                      separatorBuilder: (context, _) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final p = filtered[index];
                                        return _PatientGlassCard(
                                          name: p.displayName,
                                          subtitle: p.lastVisitLabel,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

DateTime? _appointmentDayOnly(dynamic date) {
  if (date == null) return null;
  if (date is Timestamp) {
    final d = date.toDate();
    return DateTime(d.year, d.month, d.day);
  }
  if (date is DateTime) {
    return DateTime(date.year, date.month, date.day);
  }
  return null;
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kStaffSilverBorder,
            width: kStaffCardOutlineWidth,
          ),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(
            color: Color(0xFFE8F4F0),
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search_rounded, color: kStaffLuxGold),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}

class _PatientGlassCard extends StatelessWidget {
  const _PatientGlassCard({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kStaffSilverBorder,
            width: kStaffCardOutlineWidth,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: kStaffAccentSlateBlue),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: kStaffLuxGold,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: const Color(
                                  0xFFC9C4B0,
                                ).withValues(alpha: 0.95),
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
