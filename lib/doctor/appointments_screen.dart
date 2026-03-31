import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/appointment_queries.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/patient_profile_read.dart';
import '../auth/firestore_user_doc_id.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    this.embedded = false,
    this.doctorUserId,
  });

  /// When true, used inside [IndexedStack] without an [AppBar] (parent supplies title).
  final bool embedded;
  final String? doctorUserId;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();

  static String _statusKey(dynamic raw) {
    return (raw ?? 'pending').toString().trim().toLowerCase();
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortNewestFirst(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    int ts(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final c = d.data()[AppointmentFields.createdAt];
      if (c is Timestamp) return c.millisecondsSinceEpoch;
      return 0;
    }

    list.sort((a, b) => ts(b).compareTo(ts(a)));
    return list;
  }

  static String _formatDateTime(Map<String, dynamic> data) {
    final date = data[AppointmentFields.date];
    final time = (data[AppointmentFields.time] ?? '—').toString();
    String datePart = '—';
    if (date is Timestamp) {
      datePart = DateFormat('yyyy/MM/dd').format(date.toDate());
    } else if (date is String && date.trim().isNotEmpty) {
      datePart = date.trim();
    }
    return '$datePart  •  $time';
  }

  static String _localizedGender(BuildContext context, String raw) {
    if (raw.isEmpty) return S.of(context).translate('doctor_appt_not_available');
    final n = raw.toLowerCase().trim();
    final s = S.of(context);
    const maleHints = {'male', 'm', 'man', 'ذكر', 'رجل', 'نێر'};
    const femaleHints = {'female', 'f', 'woman', 'أنثى', 'انثى', 'مێ'};
    if (maleHints.contains(n)) return s.translate('doctor_appt_gender_male');
    if (femaleHints.contains(n)) return s.translate('doctor_appt_gender_female');
    return raw;
  }

  static Uri? _telUri(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.isEmpty) return null;
    return Uri.parse('tel:$cleaned');
  }

  static Future<void> _launchTel(BuildContext context, String phone) async {
    final s = S.of(context);
    final uri = _telUri(phone);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('doctor_appt_call_failed'),
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('doctor_appt_call_failed'),
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    }
  }

  static void _showPatientDetail(
    BuildContext context, {
    required Map<String, dynamic>? patientProfile,
    required String fallbackPatientName,
    required String dateTimeLine,
    required String status,
  }) {
    final s = S.of(context);
    final dir = AppLocaleScope.of(context).textDirection;
    final name = (patientProfile?['fullName'] ?? fallbackPatientName).toString().trim();
    final displayName = name.isEmpty ? fallbackPatientName : name;
    final age = patientAgeYearsFromUserData(patientProfile);
    final ageStr = age != null ? '$age' : s.translate('doctor_appt_not_available');
    final genderRaw = patientGenderRawFromUserData(patientProfile);
    final genderStr = _localizedGender(context, genderRaw);
    final phone = patientPhoneFromUserData(patientProfile);
    final phoneStr = phone.isNotEmpty ? phone : s.translate('doctor_appt_not_available');
    final email = patientEmailFromUserData(patientProfile);
    final emailStr = email.isNotEmpty ? email : s.translate('doctor_appt_not_available');
    final history = patientMedicalHistoryFromUserData(patientProfile);
    final historyBody = history.isNotEmpty
        ? history
        : s.translate('doctor_appt_no_medical_history');

    String statusLabel() {
      switch (_statusKey(status)) {
        case 'completed':
          return s.translate('doctor_appt_status_completed');
        case 'cancelled':
          return s.translate('doctor_appt_status_cancelled');
        default:
          return s.translate('doctor_appt_status_pending');
      }
    }

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: dir,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(
              s.translate('doctor_appt_patient_profile_title'),
              style: const TextStyle(
                fontFamily: 'KurdishFont',
                color: Color(0xFFD9E2EC),
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailLine(label: s.translate('doctor_appt_patient_name_label'), value: displayName),
                  _DetailLine(label: s.translate('doctor_appt_label_age'), value: ageStr),
                  _DetailLine(label: s.translate('doctor_appt_label_gender'), value: genderStr),
                  _DetailLine(label: s.translate('doctor_appt_label_phone'), value: phoneStr),
                  _DetailLine(label: s.translate('doctor_appt_label_email'), value: emailStr),
                  _DetailLine(label: s.translate('doctor_appt_datetime_label'), value: dateTimeLine),
                  _DetailLine(label: s.translate('doctor_appt_label_appointment_status'), value: statusLabel()),
                  const SizedBox(height: 12),
                  Text(
                    s.translate('doctor_appt_medical_history_section'),
                    style: TextStyle(
                      color: const Color(0xFF829AB1).withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    historyBody,
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontSize: 14,
                      height: 1.4,
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  s.translate('doctor_appt_close'),
                  style: const TextStyle(
                    color: Color(0xFF42A5F5),
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _ageGenderPhoneSummary(
    BuildContext context,
    Map<String, dynamic>? profile,
    bool patientLoading,
  ) {
    final s = S.of(context);
    if (patientLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: const Color(0xFF42A5F5).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '…',
              style: TextStyle(
                color: const Color(0xFF829AB1).withValues(alpha: 0.9),
                fontSize: 11,
                fontFamily: 'KurdishFont',
              ),
            ),
          ],
        ),
      );
    }

    final age = patientAgeYearsFromUserData(profile);
    final agePart = age != null
        ? '${s.translate('doctor_appt_label_age')}: $age'
        : '${s.translate('doctor_appt_label_age')}: ${s.translate('doctor_appt_not_available')}';
    final genderRaw = patientGenderRawFromUserData(profile);
    final genderPart = genderRaw.isNotEmpty
        ? '${s.translate('doctor_appt_label_gender')}: ${_localizedGender(context, genderRaw)}'
        : '${s.translate('doctor_appt_label_gender')}: ${s.translate('doctor_appt_not_available')}';
    final phone = patientPhoneFromUserData(profile);
    final phonePart = phone.isNotEmpty
        ? '${s.translate('doctor_appt_label_phone')}: $phone'
        : '${s.translate('doctor_appt_label_phone')}: ${s.translate('doctor_appt_not_available')}';

    const compactMeta = TextStyle(
      color: Color(0xFF829AB1),
      fontSize: 11,
      height: 1.2,
      fontFamily: 'KurdishFont',
    );

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$agePart  ·  $genderPart', style: compactMeta),
          const SizedBox(height: 2),
          Text(
            phonePart,
            style: compactMeta.copyWith(fontSize: 12, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  Set<String> _doctorIdsForQueries() {
    final fromTab = widget.doctorUserId?.trim() ?? '';
    if (fromTab.isNotEmpty) {
      return <String>{fromTab};
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <String>{};
    final ids = <String>{};
    final uid = user.uid.trim();
    if (uid.isNotEmpty) ids.add(uid);
    final docId = firestoreUserDocId(user).trim();
    if (docId.isNotEmpty) ids.add(docId);
    return ids;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _watchDoctorAppointmentsAnyAlias(Set<String> doctorIds) {
    final start = DateTime(2020, 1, 1);
    final end = DateTime(2100, 1, 1);
    final streams = doctorIds
        .map(
          (id) => appointmentsForDoctorDateRange(
            doctorUserId: id,
            rangeStartInclusiveLocal: start,
            rangeEndExclusiveLocal: end,
          ).snapshots(),
        )
        .toList();

    return Stream.multi((controller) {
      final latest =
          List<QuerySnapshot<Map<String, dynamic>>?>.filled(streams.length, null);
      void emitMerged() {
        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final snap in latest) {
          for (final d in snap?.docs ?? const []) {
            byId[d.id] = d;
          }
        }
        controller.add(byId.values.toList());
      }

      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < streams.length; i++) {
        subs.add(
          streams[i].listen(
            (event) {
              latest[i] = event;
              emitMerged();
            },
            onError: controller.addError,
          ),
        );
      }
      controller.onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    });
  }

  Future<void> _setStatus(BuildContext context, String docId, String status) async {
    final s = S.of(context);
    try {
      await FirebaseFirestore.instance
          .collection(AppointmentFields.collection)
          .doc(docId)
          .update({
        AppointmentFields.status: status,
        AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'completed'
                  ? s.translate('doctor_appointment_done_snack')
                  : s.translate('doctor_appointment_cancelled_snack'),
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('doctor_appointments_update_error'),
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorIds = _doctorIdsForQueries();
    final s = S.of(context);

    final body = doctorIds.isEmpty
        ? Center(
            child: Text(
              s.translate('login_required'),
              style: const TextStyle(color: Color(0xFF829AB1), fontFamily: 'KurdishFont'),
            ),
          )
        : StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _watchDoctorAppointmentsAnyAlias(doctorIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                );
              }
              if (snapshot.hasError) {
                final err = '${snapshot.error}';
                final indexHints =
                    '\n\n$kAppointmentsDoctorDateStatusIndexHint\n'
                    '$kAppointmentsDoctorIdDateStringIndexHint';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.translate('doctors_load_error_detail', params: {'error': '$err$indexHints'}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data ?? [];
              final sorted = AppointmentsScreen._sortNewestFirst(docs);

              if (sorted.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Divider(height: 1, thickness: 1, color: Colors.white10),
                ),
                itemBuilder: (context, index) {
                  final doc = sorted[index];
                  final data = doc.data();
                  final patientName =
                      (data[AppointmentFields.patientName] ?? '—').toString();
                  final status = AppointmentsScreen._statusKey(data[AppointmentFields.status]);
                  final dateTimeLine = AppointmentsScreen._formatDateTime(data);
                  final patientId =
                      (data[AppointmentFields.patientId] ?? '').toString().trim();

                  Widget cardForProfile(Map<String, dynamic>? profile, {required bool patientLoading}) {
                    return _AppointmentCard(
                      patientName: patientName,
                      dateTimeLine: dateTimeLine,
                      status: status,
                      showActions: status == 'pending',
                      phoneForCall: patientPhoneFromUserData(profile),
                      ageLine: AppointmentsScreen._ageGenderPhoneSummary(context, profile, patientLoading),
                      onCardTap: () => AppointmentsScreen._showPatientDetail(
                        context,
                        patientProfile: profile,
                        fallbackPatientName: patientName,
                        dateTimeLine: dateTimeLine,
                        status: status,
                      ),
                      onCallTap: patientPhoneFromUserData(profile).isNotEmpty
                          ? () => AppointmentsScreen._launchTel(context, patientPhoneFromUserData(profile))
                          : null,
                      onComplete: () => _setStatus(context, doc.id, 'completed'),
                      onCancel: () => _setStatus(context, doc.id, 'cancelled'),
                    );
                  }

                  if (patientId.isEmpty) {
                    return cardForProfile(null, patientLoading: false);
                  }

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('users').doc(patientId).snapshots(),
                    builder: (context, patientSnap) {
                      final loading =
                          patientSnap.connectionState == ConnectionState.waiting && !patientSnap.hasData;
                      final profile = patientSnap.data?.data();
                      return cardForProfile(profile, patientLoading: loading);
                    },
                  );
                },
              );
            },
          );

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: widget.embedded
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: s.translate('tooltip_back'),
                ),
                title: Text(
                  s.translate('doctor_title_appointments_list'),
                  style: const TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: const Color(0xFFD9E2EC),
                elevation: 0,
              ),
        body: body,
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF829AB1).withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'KurdishFont',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFD9E2EC),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'KurdishFont',
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.patientName,
    required this.dateTimeLine,
    required this.status,
    required this.showActions,
    required this.phoneForCall,
    required this.ageLine,
    required this.onCardTap,
    required this.onCallTap,
    required this.onComplete,
    required this.onCancel,
  });

  final String patientName;
  final String dateTimeLine;
  final String status;
  final bool showActions;
  final String phoneForCall;
  final Widget ageLine;
  final VoidCallback onCardTap;
  final VoidCallback? onCallTap;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  Color get _badgeColor {
    switch (status) {
      case 'completed':
        return const Color(0xFF28C76F);
      case 'cancelled':
        return const Color(0xFFFF4D6D);
      case 'pending':
      default:
        return const Color(0xFFE6B800);
    }
  }

  String _badgeLabel(BuildContext context) {
    final s = S.of(context);
    switch (status) {
      case 'completed':
        return s.translate('doctor_appt_status_completed');
      case 'cancelled':
        return s.translate('doctor_appt_status_cancelled');
      case 'pending':
      default:
        return s.translate('doctor_appt_status_pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final showPhoneIcon = onCallTap != null && phoneForCall.isNotEmpty;

    return Material(
      color: const Color(0xFF1D1E33),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white10, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onCardTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: AppLocaleScope.of(context).textDirection,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.translate('doctor_appt_patient_name_label'),
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: const Color(0xFF829AB1).withValues(alpha: 0.95),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                patientName,
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: Color(0xFFD9E2EC),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'KurdishFont',
                                ),
                              ),
                            ),
                            if (showPhoneIcon) ...[
                              const SizedBox(width: 4),
                              Material(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: onCallTap,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.phone_rounded,
                                      size: 18,
                                      color: Color(0xFF42A5F5),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        ageLine,
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _badgeColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _badgeColor.withValues(alpha: 0.55)),
                    ),
                    child: Text(
                      _badgeLabel(context),
                      style: TextStyle(
                        color: _badgeColor,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'KurdishFont',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.translate('doctor_appt_datetime_label'),
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: const Color(0xFF829AB1).withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'KurdishFont',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateTimeLine,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  color: Color(0xFFD9E2EC),
                  fontSize: 14,
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showActions) ...[
                const SizedBox(height: 10),
                Row(
                  textDirection: AppLocaleScope.of(context).textDirection,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF4D6D),
                          side: const BorderSide(color: Color(0xFFFF4D6D)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          s.translate('doctor_appt_action_decline'),
                          style: const TextStyle(
                            fontFamily: 'KurdishFont',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28C76F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: const Size(0, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          s.translate('doctor_appt_action_complete'),
                          style: const TextStyle(
                            fontFamily: 'KurdishFont',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
