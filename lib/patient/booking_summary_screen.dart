import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/available_days_queries.dart';
import '../auth/patient_session_cache.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';

/// Final step before committing an [available_days] booking (patient).
/// Shows only **available vs booked** per slot (no other patients' names).
class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({
    super.key,
    required this.availableDayDocId,
    required this.doctorId,
    required this.patientName,
    required this.doctorDisplayName,
    required this.mergedDoctorData,
    required this.dateLocal,
  });

  final String availableDayDocId;
  final String doctorId;
  final String patientName;
  final String doctorDisplayName;
  final Map<String, dynamic> mergedDoctorData;
  final DateTime dateLocal;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _submitting = false;

  String get _doctorUid => widget.doctorId.trim();

  String get _resolvedDoctorUid {
    final direct = widget.doctorId.trim();
    if (direct.isNotEmpty) return direct;
    final fromMap = (widget.mergedDoctorData['uid'] ??
            widget.mergedDoctorData['doctorId'] ??
            widget.mergedDoctorData['id'] ??
            '')
        .toString()
        .trim();
    return fromMap;
  }

  Future<void> _confirmWithPreview(BuildContext context, String timeDisplay) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dir = AppLocaleScope.of(ctx).textDirection;
        return Directionality(
          textDirection: dir,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              s.translate('booking_summary_title'),
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
                  Text(
                    s.translate(
                      'booking_time_confirm_prompt',
                      params: {'time': timeDisplay},
                    ),
                    style: const TextStyle(
                      fontFamily: 'KurdishFont',
                      color: Color(0xFF829AB1),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BookingConfirmLegalNotice(s: s),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  s.translate('action_cancel'),
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: const Color(0xFF102A43),
                ),
                child: Text(
                  s.translate('confirm_booking'),
                  style: const TextStyle(fontFamily: 'KurdishFont'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (ok == true && context.mounted) {
      await _commitBooking(context);
    }
  }

  Future<void> _commitBooking(BuildContext context) async {
    final s = S.of(context);
    final uid = (FirebaseAuth.instance.currentUser?.uid ??
            await PatientSessionCache.readPatientRefId())
        ?.trim();
    if (uid == null || uid.isEmpty) return;

    setState(() => _submitting = true);
    try {
      var doctorName = widget.doctorDisplayName.trim();
      if (doctorName.isEmpty) {
        try {
          doctorName = canonicalDoctorNameForStorage(widget.mergedDoctorData);
        } catch (_) {}
      }
      if (doctorName.isEmpty) doctorName = s.translate('doctor_default');

      final err = await bookAvailableDayTransaction(
        availableDayDocId: widget.availableDayDocId,
        patientId: uid,
        patientName: widget.patientName,
        doctorId: _resolvedDoctorUid,
        doctorDisplayName: doctorName,
      );

      if (!mounted || !context.mounted) return;

      if (err != null) {
        final key = switch (err) {
          'available_day_full' => 'available_day_full',
          'available_day_missing' => 'available_day_missing',
          'available_day_doctor_mismatch' => 'available_day_mismatch',
          'available_day_closed' => 'available_day_closed',
          'login_required' => 'login_required',
          _ => 'available_day_tx_failed',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate(key),
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
        return;
      }

      if (!mounted || !context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final dir = AppLocaleScope.of(ctx).textDirection;
          final loc = S.of(ctx);
          return Directionality(
            textDirection: dir,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1D1E33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                loc.translate('booking_success_title'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFD9E2EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                loc.translate('booking_success_body'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFF829AB1),
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    loc.translate('ok'),
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

      if (!mounted || !context.mounted) return;
      // Return to patient dashboard (home under AuthGate), not My Appointments.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dayOnly = DateTime(
      widget.dateLocal.year,
      widget.dateLocal.month,
      widget.dateLocal.day,
    );

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
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
            s.translate('booking_summary_title'),
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        body: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AvailableDayFields.collection)
                .doc(widget.availableDayDocId)
                .snapshots(),
            builder: (context, daySnap) {
              if (daySnap.connectionState == ConnectionState.waiting &&
                  !daySnap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                  ),
                );
              }
              final dayData = daySnap.data?.data();
              final open = availableDayIsOpen(dayData);
              if (dayData == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.translate('available_day_missing'),
                      style: const TextStyle(
                        color: Color(0xFF829AB1),
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                  ),
                );
              }

              final startHhMm = normalizeAvailableDayStartTimeHhMm(
                dayData[AvailableDayFields.startTime],
              );
              final closingHhMm = normalizeAvailableDayClosingTimeHhMm(
                dayData[AvailableDayFields.closingTime],
              );
              final durMin = normalizeAppointmentDurationMinutes(
                dayData[AvailableDayFields.appointmentDuration],
              );

              final slots = generatedSlotStartsForDay(
                dateOnly: dayOnly,
                startTimeHhMm: startHhMm,
                closingTimeHhMm: closingHhMm,
                durationMinutes: durMin,
              );

              return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                stream: watchDoctorAppointmentsForLocalDay(
                  doctorUserId: _doctorUid,
                  dayLocal: dayOnly,
                ),
                builder: (context, apptSnap) {
                  if (apptSnap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          s.translate(
                            'doctors_load_error_detail',
                            params: {'error': '${apptSnap.error}'},
                          ),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontFamily: 'KurdishFont',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final docs = apptSnap.data ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final bookedKeys = bookedTimeKeysHhMmForAvailableDay(
                    sameDayDocs: docs,
                    availableDayDocId: widget.availableDayDocId,
                  );
                  final firstFree = firstAvailableSlotStart(
                    slots: slots,
                    bookedKeys: bookedKeys,
                  );
                  final assignedTimeDisplay = firstFree != null
                      ? DateFormat.jm(localeTag).format(firstFree)
                      : '—';

                  final doctorName = widget.doctorDisplayName.trim().isEmpty
                      ? s.translate('doctor_default')
                      : widget.doctorDisplayName;
                  final dateLabelValue =
                      DateFormat.yMMMEd(localeTag).format(widget.dateLocal);

                  final bookedCount = bookedKeys.length;
                  final totalCapacity = slots.length;
                  final spotsLeft =
                      (totalCapacity - bookedCount).clamp(0, totalCapacity);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            18,
                            16,
                            18,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF475569).withValues(alpha: 0.5),
                              width: 1,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1E293B).withValues(alpha: 0.92),
                                const Color(0xFF0F172A).withValues(alpha: 0.96),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.38),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                                spreadRadius: -4,
                              ),
                              BoxShadow(
                                color: const Color(0xFF38BDF8)
                                    .withValues(alpha: 0.07),
                                blurRadius: 28,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      s.translate(
                                        'booking_summary_assigned_time',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'KurdishFont',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFCBD5E1),
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      assignedTimeDisplay,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'KurdishFont',
                                        fontSize: 36,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF38BDF8),
                                        height: 1.1,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _BookingInfoTile(
                                      label: s.translate(
                                        'booking_summary_doctor',
                                      ),
                                      value: doctorName,
                                      valueColor: const Color(0xFFF59E0B),
                                      valueFontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _BookingInfoTile(
                                      label: s.translate(
                                        'booking_summary_date_label',
                                      ),
                                      value: dateLabelValue,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 20, bottom: 8),
                                child: _BookingCapacityStats(
                                  bookedText: _localizedDigitString(
                                    context,
                                    bookedCount,
                                  ),
                                  totalText: _localizedDigitString(
                                    context,
                                    totalCapacity,
                                  ),
                                  sublabel: s.translate(
                                    'booking_summary_only_spots_left',
                                    params: {
                                      'x': _localizedDigitString(
                                        context,
                                        spotsLeft,
                                      ),
                                    },
                                  ),
                                ),
                              ),
                              if (!open)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    s.translate('available_day_closed_banner'),
                                    style: const TextStyle(
                                      fontFamily: 'KurdishFont',
                                      color: Color(0xFFF87171),
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.translate('patient_booking_slots_privacy_title'),
                          style: const TextStyle(
                            fontFamily: 'KurdishFont',
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: slots.isEmpty
                              ? Center(
                                  child: Text(
                                    s.translate('day_mgmt_no_slots'),
                                    style: const TextStyle(
                                      color: Color(0xFF829AB1),
                                      fontFamily: 'KurdishFont',
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  itemCount: slots.length,
                                  itemBuilder: (context, i) {
                                    final slot = slots[i];
                                    final key = formatTimeHhMm(slot);
                                    final isBooked = bookedKeys.contains(key);
                                    final timePretty =
                                        DateFormat.jm(localeTag).format(slot);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Material(
                                        color: const Color(0xFF15192E),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 88,
                                                child: Text(
                                                  timePretty,
                                                  style: const TextStyle(
                                                    fontFamily: 'KurdishFont',
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: Color(0xFFCBD5E1),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  isBooked
                                                      ? s.translate(
                                                          'patient_slot_label_booked',
                                                        )
                                                      : s.translate(
                                                          'patient_slot_label_available',
                                                        ),
                                                  style: TextStyle(
                                                    fontFamily: 'KurdishFont',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: isBooked
                                                        ? const Color(0xFFDC2626)
                                                        : const Color(0xFF4ADE80),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                        _GradientBookingButton(
                          enabled: !_submitting &&
                              open &&
                              firstFree != null &&
                              slots.isNotEmpty,
                          submitting: _submitting,
                          label: s.translate('confirm_booking'),
                          onPressed: () => _confirmWithPreview(
                            context,
                            assignedTimeDisplay,
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
      ),
    );
  }
}

String _localizedDigitString(BuildContext context, int n) {
  final code = Localizations.localeOf(context).languageCode;
  if (code == 'ar' || code == 'ckb') {
    try {
      return NumberFormat('#', 'ar').format(n);
    } catch (_) {
      return '$n';
    }
  }
  return '$n';
}

/// Legal warning: red border, gavel icon, bold red emphasis phrase (above Confirm).
class _BookingConfirmLegalNotice extends StatelessWidget {
  const _BookingConfirmLegalNotice({required this.s});

  final AppLocalizations s;

  static const Color _borderRed = Color(0xFFDC2626);
  static const Color _emphasisRed = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderRed, width: 2),
        color: const Color(0xFF2A0A0A).withValues(alpha: 0.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel, color: _borderRed, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFE2E8F0),
                  height: 1.55,
                  fontSize: 13.5,
                ),
                children: [
                  TextSpan(text: s.translate('booking_confirm_legal_notice_prefix')),
                  TextSpan(
                    text: s.translate('booking_confirm_legal_notice_emphasis'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _emphasisRed,
                    ),
                  ),
                  TextSpan(text: s.translate('booking_confirm_legal_notice_suffix')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Booked (red) + `/` total capacity (green), with remaining-spots sentence below.
class _BookingCapacityStats extends StatelessWidget {
  const _BookingCapacityStats({
    required this.bookedText,
    required this.totalText,
    required this.sublabel,
  });

  final String bookedText;
  final String totalText;
  final String sublabel;

  static const Color _bookedRed = Color(0xFFB91C1C);
  static const Color _capGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bookedText,
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: _bookedRed,
                  height: 1,
                ),
              ),
              Text(
                ' / ',
                style: TextStyle(
                  fontFamily: 'KurdishFont',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  height: 1,
                ),
              ),
              Text(
                totalText,
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _capGreen,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            sublabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingInfoTile extends StatelessWidget {
  const _BookingInfoTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueFontSize,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final double? valueFontSize;

  @override
  Widget build(BuildContext context) {
    final size = valueFontSize ?? 14.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'KurdishFont',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'KurdishFont',
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFFE8EEF4),
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _GradientBookingButton extends StatelessWidget {
  const _GradientBookingButton({
    required this.enabled,
    required this.submitting,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool submitting;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !submitting;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: active
              ? const [
                  Color(0xFF3B82F6),
                  Color(0xFF2563EB),
                  Color(0xFF1D4ED8),
                ]
              : const [
                  Color(0xFF475569),
                  Color(0xFF334155),
                ],
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.38),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFFE0F2FE),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: active
                            ? const Color(0xFFF0F9FF)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
