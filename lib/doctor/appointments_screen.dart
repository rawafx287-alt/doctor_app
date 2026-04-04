import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/appointment_queries.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../models/patient_profile_read.dart';
import '../auth/firestore_user_doc_id.dart';
import '../theme/staff_premium_theme.dart';
import 'doctor_premium_shell.dart';

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

  static DateTime? _appointmentDayOnly(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) {
      final d = date.toDate();
      return DateTime(d.year, d.month, d.day);
    }
    if (date is DateTime) {
      return DateTime(date.year, date.month, date.day);
    }
    var s = staffDigitsToEnglishAscii(date.toString().trim());
    if (s.isEmpty) return null;
    final ymd = RegExp(r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})');
    final m = ymd.firstMatch(s);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    try {
      final d = DateTime.parse(s);
      return DateTime(d.year, d.month, d.day);
    } catch (_) {
      return null;
    }
  }

  static String _formatDateTime(Map<String, dynamic> data) {
    final date = data[AppointmentFields.date];
    final timeRaw = (data[AppointmentFields.time] ?? '—').toString();
    final timeEn = staffDigitsToEnglishAscii(timeRaw);
    final day = _appointmentDayOnly(date);
    String datePart = '—';
    if (day != null) {
      datePart = DateFormat('yyyy/MM/dd', 'en_US').format(day);
    } else if (date != null) {
      final raw = staffDigitsToEnglishAscii(date.toString().trim());
      if (raw.isNotEmpty) datePart = raw;
    }
    return '$datePart  •  $timeEn';
  }

  static String _localizedGender(BuildContext context, String raw) {
    if (raw.isEmpty)
      return S.of(context).translate('doctor_appt_not_available');
    final n = raw.toLowerCase().trim();
    final s = S.of(context);
    const maleHints = {'male', 'm', 'man', 'ذكر', 'رجل', 'نێر'};
    const femaleHints = {'female', 'f', 'woman', 'أنثى', 'انثى', 'مێ'};
    if (maleHints.contains(n)) return s.translate('doctor_appt_gender_male');
    if (femaleHints.contains(n))
      return s.translate('doctor_appt_gender_female');
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
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
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
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
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
    final name = (patientProfile?['fullName'] ?? fallbackPatientName)
        .toString()
        .trim();
    final displayName = name.isEmpty ? fallbackPatientName : name;
    final age = patientAgeYearsFromUserData(patientProfile);
    final ageStr = age != null
        ? '$age'
        : s.translate('doctor_appt_not_available');
    final genderRaw = patientGenderRawFromUserData(patientProfile);
    final genderStr = _localizedGender(context, genderRaw);
    final phone = patientPhoneFromUserData(patientProfile);
    final phoneStr = phone.isNotEmpty
        ? phone
        : s.translate('doctor_appt_not_available');
    final email = patientEmailFromUserData(patientProfile);
    final emailStr = email.isNotEmpty
        ? email
        : s.translate('doctor_appt_not_available');
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
        case 'confirmed':
          return s.translate('status_confirmed');
        case 'arrived':
          return s.translate('status_arrived');
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              s.translate('doctor_appt_patient_profile_title'),
              style: const TextStyle(
                fontFamily: kPatientPrimaryFont,
                color: Color(0xFFD9E2EC),
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailLine(
                    label: s.translate('doctor_appt_patient_name_label'),
                    value: displayName,
                  ),
                  _DetailLine(
                    label: s.translate('doctor_appt_label_age'),
                    value: ageStr,
                  ),
                  _DetailLine(
                    label: s.translate('doctor_appt_label_gender'),
                    value: genderStr,
                  ),
                  _DetailLine(
                    label: s.translate('doctor_appt_label_phone'),
                    value: phoneStr,
                  ),
                  _DetailLine(
                    label: s.translate('doctor_appt_label_email'),
                    value: emailStr,
                  ),
                  _DetailLine(
                    label: s.translate('doctor_appt_datetime_label'),
                    value: dateTimeLine,
                  ),
                  _DetailLine(
                    label: s.translate('doctor_appt_label_appointment_status'),
                    value: statusLabel(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.translate('doctor_appt_medical_history_section'),
                    style: TextStyle(
                      color: const Color(0xFF829AB1).withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: kPatientPrimaryFont,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    historyBody,
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontSize: 14,
                      height: 1.4,
                      fontFamily: kPatientPrimaryFont,
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
                    fontFamily: kPatientPrimaryFont,
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
                color: const Color(0xFFB0C5C0).withValues(alpha: 0.95),
                fontSize: 11,
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w600,
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
      color: Color(0xFFB8C9C4),
      fontSize: 11,
      height: 1.2,
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w600,
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
      final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
        streams.length,
        null,
      );
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
          streams[i].listen((event) {
            latest[i] = event;
            emitMerged();
          }, onError: controller.addError),
        );
      }
      controller.onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    });
  }

  int _timeSortMinutesAppt(dynamic timeVal) {
    final raw = staffDigitsToEnglishAscii((timeVal ?? '').toString().trim());
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (m != null) {
      return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    }
    return 1 << 20;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _appointmentsForToday(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
    DateTime now,
  ) {
    final day = DateTime(now.year, now.month, now.day);
    return all.where((d) {
      final ad = AppointmentsScreen._appointmentDayOnly(
        d.data()[AppointmentFields.date],
      );
      return ad != null &&
          ad.year == day.year &&
          ad.month == day.month &&
          ad.day == day.day;
    }).toList();
  }

  void _sortTodayByTime(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
  ) {
    list.sort(
      (a, b) => _timeSortMinutesAppt(
        a.data()[AppointmentFields.time],
      ).compareTo(_timeSortMinutesAppt(b.data()[AppointmentFields.time])),
    );
  }

  int _currentTimelineIndex(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
  ) {
    for (var i = 0; i < list.length; i++) {
      final st = AppointmentsScreen._statusKey(
        list[i].data()[AppointmentFields.status],
      );
      if (st != 'completed' && st != 'cancelled' && st != 'canceled') {
        return i;
      }
    }
    return -1;
  }

  String _doctorUserIdForEmbedded(Set<String> doctorIds) {
    final w = widget.doctorUserId?.trim() ?? '';
    if (w.isNotEmpty) return w;
    if (doctorIds.isEmpty) return '';
    return doctorIds.first;
  }

  Future<void> _setStatus(
    BuildContext context,
    String docId,
    String status,
  ) async {
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
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
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
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
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
              style: const TextStyle(
                color: Color(0xFF829AB1),
                fontFamily: kPatientPrimaryFont,
              ),
            ),
          )
        : StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _watchDoctorAppointmentsAnyAlias(doctorIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                if (widget.embedded) {
                  return const _EmbeddedAppointmentsLoading();
                }
                return const Center(
                  child: CircularProgressIndicator(color: kStaffLuxGold),
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
                      s.translate(
                        'doctors_load_error_detail',
                        params: {'error': '$err$indexHints'},
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFAB91),
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data ?? [];

              if (widget.embedded) {
                final today = _appointmentsForToday(docs, DateTime.now());
                _sortTodayByTime(today);
                final cur = _currentTimelineIndex(today);
                final uid = _doctorUserIdForEmbedded(doctorIds);
                return _DoctorTodayDashboard(
                  doctorUserId: uid,
                  todayDocs: today,
                  currentIndex: cur,
                  onSetStatus: _setStatus,
                );
              }

              final sorted = AppointmentsScreen._sortNewestFirst(docs);

              if (sorted.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.translate('doctor_appointments_empty'),
                      textAlign: TextAlign.center,
                      style: staffLabelTextStyle(
                        fontSize: 15,
                      ).copyWith(color: kStaffMutedText),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white10,
                  ),
                ),
                itemBuilder: (context, index) {
                  final doc = sorted[index];
                  final data = doc.data();
                  final patientName =
                      (data[AppointmentFields.patientName] ?? '—').toString();
                  final status = AppointmentsScreen._statusKey(
                    data[AppointmentFields.status],
                  );
                  final dateTimeLine = AppointmentsScreen._formatDateTime(data);
                  final patientId = (data[AppointmentFields.patientId] ?? '')
                      .toString()
                      .trim();

                  Widget cardForProfile(
                    Map<String, dynamic>? profile, {
                    required bool patientLoading,
                  }) {
                    return _AppointmentCard(
                      patientName: patientName,
                      dateTimeLine: dateTimeLine,
                      status: status,
                      showActions: status == 'pending',
                      phoneForCall: patientPhoneFromUserData(profile),
                      ageLine: AppointmentsScreen._ageGenderPhoneSummary(
                        context,
                        profile,
                        patientLoading,
                      ),
                      onCardTap: () => AppointmentsScreen._showPatientDetail(
                        context,
                        patientProfile: profile,
                        fallbackPatientName: patientName,
                        dateTimeLine: dateTimeLine,
                        status: status,
                      ),
                      onCallTap: patientPhoneFromUserData(profile).isNotEmpty
                          ? () => AppointmentsScreen._launchTel(
                              context,
                              patientPhoneFromUserData(profile),
                            )
                          : null,
                      onComplete: () =>
                          _setStatus(context, doc.id, 'completed'),
                      onCancel: () => _setStatus(context, doc.id, 'cancelled'),
                    );
                  }

                  if (patientId.isEmpty) {
                    return cardForProfile(null, patientLoading: false);
                  }

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(patientId)
                        .snapshots(),
                    builder: (context, patientSnap) {
                      final loading =
                          patientSnap.connectionState ==
                              ConnectionState.waiting &&
                          !patientSnap.hasData;
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
        backgroundColor: widget.embedded
            ? Colors.transparent
            : kDoctorPremiumGradientBottom,
        extendBodyBehindAppBar: !widget.embedded,
        appBar: widget.embedded
            ? null
            : doctorPremiumAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: s.translate('tooltip_back'),
                ),
                title: Text(
                  s.translate('doctor_title_appointments_list'),
                  style: const TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 17,
                  ),
                ),
              ),
        body: widget.embedded
            ? body
            : Stack(
                fit: StackFit.expand,
                children: [
                  const DoctorPremiumBackground(),
                  Positioned.fill(child: body),
                ],
              ),
      ),
    );
  }
}

