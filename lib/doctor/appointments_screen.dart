import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/available_days_queries.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/appointment_booking_details.dart';
import '../models/patient_profile_read.dart';
import '../auth/firestore_user_doc_id.dart';
import '../theme/staff_premium_theme.dart';
import '../widgets/appointment_action_confirm_dialog.dart';
import '../patient/create_patient_appointment.dart';
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

  static String _localizedGenderLabel(BuildContext context, String raw) {
    if (raw.isEmpty) {
      return S.of(context).translate('doctor_appt_not_available');
    }
    final n = raw.toLowerCase().trim();
    final s = S.of(context);
    const maleHints = {'male', 'm', 'man', 'ذكر', 'رجل', 'نێر'};
    const femaleHints = {'female', 'f', 'woman', 'أنثى', 'انثى', 'مێ'};
    if (maleHints.contains(n)) return s.translate('doctor_appt_gender_male');
    if (femaleHints.contains(n)) return s.translate('doctor_appt_gender_female');
    return raw;
  }

  /// Local appointment date + [AppointmentFields.time] for detail sheet / labels.
  static DateTime slotStartFromAppointmentDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    var day = DateTime.now();
    final d = data[AppointmentFields.date];
    if (d is Timestamp) {
      final x = d.toDate();
      day = DateTime(x.year, x.month, x.day);
    }
    final hhmm = normalizeAppointmentTimeToHhMm(data[AppointmentFields.time]);
    if (hhmm.isEmpty) {
      return DateTime(day.year, day.month, day.day);
    }
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final mi = int.tryParse(parts[1]) ?? 0;
    return DateTime(day.year, day.month, day.day, h, mi);
  }

  /// Glass-style patient detail sheet for the doctor embedded slot list.
  static Future<void> showDoctorPatientDetailBottomSheet(
    BuildContext context, {
    required QueryDocumentSnapshot<Map<String, dynamic>> appointmentDoc,
    required DateTime slotStart,
    required Map<String, int> queueByDocId,
    required Future<void> Function(BuildContext, String, String) onSetStatus,
    required bool showActionButtons,
  }) async {
    final apptData = appointmentDoc.data();
    final patientName =
        (apptData[AppointmentFields.patientName] ?? '—').toString();
    final patientId =
        (apptData[AppointmentFields.patientId] ?? '').toString().trim();
    final queueEn =
        formatDailyQueueTicketEnglish(appointmentDoc, queueByDocId);
    final queueLabel = queueEn == '—' ? '—' : '#$queueEn';
    final timeEn = DateFormat.jm('en_US').format(slotStart);
    final nf = NumberFormat.decimalPattern('en_US');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (sheetContext) {
        const deepBlue = Color(0xFF0A1628);
        const vibrantGreen = Color(0xFF22C55E);
        const softRed = Color(0xFFFB7185);

        Widget buildBody(Map<String, dynamic>? profile, bool patientLoading) {
          final s = S.of(sheetContext);
          final notRec = s.translate('booking_detail_not_recorded');
          final rawPhone = appointmentBookingPhoneRaw(apptData, profile);
          final phoneDigits =
              rawPhone.trim().isEmpty ? '' : staffDigitsToEnglishAscii(rawPhone);
          final ageYears = appointmentBookingAgeYears(apptData, profile);
          final ageText =
              ageYears == null ? notRec : nf.format(ageYears);
          final genderRaw =
              appointmentBookingGenderRaw(apptData, profile);
          final genderLabel = genderRaw.isEmpty
              ? notRec
              : _localizedGenderLabel(sheetContext, genderRaw);
          final bloodRaw = appointmentBloodGroupRaw(apptData);
          final bloodText = bloodRaw.isEmpty ? notRec : bloodRaw;
          final residentRaw = appointmentResidentPlaceRaw(apptData);
          final residentDisplay =
              residentRaw.isEmpty ? notRec : residentRaw;
          final bookingMn = appointmentBookingMedicalNotesRaw(apptData);
          final profileMn = patientLoading
              ? ''
              : patientMedicalHistoryFromUserData(profile);

          Widget detailCell({
            required String label,
            required Widget value,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                ),
                const SizedBox(height: 4),
                DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.25,
                    color: Colors.white.withValues(alpha: 0.94),
                  ),
                  child: value,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                patientName,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  height: 1.15,
                  color: kStaffLuxGold.withValues(alpha: 0.98),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${s.translate('secretary_ticket_number')} $queueLabel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: kStaffLuxGold.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 22),
              if (patientLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: kStaffLuxGold.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          detailCell(
                            label: s.translate('doctor_appt_label_phone'),
                            value: phoneDigits.isEmpty
                                ? Text(notRec)
                                : InkWell(
                                    onTap: () => AppointmentsScreen._launchTel(
                                      sheetContext,
                                      rawPhone,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.phone_in_talk_rounded,
                                            size: 18,
                                            color: kStaffLuxGold.withValues(
                                              alpha: 0.92,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Directionality(
                                              textDirection: ui.TextDirection.ltr,
                                              child: Text(phoneDigits),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          detailCell(
                            label: s.translate('doctor_appt_label_gender'),
                            value: Text(genderLabel),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          detailCell(
                            label: s.translate('doctor_appt_label_age'),
                            value: Directionality(
                              textDirection: ui.TextDirection.ltr,
                              child: Text(ageText),
                            ),
                          ),
                          const SizedBox(height: 16),
                          detailCell(
                            label: s.translate('ticket_time'),
                            value: Directionality(
                              textDirection: ui.TextDirection.ltr,
                              child: Text(timeEn),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              detailCell(
                label: s.translate('doctor_appt_label_blood'),
                value: Text(bloodText),
              ),
              const SizedBox(height: 16),
              detailCell(
                label: s.translate('doctor_appt_label_resident_place'),
                value: Text(residentDisplay),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: kStaffLuxGold.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kStaffLuxGold.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.translate('booking_form_medical_notes'),
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: kStaffLuxGold.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bookingMn.isEmpty
                          ? s.translate('doctor_appt_no_booking_notes')
                          : bookingMn,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.white.withValues(
                          alpha: bookingMn.isEmpty ? 0.55 : 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (profileMn.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: kStaffLuxGold.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.translate('doctor_appt_medical_history_section'),
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: kStaffLuxGold.withValues(alpha: 0.88),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profileMn,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (showActionButtons) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: vibrantGreen,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await onSetStatus(
                              context,
                              appointmentDoc.id,
                              'completed',
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              s.translate('doctor_appt_action_complete'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: softRed,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await onSetStatus(
                              context,
                              appointmentDoc.id,
                              'cancelled',
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              s.translate('doctor_appt_action_decline'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        }

        final media = MediaQuery.of(sheetContext);
        final maxH = media.size.height * 0.92;

        Widget sheetContent(Map<String, dynamic>? profile, bool loading) {
          return Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: deepBlue.withValues(alpha: 0.82),
                      border: Border.all(
                        color: kStaffLuxGold.withValues(alpha: 0.28),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: buildBody(profile, loading),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (patientId.isEmpty) {
          return sheetContent(null, false);
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .snapshots(),
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting &&
                !snap.hasData;
            final profile = snap.data?.data();
            return sheetContent(profile, loading);
          },
        );
      },
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

  String _doctorUserIdForEmbedded(Set<String> doctorIds) {
    final w = widget.doctorUserId?.trim() ?? '';
    if (w.isNotEmpty) return w;
    if (doctorIds.isEmpty) return '';
    return doctorIds.first;
  }

  Future<void> _confirmSetStatus(
    BuildContext context,
    String docId,
    String status,
  ) async {
    final st = status.trim().toLowerCase();
    if (st == 'completed' ||
        st == 'cancelled' ||
        st == 'canceled') {
      final ok = await showAppointmentActionConfirmDialog(
        context,
        isCompleteAction: st == 'completed',
      );
      if (ok != true || !context.mounted) return;
    }
    await _setStatus(context, docId, status);
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
                final uid = _doctorUserIdForEmbedded(doctorIds);
                return _DoctorTodayDashboard(
                  doctorUserId: uid,
                  onSetStatus: _confirmSetStatus,
                );
              }

              final sorted =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
              sortStaffAppointmentsInPlace(sorted);
              final queueById = dailyQueueNumberByDocId(sorted);

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
                  final patientId = (data[AppointmentFields.patientId] ?? '')
                      .toString()
                      .trim();

                  Widget cardForProfile(
                    Map<String, dynamic>? profile, {
                    required bool patientLoading,
                  }) {
                    return _AppointmentCard(
                      patientName: patientName,
                      queueEn: formatDailyQueueTicketEnglish(doc, queueById),
                      status: status,
                      showActions: status == 'pending',
                      onCardTap: () =>
                          AppointmentsScreen.showDoctorPatientDetailBottomSheet(
                        context,
                        appointmentDoc: doc,
                        slotStart:
                            AppointmentsScreen.slotStartFromAppointmentDoc(doc),
                        queueByDocId: queueById,
                        onSetStatus: _confirmSetStatus,
                        showActionButtons: status == 'pending',
                      ),
                      onComplete: () =>
                          _confirmSetStatus(context, doc.id, 'completed'),
                      onCancel: () =>
                          _confirmSetStatus(context, doc.id, 'cancelled'),
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

class _EmbeddedAppointmentsLoading extends StatelessWidget {
  const _EmbeddedAppointmentsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: kStaffLuxGold));
  }
}

/// Maps slot time → appointment doc (first per time). Includes **cancelled** so rejected patients stay visible.
Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
    _appointmentsBySlotHhMmIncludingCancelled(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final m = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final d in docs) {
    final k = normalizeAppointmentTimeToHhMm(d.data()[AppointmentFields.time]);
    if (k.isEmpty) continue;
    m.putIfAbsent(k, () => d);
  }
  return m;
}

int _queueSortValueForSlot(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  Map<String, int> queueByDocId,
) {
  final fromMap = queueByDocId[doc.id];
  if (fromMap != null && fromMap > 0) {
    return fromMap;
  }
  final raw = doc.data()[AppointmentFields.queueNumber];
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.round();
  }
  if (raw != null) {
    final p = int.tryParse(raw.toString().trim());
    if (p != null && p > 0) {
      return p;
    }
  }
  return 1 << 20;
}

/// Booked slots: **active (no green / not completed) first**, then terminal rows.
/// Within each group: ticket / queue number, then slot time (tie-break).
List<DateTime> _sortedBookedSlotsUnified({
  required List<DateTime> visibleSlots,
  required Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byKeyAll,
  required Map<String, int> queueByDocId,
}) {
  final list = List<DateTime>.from(visibleSlots);
  int cmp(DateTime a, DateTime b) {
    final da = byKeyAll[formatTimeHhMm(a)]!;
    final db = byKeyAll[formatTimeHhMm(b)]!;
    final ta = appointmentStatusIsTerminalForStaffSort(
      (da.data()[AppointmentFields.status] ?? 'pending').toString(),
    );
    final tb = appointmentStatusIsTerminalForStaffSort(
      (db.data()[AppointmentFields.status] ?? 'pending').toString(),
    );
    // Same as: !isCompleted before isCompleted
    if (ta != tb) {
      return ta ? 1 : -1;
    }
    final qa = _queueSortValueForSlot(da, queueByDocId);
    final qb = _queueSortValueForSlot(db, queueByDocId);
    if (qa != qb) {
      return qa.compareTo(qb);
    }
    return a.compareTo(b);
  }

  list.sort(cmp);
  return list;
}

bool _slotAppointmentIsTerminal(
  DateTime slot,
  Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byKeyAll,
) {
  final doc = byKeyAll[formatTimeHhMm(slot)];
  if (doc == null) return false;
  return appointmentStatusIsTerminalForStaffSort(
    (doc.data()[AppointmentFields.status] ?? 'pending').toString(),
  );
}

String _unifiedBookedListAnimationKey(
  List<DateTime> ordered,
  Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byKeyAll,
) {
  return ordered
      .map((s) {
        final d = byKeyAll[formatTimeHhMm(s)]!;
        final st = AppointmentsScreen._statusKey(
          d.data()[AppointmentFields.status],
        );
        return '${d.id}:$st';
      })
      .join('|');
}

/// Yields immediately then every 30s so [DateTime.now] rolls over at local midnight.
Stream<DateTime> _doctorDashboardTodayClock() async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(
    const Duration(seconds: 30),
    (_) => 0,
  )) {
    yield DateTime.now();
  }
}

/// Booked slots only (includes rejected when present in [byKeyAll]), filtered by patient name.
/// Order is undefined; use [_sortedBookedSlotsUnified] for stable queue + time order.
List<DateTime> _visibleBookedSlotsForSearch(
  List<DateTime> slots,
  Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byKeyAll,
  String searchQuery,
) {
  final q = searchQuery.trim().toLowerCase();
  final out = <DateTime>[];
  for (final slot in slots) {
    final k = formatTimeHhMm(slot);
    final doc = byKeyAll[k];
    if (doc == null) {
      continue;
    }
    final name =
        (doc.data()[AppointmentFields.patientName] ?? '').toString();
    if (q.isEmpty || name.toLowerCase().contains(q)) {
      out.add(slot);
    }
  }
  return out;
}

Future<void> _openStaffWalkInBooking(
  BuildContext context, {
  required String doctorUserId,
  required DateTime dayLocal,
  required DateTime slotStart,
}) async {
  final s = S.of(context);
  final nameController = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dctx) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          s.translate('master_calendar_add_walkin'),
          style: const TextStyle(
            fontFamily: kPatientPrimaryFont,
            color: Color(0xFFD9E2EC),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(
            color: Color(0xFFD9E2EC),
            fontFamily: kPatientPrimaryFont,
          ),
          decoration: InputDecoration(
            labelText: s.translate('doctor_appt_patient_name_label'),
            labelStyle: const TextStyle(color: Color(0xFF829AB1)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(
              s.translate('action_cancel'),
              style: const TextStyle(
                fontFamily: kPatientPrimaryFont,
                color: Color(0xFF42A5F5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(
              s.translate('confirm_booking'),
              style: const TextStyle(
                fontFamily: kPatientPrimaryFont,
                color: Color(0xFF42A5F5),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
  if (ok != true) {
    nameController.dispose();
    return;
  }
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final slotMinutes = slotStart.hour * 60 + slotStart.minute;
  final err = await createStaffAppointment(
    doctorId: doctorUserId,
    dateLocal: dayLocal,
    slotStartMinutes: slotMinutes,
    patientName: nameController.text,
    createdByUid: uid,
  );
  nameController.dispose();
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.translate(err),
          style: const TextStyle(fontFamily: kPatientPrimaryFont),
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.translate('master_calendar_saved'),
          style: const TextStyle(fontFamily: kPatientPrimaryFont),
        ),
      ),
    );
  }
}

/// Full-height “نۆرەکان بەپێی کات” list driven by day settings + appointments streams.
class _DoctorTodayScheduleSection extends StatelessWidget {
  const _DoctorTodayScheduleSection({
    super.key,
    required this.doctorUserId,
    required this.todayOnly,
    required this.onSetStatus,
    required this.searchQuery,
  });

  final String doctorUserId;
  final DateTime todayOnly;
  final Future<void> Function(BuildContext context, String docId, String status)
  onSetStatus;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final nfCount = NumberFormat.decimalPattern('en_US');
    final dayDocId = availableDayDocumentId(
      doctorUserId: doctorUserId,
      dateLocal: todayOnly,
    );

    Widget slotsHeading({required int bookedCount}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kStaffLuxGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: kStaffLuxGold.withValues(alpha: 0.4),
                width: 0.85,
              ),
            ),
            child: Text(
              s.translate(
                'doctor_today_booked_count_badge',
                params: {'count': nfCount.format(bookedCount)},
              ),
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                color: kStaffLuxGold.withValues(alpha: 0.96),
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AvailableDayFields.collection)
          .doc(dayDocId)
          .snapshots(),
      builder: (context, daySnap) {
        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: watchDoctorAppointmentsForLocalDay(
            doctorUserId: doctorUserId,
            dayLocal: todayOnly,
          ),
          builder: (context, apptSnap) {
            if (apptSnap.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  slotsHeading(bookedCount: 0),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          s.translate('schedule_load_error'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontFamily: kPatientPrimaryFont,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            if (apptSnap.connectionState == ConnectionState.waiting &&
                !apptSnap.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  slotsHeading(bookedCount: 0),
                  const Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: kStaffLuxGold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final dayData = daySnap.data?.data();
            final noHours = dayData == null || !availableDayIsOpen(dayData);
            List<DateTime> slots = const [];
            if (!noHours) {
              final d = dayData;
              final start = normalizeAvailableDayStartTimeHhMm(
                d[AvailableDayFields.startTime],
              );
              final end = normalizeAvailableDayClosingTimeHhMm(
                d[AvailableDayFields.closingTime],
              );
              final dur = normalizeAppointmentDurationMinutes(
                d[AvailableDayFields.appointmentDuration],
              );
              slots = generatedSlotStartsForDay(
                dateOnly: todayOnly,
                startTimeHhMm: start,
                closingTimeHhMm: end,
                durationMinutes: dur,
              );
            }

            final byKeyAll =
                _appointmentsBySlotHhMmIncludingCancelled(apptSnap.data ?? const []);
            final queueById =
                dailyQueueNumberByDocId(apptSnap.data ?? const []);
            final emptyGrid = noHours || slots.isEmpty;
            if (emptyGrid) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  slotsHeading(bookedCount: 0),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Text(
                          s.translate('doctor_today_no_slots_message'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final visibleSlots = _visibleBookedSlotsForSearch(
              slots,
              byKeyAll,
              searchQuery,
            );
            final orderedSlots = _sortedBookedSlotsUnified(
              visibleSlots: visibleSlots,
              byKeyAll: byKeyAll,
              queueByDocId: queueById,
            );
            final hasNonTerminalSlot = orderedSlots.any(
              (s) => !_slotAppointmentIsTerminal(s, byKeyAll),
            );
            final firstTerminalIdx = orderedSlots.indexWhere(
              (s) => _slotAppointmentIsTerminal(s, byKeyAll),
            );
            final completedSectionStartIndex =
                hasNonTerminalSlot && firstTerminalIdx >= 0
                    ? firstTerminalIdx
                    : null;
            final bottomListPadding =
                16 + MediaQuery.paddingOf(context).bottom + 76;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                slotsHeading(bookedCount: visibleSlots.length),
                Expanded(
                  child: visibleSlots.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                            child: searchQuery.trim().isNotEmpty
                                ? Text(
                                    s.translate('doctor_patients_empty'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      height: 1.35,
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(22),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: kStaffLuxGold.withValues(
                                            alpha: 0.1,
                                          ),
                                          border: Border.all(
                                            color: kStaffLuxGold.withValues(
                                              alpha: 0.38,
                                            ),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: kStaffLuxGold.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 24,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.calendar_month_rounded,
                                          size: 52,
                                          color: kStaffLuxGold.withValues(
                                            alpha: 0.95,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        s.translate(
                                          'doctor_today_no_bookings_empty',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          height: 1.45,
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        )
                      : ListView(
                          key: ValueKey<String>(
                            _unifiedBookedListAnimationKey(
                              orderedSlots,
                              byKeyAll,
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            bottomListPadding,
                          ),
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          children: [
                            for (var i = 0; i < orderedSlots.length; i++) ...[
                              if (completedSectionStartIndex != null &&
                                  i == completedSectionStartIndex) ...[
                                if (i > 0) const SizedBox(height: 20),
                                const _DoctorCompletedAppointmentsSectionHeader(),
                                const SizedBox(height: 8),
                              ] else if (i > 0)
                                const SizedBox(height: 8),
                              _DoctorSlotGlassCard(
                                key: ValueKey<String>(
                                  byKeyAll[formatTimeHhMm(orderedSlots[i])]!.id,
                                ),
                                slotStart: orderedSlots[i],
                                appointmentDoc:
                                    byKeyAll[formatTimeHhMm(orderedSlots[i])]!,
                                doctorUserId: doctorUserId,
                                dayLocal: todayOnly,
                                queueByDocId: queueById,
                                onSetStatus: onSetStatus,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DoctorCompletedAppointmentsSectionHeader extends StatelessWidget {
  const _DoctorCompletedAppointmentsSectionHeader();

  static final Color _dividerTone = Colors.white.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labelStyle = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      height: 1.2,
      color: Colors.white.withValues(alpha: 0.48),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: _dividerTone,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              s.translate('doctor_today_completed_section_label'),
              textAlign: TextAlign.center,
              style: labelStyle,
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: _dividerTone,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorSlotGlassCard extends StatelessWidget {
  const _DoctorSlotGlassCard({
    super.key,
    required this.slotStart,
    required this.appointmentDoc,
    required this.doctorUserId,
    required this.dayLocal,
    required this.queueByDocId,
    required this.onSetStatus,
  });

  final DateTime slotStart;
  final QueryDocumentSnapshot<Map<String, dynamic>>? appointmentDoc;
  final String doctorUserId;
  final DateTime dayLocal;
  final Map<String, int> queueByDocId;
  final Future<void> Function(BuildContext context, String docId, String status)
  onSetStatus;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final timeEn = DateFormat.jm('en_US').format(slotStart);
    final doc = appointmentDoc;
    final booked = doc != null;
    final apptData = doc?.data();
    final patientName = booked
        ? (apptData![AppointmentFields.patientName] ?? '—').toString()
        : '';
    final status = booked
        ? AppointmentsScreen._statusKey(apptData![AppointmentFields.status])
        : '';
    final showActions = booked && status == 'pending';
    final isTerminal = booked &&
        (status == 'completed' ||
            status == 'cancelled' ||
            status == 'canceled');
    final patientId = booked
        ? (apptData![AppointmentFields.patientId] ?? '').toString().trim()
        : '';
    final stripGold = booked && status == 'pending';

    Widget cardBody({
      required Map<String, dynamic>? profile,
      required bool patientLoading,
    }) {
      final neutralFinished = isTerminal;
      final leftStripColor = neutralFinished
          ? const Color(0xFF455A64)
          : (stripGold ? null : kStaffAccentSlateBlue);
      final leftStripGradient =
          stripGold && !neutralFinished ? kStaffGoldActionGradient : null;
      final cardBorderColor = neutralFinished
          ? const Color(0xFF546E7A).withValues(alpha: 0.55)
          : (stripGold
              ? kStaffLuxGold.withValues(alpha: 0.48)
              : kStaffSilverBorder);

      const vibrantGreen = Color(0xFF22C55E);
      const softRed = Color(0xFFFB7185);

      Widget circleAction({
        required Color fill,
        required IconData icon,
        required String tooltip,
        required VoidCallback onPressed,
      }) {
        return Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Ink(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        );
      }

      final apptDoc = doc;
      final queueEn = booked && apptDoc != null
          ? formatDailyQueueTicketEnglish(apptDoc, queueByDocId)
          : '—';

      /// Time + name (or empty-slot copy) only; ticket sits in the outer card [Row].
      Widget mainTapChild = Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        child: Column(
          crossAxisAlignment: booked
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Text(
                timeEn,
                textAlign: booked ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  height: 1.05,
                  color: kStaffLuxGold.withValues(alpha: 0.88),
                ),
              ),
            ),
            if (booked) ...[
              const SizedBox(height: 4),
              Text(
                patientName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1.12,
                  color: kStaffLuxGold.withValues(alpha: 0.97),
                ),
              ),
            ],
            if (!booked) ...[
              const SizedBox(height: 2),
              Text(
                s.translate('schedule_slot_available_ku'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1.12,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.translate('master_calendar_add_walkin'),
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w600,
                  fontSize: 9.5,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ],
          ],
        ),
      );

      Widget card = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628).withValues(
                alpha: booked ? 0.52 : 0.44,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cardBorderColor,
                width: 1,
              ),
              boxShadow: stripGold && !neutralFinished
                  ? [
                      BoxShadow(
                        color: kStaffLuxGold.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: IntrinsicHeight(
              child: Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        gradient: leftStripGradient,
                        color: leftStripColor,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(15),
                        ),
                      ),
                    ),
                    if (showActions)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 10,
                          end: 6,
                          top: 6,
                          bottom: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            circleAction(
                              fill: vibrantGreen,
                              icon: Icons.check_rounded,
                              tooltip:
                                  s.translate('doctor_appt_action_complete'),
                              onPressed: () => onSetStatus(
                                context,
                                doc.id,
                                'completed',
                              ),
                            ),
                            const SizedBox(width: 8),
                            circleAction(
                              fill: softRed,
                              icon: Icons.close_rounded,
                              tooltip:
                                  s.translate('doctor_appt_action_decline'),
                              onPressed: () => onSetStatus(
                                context,
                                doc.id,
                                'cancelled',
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (booked && isTerminal)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 10,
                          end: 6,
                          top: 6,
                          bottom: 6,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: status == 'completed'
                                  ? s.translate('doctor_appt_status_completed')
                                  : s.translate('doctor_appt_status_cancelled'),
                              child: Icon(
                                status == 'completed'
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: status == 'completed'
                                    ? vibrantGreen.withValues(alpha: 0.85)
                                    : softRed.withValues(alpha: 0.88),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 72,
                              child: Text(
                                s.translate(
                                  status == 'completed'
                                      ? 'doctor_appt_status_completed'
                                      : 'doctor_appt_status_cancelled',
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 8.5,
                                  height: 1.1,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: booked
                              ? () {
                                  AppointmentsScreen
                                      .showDoctorPatientDetailBottomSheet(
                                    context,
                                    appointmentDoc: doc,
                                    slotStart: slotStart,
                                    queueByDocId: queueByDocId,
                                    onSetStatus: onSetStatus,
                                    showActionButtons: showActions,
                                  );
                                }
                              : () => _openStaffWalkInBooking(
                                    context,
                                    doctorUserId: doctorUserId,
                                    dayLocal: dayLocal,
                                    slotStart: slotStart,
                                  ),
                          child: Directionality(
                            textDirection:
                                AppLocaleScope.of(context).textDirection,
                            child: mainTapChild,
                          ),
                        ),
                      ),
                    ),
                    if (booked)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: 10,
                          top: 6,
                          bottom: 6,
                        ),
                        child: Center(
                          child: Semantics(
                            label:
                                '${s.translate('secretary_ticket_number')} $queueEn',
                            child: _DoctorQueueGoldCircle(number: queueEn),
                          ),
                        ),
                      ),
                    if (!booked)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: 8,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_rounded,
                              color: kStaffLuxGold.withValues(alpha: 0.95),
                              size: 28,
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              width: 64,
                              child: Text(
                                s.translate('book_now'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 8.5,
                                  height: 1.1,
                                  color: kStaffLuxGold.withValues(alpha: 0.88),
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
      );
      if (isTerminal) {
        return Opacity(opacity: 0.68, child: card);
      }
      return card;
    }

    if (!booked) {
      return cardBody(profile: null, patientLoading: false);
    }
    if (patientId.isEmpty) {
      return cardBody(profile: null, patientLoading: false);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .snapshots(),
      builder: (context, patientSnap) {
        final loading = patientSnap.connectionState ==
                ConnectionState.waiting &&
            !patientSnap.hasData;
        final profile = patientSnap.data?.data();
        return cardBody(
          profile: profile,
          patientLoading: loading,
        );
      },
    );
  }
}

class _DoctorTodayDashboard extends StatefulWidget {
  const _DoctorTodayDashboard({
    required this.doctorUserId,
    required this.onSetStatus,
  });

  final String doctorUserId;
  final Future<void> Function(BuildContext context, String docId, String status)
  onSetStatus;

  @override
  State<_DoctorTodayDashboard> createState() => _DoctorTodayDashboardState();
}

class _DoctorTodayDashboardState extends State<_DoctorTodayDashboard> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    if (widget.doctorUserId.isEmpty) {
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

    return StreamBuilder<DateTime>(
      stream: _doctorDashboardTodayClock(),
      builder: (context, clockSnap) {
        final now = clockSnap.data ?? DateTime.now();
        final todayOnly = DateTime(now.year, now.month, now.day);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _AppointmentsDashboardSearchField(
                controller: _searchController,
                hint: s.translate('doctor_patients_search_hint'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: _DoctorTodayScheduleSection(
                key: ValueKey<DateTime>(todayOnly),
                doctorUserId: widget.doctorUserId,
                todayOnly: todayOnly,
                onSetStatus: widget.onSetStatus,
                searchQuery: _searchController.text,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppointmentsDashboardSearchField extends StatelessWidget {
  const _AppointmentsDashboardSearchField({
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
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(
              color: Color(0xFFE8F4F0),
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.search_rounded,
                color: kStaffLuxGold.withValues(alpha: 0.9),
                size: 26,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.patientName,
    required this.queueEn,
    required this.status,
    required this.showActions,
    required this.onCardTap,
    required this.onComplete,
    required this.onCancel,
  });

  final String patientName;
  final String queueEn;
  final String status;
  final bool showActions;
  final VoidCallback onCardTap;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final stripGold = AppointmentsScreen._statusKey(status) == 'pending';

    return Material(
      color: Colors.transparent,
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showActions) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 4,
                        end: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DoctorApptDoneRejectCircle(
                            fill: const Color(0xFF16A34A),
                            icon: Icons.check_rounded,
                            tooltip:
                                s.translate('doctor_appt_action_complete'),
                            onPressed: onComplete,
                          ),
                          const SizedBox(width: 8),
                          _DoctorApptDoneRejectCircle(
                            fill: const Color(0xFFDC2626),
                            icon: Icons.close_rounded,
                            tooltip:
                                s.translate('doctor_appt_action_decline'),
                            onPressed: onCancel,
                          ),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onCardTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                patientName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  height: 1.15,
                                  color: kStaffLuxGold.withValues(
                                    alpha: 0.98,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Semantics(
                      label:
                          '${s.translate('secretary_ticket_number')} $queueEn',
                      child: _DoctorQueueGoldCircle(number: queueEn),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorQueueGoldCircle extends StatelessWidget {
  const _DoctorQueueGoldCircle({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    // ~20% smaller than previous 52px — compact badge, not a dominant focal point.
    const size = 42.0;
    final gold = kStaffLuxGold;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.32),
              blurRadius: 5,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: gold.withValues(alpha: 0.88),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(1.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.42),
                width: 0.75,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF030305),
                  Color(0xFF0B1F33),
                  Color(0xFF0A1628),
                ],
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  number,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: number.length > 2 ? 13.5 : 15.5,
                    height: 1,
                    letterSpacing: -0.2,
                    color: gold.withValues(alpha: 0.96),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorApptDoneRejectCircle extends StatelessWidget {
  const _DoctorApptDoneRejectCircle({
    required this.fill,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Color fill;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
