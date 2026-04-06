import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../auth/app_logout.dart';
import '../firestore/appointment_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/appointment_booking_details.dart';
import '../models/doctor_localized_content.dart';
import '../theme/staff_premium_theme.dart';
import '../widgets/appointment_action_confirm_dialog.dart';
import '../widgets/secretary_appointment_card.dart';

/// Secretary: appointments for selected doctor — active (earliest first), then
/// completed/cancelled (most recently updated first). Re-sorts on each snapshot.
class SecretaryBookingsDashboardScreen extends StatefulWidget {
  const SecretaryBookingsDashboardScreen({super.key});

  @override
  State<SecretaryBookingsDashboardScreen> createState() =>
      _SecretaryBookingsDashboardScreenState();
}

class _SecretaryBookingsDashboardScreenState
    extends State<SecretaryBookingsDashboardScreen> {
  String? _pickedDoctorId;
  final Set<String> _updating = {};
  final ScrollController _appointmentsScrollController = ScrollController();

  @override
  void dispose() {
    _appointmentsScrollController.dispose();
    super.dispose();
  }

  void _scrollAppointmentsToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _appointmentsScrollController;
      if (c.hasClients) {
        c.jumpTo(0);
      }
    });
  }

  Future<void> _setStatus(String docId, String status) async {
    final id = docId.trim();
    if (id.isEmpty) return;
    setState(() => _updating.add(id));
    try {
      await FirebaseFirestore.instance
          .collection(AppointmentFields.collection)
          .doc(id)
          .update({
            AppointmentFields.status: status,
            AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
          });
    } finally {
      if (mounted) {
        setState(() => _updating.remove(id));
        _scrollAppointmentsToTop();
      }
    }
  }

  String? _receiptUrlFromAppointment(Map<String, dynamic> data) {
    final a = (data[AppointmentFields.receiptImageUrl] ?? '').toString().trim();
    if (a.isNotEmpty) return a;
    final b = (data[AppointmentFields.receiptUrl] ?? '').toString().trim();
    if (b.isNotEmpty) return b;
    return null;
  }

  bool _canSecretaryVerifyPayment(Map<String, dynamic> data) {
    return (data[AppointmentFields.paymentStatus] ?? '')
            .toString()
            .toLowerCase()
            .trim() ==
        'pending_verification';
  }

  Future<void> _verifyPayment(BuildContext context, String docId) async {
    final id = docId.trim();
    if (id.isEmpty) return;
    setState(() => _updating.add(id));
    try {
      await FirebaseFirestore.instance
          .collection(AppointmentFields.collection)
          .doc(id)
          .update({
            AppointmentFields.paymentStatus: 'confirmed',
            AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
          });
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).translate('secretary_payment_verified_ok'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  Future<void> _confirmAndSetStatus(
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
    await _setStatus(docId, status);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: kStaffPrimaryNavy,
          foregroundColor: const Color(0xFFD9E2EC),
          title: Text(
            s.translate('secretary_bookings_title'),
            style: staffAppBarTitleStyle().copyWith(
              color: const Color(0xFFD9E2EC),
            ),
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
                        style: staffLabelTextStyle(),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _pickedDoctorId != null &&
                              docs.any((d) => d.id == _pickedDoctorId)
                          ? _pickedDoctorId
                          : null,
                      dropdownColor: kStaffCardSurface,
                      decoration: InputDecoration(
                        labelText: s.translate('master_calendar_pick_doctor'),
                        labelStyle: staffLabelTextStyle(),
                        filled: true,
                        fillColor: kStaffCardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kStaffSilverBorder,
                            width: kStaffCardOutlineWidth,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kStaffSilverBorder,
                            width: kStaffCardOutlineWidth,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kStaffPrimaryNavy,
                            width: 1.2,
                          ),
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
                                style: staffHeaderTextStyle(
                                  fontSize: 15,
                                  color: kStaffBodyText,
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
                          style: staffLabelTextStyle(),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection(AppointmentFields.collection)
                            .where(
                              AppointmentFields.doctorId,
                              isEqualTo: _pickedDoctorId!.trim(),
                            )
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: kStaffPrimaryNavy,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            );
                          }
                          final docs = List<
                              QueryDocumentSnapshot<
                                  Map<String, dynamic>>>.from(
                            snapshot.data?.docs ?? [],
                          );
                          sortStaffAppointmentsInPlace(docs);
                          final queueById = dailyQueueNumberByDocId(docs);

                          if (docs.isEmpty) {
                            return Center(
                              child: Text(
                                s.translate('secretary_bookings_empty'),
                                style: staffLabelTextStyle(),
                              ),
                            );
                          }

                          return ListView.separated(
                            controller: _appointmentsScrollController,
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              16 + MediaQuery.paddingOf(context).bottom,
                            ),
                            itemCount: docs.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 18),
                            itemBuilder: (context, i) {
                              final doc = docs[i];
                              final data = doc.data();
                              final st = (data[AppointmentFields.status] ??
                                      'pending')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              final patient =
                                  (data[AppointmentFields.patientName] ?? '—')
                                      .toString();
                              final busy = _updating.contains(doc.id);
                              final queueEn =
                                  formatDailyQueueTicketEnglish(doc, queueById);
                              final patientId =
                                  (data[AppointmentFields.patientId] ?? '')
                                      .toString()
                                      .trim();

                              SecretaryAppointmentCard buildCard(
                                String phoneEn,
                                String dialRaw,
                              ) {
                                return SecretaryAppointmentCard(
                                  animationIndex: i,
                                  patientName: patient,
                                  queueEn: queueEn,
                                  phoneDisplay: phoneEn,
                                  phoneDialRaw: dialRaw.isEmpty ? null : dialRaw,
                                  statusRaw: st,
                                  busy: busy,
                                  receiptImageUrl:
                                      _receiptUrlFromAppointment(data),
                                  paymentMethodRaw:
                                      (data[AppointmentFields.paymentMethod] ??
                                              '')
                                          .toString(),
                                  paymentStatusRaw:
                                      (data[AppointmentFields.paymentStatus] ??
                                              '')
                                          .toString(),
                                  onVerifyPayment: _canSecretaryVerifyPayment(
                                    data,
                                  )
                                      ? () => _verifyPayment(context, doc.id)
                                      : null,
                                  onCompleted: busy
                                      ? null
                                      : () => _confirmAndSetStatus(
                                            context,
                                            doc.id,
                                            'completed',
                                          ),
                                  onCancelled: busy
                                      ? null
                                      : () => _confirmAndSetStatus(
                                            context,
                                            doc.id,
                                            'cancelled',
                                          ),
                                );
                              }

                              final Widget row;
                              if (patientId.isEmpty) {
                                final raw = appointmentBookingPhoneRaw(data, null);
                                final phoneEn = raw.trim().isEmpty
                                    ? s.translate('booking_detail_not_recorded')
                                    : staffDigitsToEnglishAscii(raw);
                                row = buildCard(phoneEn, raw);
                              } else {
                                row = StreamBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(patientId)
                                      .snapshots(),
                                  builder: (context, snap) {
                                    final userData = snap.data?.data();
                                    final raw = appointmentBookingPhoneRaw(
                                      data,
                                      userData,
                                    );
                                    final phoneEn = raw.trim().isEmpty
                                        ? s.translate(
                                            'booking_detail_not_recorded',
                                          )
                                        : staffDigitsToEnglishAscii(raw);
                                    return buildCard(phoneEn, raw);
                                  },
                                );
                              }
                              return KeyedSubtree(
                                key: ValueKey<String>(doc.id),
                                child: row,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