String _doctorDashPhotoUrl(Map<String, dynamic>? d) {
  if (d == null) return '';
  for (final k in ['photoURL', 'photoUrl', 'imageUrl', 'profileImageUrl']) {
    final t = (d[k] ?? '').toString().trim();
    if (t.isNotEmpty) return t;
  }
  return '';
}

class _EmbeddedAppointmentsLoading extends StatelessWidget {
  const _EmbeddedAppointmentsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: kStaffLuxGold));
  }
}

class _GlassStatCard extends StatelessWidget {
  const _GlassStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: kStaffSilverBorder,
                width: kStaffCardOutlineWidth,
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFFF5FBF8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineGlassCard extends StatelessWidget {
  const _TimelineGlassCard({
    required this.datePartEn,
    required this.timePartEn,
    required this.isCurrent,
    required this.patientName,
    required this.status,
    required this.showActions,
    required this.phoneForCall,
    required this.ageLine,
    required this.onDetail,
    required this.onCall,
    required this.onComplete,
    required this.onCancel,
  });

  final String datePartEn;
  final String timePartEn;
  final bool isCurrent;
  final String patientName;
  final String status;
  final bool showActions;
  final String phoneForCall;
  final Widget ageLine;
  final VoidCallback onDetail;
  final VoidCallback? onCall;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final badge = staffAppointmentStatusBadgeStyle(status);
    final showPhone = onCall != null && phoneForCall.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: isCurrent ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent
                      ? kStaffLuxGold.withValues(alpha: 0.48)
                      : kStaffSilverBorder,
                  width: kStaffCardOutlineWidth,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: kStaffLuxGold.withValues(alpha: 0.38),
                          blurRadius: 20,
                          spreadRadius: -2,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: isCurrent ? kStaffGoldActionGradient : null,
                        color: isCurrent ? null : kStaffAccentSlateBlue,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(15),
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: kStaffLuxGold.withValues(alpha: 0.7),
                                  blurRadius: 10,
                                  spreadRadius: -1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 108,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 15,
                                            color: kStaffLuxGold,
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Directionality(
                                              textDirection:
                                                  ui.TextDirection.ltr,
                                              child: Text(
                                                datePartEn.isNotEmpty
                                                    ? datePartEn
                                                    : '—',
                                                style: const TextStyle(
                                                  fontFamily:
                                                      kPatientPrimaryFont,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: Color(0xFFE8F4F0),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time_rounded,
                                            size: 15,
                                            color: kStaffLuxGold,
                                          ),
                                          const SizedBox(width: 5),
                                          Directionality(
                                            textDirection: ui.TextDirection.ltr,
                                            child: Text(
                                              timePartEn.isNotEmpty
                                                  ? timePartEn
                                                  : '—',
                                              style: const TextStyle(
                                                fontFamily: kPatientPrimaryFont,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                color: Color(0xFFF5FBF8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        patientName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Color(0xFFF8FFFC),
                                        ),
                                      ),
                                      ageLine,
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: badge.decoration,
                                  child: Text(
                                    _timelineBadgeLabel(context, status),
                                    style: TextStyle(
                                      color: badge.foreground,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: kPatientPrimaryFont,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  tooltip: s.translate(
                                    'doctor_appt_patient_profile_title',
                                  ),
                                  onPressed: onDetail,
                                  icon: const Icon(
                                    Icons.medical_services_rounded,
                                    color: kStaffLuxGold,
                                    size: 22,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  tooltip: s.translate(
                                    'doctor_appt_medical_history_section',
                                  ),
                                  onPressed: onDetail,
                                  icon: const Icon(
                                    Icons.medication_liquid_rounded,
                                    color: kStaffLuxGold,
                                    size: 22,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  tooltip: s.translate(
                                    'doctor_appt_medical_history_section',
                                  ),
                                  onPressed: onDetail,
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    color: kStaffLuxGold,
                                    size: 22,
                                  ),
                                ),
                                if (showPhone) ...[
                                  const Spacer(),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    onPressed: onCall,
                                    icon: const Icon(
                                      Icons.phone_rounded,
                                      color: kStaffLuxGold,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (showActions) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: onCancel,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFFF8A95,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFFF8A95),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        s.translate(
                                          'doctor_appt_action_decline',
                                        ),
                                        style: const TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: StaffGoldGradientButton(
                                      label: s.translate(
                                        'doctor_appt_action_complete',
                                      ),
                                      onPressed: onComplete,
                                      fontSize: 12,
                                      borderRadius: 10,
                                      minHeight: 36,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 8,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timelineBadgeLabel(BuildContext context, String st) {
    final s = S.of(context);
    switch (st) {
      case 'completed':
        return s.translate('doctor_appt_status_completed');
      case 'cancelled':
        return s.translate('doctor_appt_status_cancelled');
      case 'confirmed':
        return s.translate('status_confirmed');
      case 'arrived':
        return s.translate('status_arrived');
      case 'pending':
      default:
        return s.translate('doctor_appt_status_pending');
    }
  }
}

class _DoctorTodayDashboard extends StatelessWidget {
  const _DoctorTodayDashboard({
    required this.doctorUserId,
    required this.todayDocs,
    required this.currentIndex,
    required this.onSetStatus,
  });

  final String doctorUserId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> todayDocs;
  final int currentIndex;
  final Future<void> Function(BuildContext context, String docId, String status)
  onSetStatus;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    final nf = NumberFormat.decimalPattern('en_US');
    final now = DateTime.now();

    if (doctorUserId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            s.translate('login_required'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    final total = todayDocs.length;
    final completed = todayDocs
        .where(
          (d) =>
              AppointmentsScreen._statusKey(
                d.data()[AppointmentFields.status],
              ) ==
              'completed',
        )
        .length;
    final remaining = todayDocs.where((d) {
      final st = AppointmentsScreen._statusKey(
        d.data()[AppointmentFields.status],
      );
      return st != 'completed' && st != 'cancelled' && st != 'canceled';
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(doctorUserId)
                .snapshots(),
            builder: (context, docSnap) {
              final data = docSnap.data?.data();
              final name = data != null
                  ? localizedDoctorFullName(data, lang)
                  : '—';
              final photo = _doctorDashPhotoUrl(data);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: kStaffGoldActionGradient,
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: kDoctorPremiumGradientTop,
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                      child: photo.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: kStaffLuxGold,
                              size: 34,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 21,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Directionality(
                          textDirection: ui.TextDirection.ltr,
                          child: Text(
                            '\u200E${nf.format(now.year)} / ${nf.format(now.month)} / ${nf.format(now.day)}',
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: kStaffLuxGold.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              s.translate('doctor_today_stats_heading'),
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              _GlassStatCard(
                label: s.translate('doctor_today_stat_total'),
                value: nf.format(total),
              ),
              const SizedBox(width: 8),
              _GlassStatCard(
                label: s.translate('doctor_today_stat_remaining'),
                value: nf.format(remaining),
              ),
              const SizedBox(width: 8),
              _GlassStatCard(
                label: s.translate('doctor_today_stat_completed'),
                value: nf.format(completed),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              s.translate('doctor_today_timeline'),
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: kStaffLuxGold.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
        Expanded(
          child: todayDocs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.translate('doctor_appointments_empty_today'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: todayDocs.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = todayDocs[index];
                    final data = doc.data();
                    final patientName =
                        (data[AppointmentFields.patientName] ?? '—').toString();
                    final status = AppointmentsScreen._statusKey(
                      data[AppointmentFields.status],
                    );
                    final dateTimeLine = AppointmentsScreen._formatDateTime(
                      data,
                    );
                    final patientId = (data[AppointmentFields.patientId] ?? '')
                        .toString()
                        .trim();
                    final isCurrent = index == currentIndex;
                    final timeRaw = staffDigitsToEnglishAscii(
                      (data[AppointmentFields.time] ?? '').toString().trim(),
                    );
                    final timeFallback = timeRaw.isNotEmpty ? timeRaw : '—';
                    final dtParts = dateTimeLine.split(RegExp(r'\s+•\s+'));
                    final datePartEn = dtParts.isNotEmpty
                        ? dtParts[0].trim()
                        : '';
                    final timePartEn = dtParts.length > 1
                        ? dtParts[1].trim()
                        : timeFallback;

                    void openDetail(Map<String, dynamic>? profile) {
                      AppointmentsScreen._showPatientDetail(
                        context,
                        patientProfile: profile,
                        fallbackPatientName: patientName,
                        dateTimeLine: dateTimeLine,
                        status: status,
                      );
                    }

                    if (patientId.isEmpty) {
                      return _TimelineGlassCard(
                        datePartEn: datePartEn,
                        timePartEn: timePartEn,
                        isCurrent: isCurrent,
                        patientName: patientName,
                        status: status,
                        showActions: status == 'pending',
                        phoneForCall: '',
                        ageLine: AppointmentsScreen._ageGenderPhoneSummary(
                          context,
                          null,
                          false,
                        ),
                        onDetail: () => openDetail(null),
                        onCall: null,
                        onComplete: () =>
                            onSetStatus(context, doc.id, 'completed'),
                        onCancel: () =>
                            onSetStatus(context, doc.id, 'cancelled'),
                      );
                    }

                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(patientId)
                          .snapshots(),
                      builder: (context, patientSnap) {
                        final loading =
                            patientSnap.connectionState ==
                                ConnectionState.waiting &&
                            !patientSnap.hasData;
                        final profile = patientSnap.data?.data();
                        final phone = patientPhoneFromUserData(profile);
                        return _TimelineGlassCard(
                          datePartEn: datePartEn,
                          timePartEn: timePartEn,
                          isCurrent: isCurrent,
                          patientName: patientName,
                          status: status,
                          showActions: status == 'pending',
                          phoneForCall: phone,
                          ageLine: AppointmentsScreen._ageGenderPhoneSummary(
                            context,
                            profile,
                            loading,
                          ),
                          onDetail: () => openDetail(profile),
                          onCall: phone.isNotEmpty
                              ? () => AppointmentsScreen._launchTel(
                                  context,
                                  phone,
                                )
                              : null,
                          onComplete: () =>
                              onSetStatus(context, doc.id, 'completed'),
                          onCancel: () =>
                              onSetStatus(context, doc.id, 'cancelled'),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
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
          Text(label, style: staffLabelTextStyle(fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: staffHeaderTextStyle(fontSize: 15)),
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

  String _badgeLabel(BuildContext context) {
    final s = S.of(context);
    switch (status) {
      case 'completed':
        return s.translate('doctor_appt_status_completed');
      case 'cancelled':
        return s.translate('doctor_appt_status_cancelled');
      case 'confirmed':
        return s.translate('status_confirmed');
      case 'arrived':
        return s.translate('status_arrived');
      case 'pending':
      default:
        return s.translate('doctor_appt_status_pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final showPhoneIcon = onCallTap != null && phoneForCall.isNotEmpty;
    final badge = staffAppointmentStatusBadgeStyle(status);
    final parts = dateTimeLine.split(RegExp(r'\s+•\s+'));
    final datePart = parts.isNotEmpty ? parts[0] : dateTimeLine;
    final timePart = parts.length > 1 ? parts[1] : '';
    final stripGold = AppointmentsScreen._statusKey(status) == 'pending';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: stripGold ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: stripGold
                      ? kStaffLuxGold.withValues(alpha: 0.45)
                      : kStaffSilverBorder,
                  width: kStaffCardOutlineWidth,
                ),
                boxShadow: stripGold
                    ? [
                        BoxShadow(
                          color: kStaffLuxGold.withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: stripGold ? kStaffGoldActionGradient : null,
                        color: stripGold ? null : kStaffAccentSlateBlue,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(15),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              textDirection: AppLocaleScope.of(
                                context,
                              ).textDirection,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.translate(
                                          'doctor_appt_patient_name_label',
                                        ),
                                        style: TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              patientName,
                                              style: const TextStyle(
                                                fontFamily: kPatientPrimaryFont,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (showPhoneIcon) ...[
                                            const SizedBox(width: 4),
                                            Material(
                                              color: kStaffLuxGold.withValues(
                                                alpha: 0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: InkWell(
                                                onTap: onCallTap,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(6),
                                                  child: Icon(
                                                    Icons.phone_rounded,
                                                    size: 18,
                                                    color: kStaffLuxGold,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: badge.decoration,
                                  child: Text(
                                    _badgeLabel(context),
                                    style: TextStyle(
                                      color: badge.foreground,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: kPatientPrimaryFont,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Divider(
                              height: 22,
                              thickness: 0.8,
                              color: kStaffLuxGold.withValues(alpha: 0.35),
                            ),
                            Text(
                              s.translate('doctor_appt_datetime_label'),
                              style: TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: kStaffLuxGold,
                                ),
                                const SizedBox(width: 6),
                                Directionality(
                                  textDirection: ui.TextDirection.ltr,
                                  child: Text(
                                    datePart,
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFFE8F4F0),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    '·',
                                    style: TextStyle(
                                      color: kStaffLuxGold.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: kStaffLuxGold,
                                ),
                                const SizedBox(width: 6),
                                if (timePart.isNotEmpty)
                                  Directionality(
                                    textDirection: ui.TextDirection.ltr,
                                    child: Text(
                                      timePart,
                                      style: const TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: Color(0xFFF5FBF8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (showActions) ...[
                              Divider(
                                height: 22,
                                thickness: 0.8,
                                color: kStaffLuxGold.withValues(alpha: 0.35),
                              ),
                              Row(
                                textDirection: AppLocaleScope.of(
                                  context,
                                ).textDirection,
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: onCancel,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFFF8A95,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFFF8A95),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(0, 40),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        s.translate(
                                          'doctor_appt_action_decline',
                                        ),
                                        style: const TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: StaffGoldGradientButton(
                                      label: s.translate(
                                        'doctor_appt_action_complete',
                                      ),
                                      onPressed: onComplete,
                                      fontSize: 13,
                                      borderRadius: 10,
                                      minHeight: 40,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
