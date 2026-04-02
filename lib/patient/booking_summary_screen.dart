import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:intl/intl.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/available_days_queries.dart';
import '../auth/patient_session_cache.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../theme/patient_premium_theme.dart';

const Color _kNavy = Color(0xFF0D2137);
const Color _kBodyMuted = Color(0xFF455A64);
const Color _kGoldDark = Color(0xFF8B6914);
const Color _kGoldMid = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFF6E7A6);
const Color _kGoldShine = Color(0xFFFFE082);
const Color _kEmeraldAvailable = Color(0xFF1B5E20);
const Color _kSlotBorderBlue = Color(0xFF1565C0);
const Color _kBookedRed = Color(0xFFB91C1C);

const LinearGradient _kMetallicGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    _kGoldDark,
    _kGoldMid,
    _kGoldShine,
    _kGoldLight,
    _kGoldMid,
    _kGoldDark,
  ],
  stops: [0.0, 0.22, 0.42, 0.55, 0.78, 1.0],
);

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
  final GlobalKey _selectedSlotKey = GlobalKey();
  bool _didEnsureSelectedVisible = false;
  bool _scrollToSlotScheduled = false;

  String get _doctorUid => widget.doctorId.trim();

  @override
  void didUpdateWidget(covariant BookingSummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableDayDocId != widget.availableDayDocId ||
        oldWidget.dateLocal != widget.dateLocal) {
      _didEnsureSelectedVisible = false;
      _scrollToSlotScheduled = false;
    }
  }

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

  void _scheduleScrollToAssignedSlot(
    DateTime? firstFree,
    List<DateTime> slots,
  ) {
    if (_scrollToSlotScheduled ||
        _didEnsureSelectedVisible ||
        firstFree == null ||
        slots.isEmpty) {
      return;
    }
    final target = formatTimeHhMm(firstFree);
    if (!slots.any((s) => formatTimeHhMm(s) == target)) return;

    _scrollToSlotScheduled = true;

    void tryVisible({bool allowRetry = true}) {
      if (!mounted || _didEnsureSelectedVisible) return;
      final ctx = _selectedSlotKey.currentContext;
      if (ctx != null) {
        _didEnsureSelectedVisible = true;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.22,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      } else if (allowRetry) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => tryVisible(allowRetry: false),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => tryVisible());
    });
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
            backgroundColor: Colors.white.withValues(alpha: 0.97),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _kGoldMid.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            title: Text(
              s.translate('booking_summary_title'),
              style: const TextStyle(
                fontFamily: kPatientNrtBoldFont,
                color: _kNavy,
                fontWeight: FontWeight.w800,
                fontSize: 17,
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
                      fontFamily: kPatientNrtBoldFont,
                      color: _kBodyMuted,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      fontSize: 14,
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
                  style: TextStyle(
                    color: _kBodyMuted.withValues(alpha: 0.9),
                    fontFamily: kPatientNrtBoldFont,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGoldMid,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  s.translate('confirm_booking'),
                  style: const TextStyle(
                    fontFamily: kPatientNrtBoldFont,
                    fontWeight: FontWeight.w800,
                  ),
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
              style: const TextStyle(fontFamily: kPatientNrtBoldFont),
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
              backgroundColor: Colors.white.withValues(alpha: 0.97),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: _kGoldMid.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              title: Text(
                loc.translate('booking_success_title'),
                style: const TextStyle(
                  fontFamily: kPatientNrtBoldFont,
                  color: _kNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              content: Text(
                loc.translate('booking_success_body'),
                style: const TextStyle(
                  fontFamily: kPatientNrtBoldFont,
                  color: _kBodyMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    loc.translate('ok'),
                    style: const TextStyle(
                      color: kPatientDeepBlue,
                      fontFamily: kPatientNrtBoldFont,
                      fontWeight: FontWeight.w800,
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
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _kNavy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: _kNavy),
            onPressed: () => Navigator.pop(context),
            tooltip: s.translate('tooltip_back'),
          ),
          title: Text(
            s.translate('booking_summary_title'),
            style: const TextStyle(
              fontFamily: kPatientNrtBoldFont,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _kNavy,
              letterSpacing: 0.2,
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: CustomPaint(
            painter: PatientSubtleGeometricPatternPainter(),
            child: SafeArea(
              top: false,
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
                        color: _kBodyMuted,
                        fontFamily: kPatientNrtBoldFont,
                        fontWeight: FontWeight.w600,
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
                            fontFamily: kPatientNrtBoldFont,
                            fontWeight: FontWeight.w600,
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

                  _scheduleScrollToAssignedSlot(firstFree, slots);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.93),
                                    Colors.white.withValues(alpha: 0.78),
                                  ],
                                ),
                                border: Border.all(
                                  color: _kGoldMid.withValues(alpha: 0.78),
                                  width: 1.15,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 26,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color: _kGoldMid.withValues(alpha: 0.16),
                                    blurRadius: 22,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  20,
                                  18,
                                  20,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      s.translate(
                                        'booking_summary_assigned_time',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: kPatientNrtBoldFont,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _kBodyMuted.withValues(
                                          alpha: 0.92,
                                        ),
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      assignedTimeDisplay,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: kPatientNrtBoldFont,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        color: _kNavy,
                                        height: 1.1,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _BookingSummaryInfoRow(
                                      icon: Icons.person_rounded,
                                      label: s.translate(
                                        'booking_summary_doctor',
                                      ),
                                      value: doctorName,
                                    ),
                                    const SizedBox(height: 14),
                                    _BookingSummaryInfoRow(
                                      icon: Icons.calendar_today_rounded,
                                      label: s.translate(
                                        'booking_summary_date_label',
                                      ),
                                      value: dateLabelValue,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 18,
                                        bottom: 6,
                                      ),
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
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          s.translate(
                                            'available_day_closed_banner',
                                          ),
                                          style: const TextStyle(
                                            fontFamily: kPatientNrtBoldFont,
                                            color: Color(0xFFE53935),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.translate('patient_booking_slots_privacy_title'),
                          style: TextStyle(
                            fontFamily: kPatientNrtBoldFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kBodyMuted.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (firstFree != null && slots.isNotEmpty) ...[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _kGoldMid.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: _kGoldDark.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s.translate(
                                        'booking_summary_selected_slot_hint',
                                      ),
                                      style: TextStyle(
                                        fontFamily: kPatientNrtBoldFont,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                        color: _kNavy.withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Expanded(
                          child: slots.isEmpty
                              ? Center(
                                  child: Text(
                                    s.translate('day_mgmt_no_slots'),
                                    style: TextStyle(
                                      color: _kBodyMuted.withValues(alpha: 0.9),
                                      fontFamily: kPatientNrtBoldFont,
                                      fontWeight: FontWeight.w600,
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
                                    final assigned = firstFree;
                                    final isYourSlot = assigned != null &&
                                        !isBooked &&
                                        key == formatTimeHhMm(assigned);
                                    final dimOthers = firstFree != null &&
                                        slots.isNotEmpty &&
                                        !isYourSlot;
                                    final timePretty =
                                        DateFormat.jm(localeTag).format(slot);

                                    final statusText = isBooked
                                        ? s.translate(
                                            'patient_slot_label_booked',
                                          )
                                        : (isYourSlot
                                              ? s.translate(
                                                  'patient_slot_label_yours',
                                                )
                                              : s.translate(
                                                  'patient_slot_label_available',
                                                ));

                                    final statusStyle = TextStyle(
                                      fontFamily: kPatientNrtBoldFont,
                                      fontSize: isYourSlot ? 15 : 14,
                                      fontWeight: isYourSlot
                                          ? FontWeight.w900
                                          : FontWeight.w800,
                                      color: isBooked
                                          ? _kBookedRed
                                          : (isYourSlot
                                                ? _kNavy
                                                : _kEmeraldAvailable),
                                    );

                                    Widget card = DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: isYourSlot
                                            ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  const Color(0xFFFFF8E1)
                                                      .withValues(alpha: 0.98),
                                                  const Color(0xFFFFECB3)
                                                      .withValues(alpha: 0.92),
                                                  Color(0xFFE8EAF6)
                                                      .withValues(alpha: 0.55),
                                                ],
                                              )
                                            : null,
                                        color: isYourSlot
                                            ? null
                                            : Colors.white.withValues(
                                                alpha: 0.94,
                                              ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isYourSlot
                                              ? _kGoldMid.withValues(
                                                  alpha: 0.98,
                                                )
                                              : _kSlotBorderBlue.withValues(
                                                  alpha: 0.28,
                                                ),
                                          width: isYourSlot ? 2.85 : 0.75,
                                        ),
                                        boxShadow: isYourSlot
                                            ? [
                                                BoxShadow(
                                                  color: _kGoldMid.withValues(
                                                    alpha: 0.38,
                                                  ),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 5),
                                                  spreadRadius: 0.5,
                                                ),
                                                BoxShadow(
                                                  color: _kGoldShine
                                                      .withValues(alpha: 0.35),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.04),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              color: isYourSlot
                                                  ? _kGoldDark.withValues(
                                                      alpha: 0.95,
                                                    )
                                                  : _kGoldMid.withValues(
                                                      alpha: 0.95,
                                                    ),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            SizedBox(
                                              width: 86,
                                              child: Text(
                                                timePretty,
                                                style: const TextStyle(
                                                  fontFamily:
                                                      kPatientNrtBoldFont,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: _kNavy,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                statusText,
                                                textAlign: TextAlign.end,
                                                style: statusStyle,
                                              ),
                                            ),
                                            if (isYourSlot) ...[
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: _kEmeraldAvailable,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.star_rounded,
                                                color: _kGoldMid,
                                                size: 26,
                                                shadows: [
                                                  Shadow(
                                                    color: _kGoldDark
                                                        .withValues(alpha: 0.35),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );

                                    if (dimOthers) {
                                      card = Opacity(opacity: 0.5, child: card);
                                    }

                                    return Padding(
                                      key: isYourSlot
                                          ? _selectedSlotKey
                                          : ValueKey<String>('slot_$key'),
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: card,
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                        _PremiumGoldBookingButton(
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

/// Doctor + date row with gold icon on soft emerald circle (summary card).
class _BookingSummaryInfoRow extends StatelessWidget {
  const _BookingSummaryInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  static const Color _iconCircleGreen = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _iconCircleGreen.withValues(alpha: 0.12),
            border: Border.all(
              color: _kGoldMid.withValues(alpha: 0.48),
              width: 0.75,
            ),
          ),
          child: Icon(icon, color: _kGoldMid, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: kPatientNrtBoldFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kBodyMuted.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kPatientNrtBoldFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
        border: Border.all(color: _borderRed, width: 1.75),
        color: const Color(0xFFFFEBEE).withValues(alpha: 0.85),
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
                  fontFamily: kPatientNrtBoldFont,
                  color: _kNavy,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                  fontSize: 13.5,
                ),
                children: [
                  TextSpan(text: s.translate('booking_confirm_legal_notice_prefix')),
                  TextSpan(
                    text: s.translate('booking_confirm_legal_notice_emphasis'),
                    style: const TextStyle(
                      fontFamily: kPatientNrtBoldFont,
                      fontWeight: FontWeight.w900,
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
                  fontFamily: kPatientNrtBoldFont,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: _bookedRed,
                  height: 1,
                ),
              ),
              Text(
                ' / ',
                style: TextStyle(
                  fontFamily: kPatientNrtBoldFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _kBodyMuted.withValues(alpha: 0.75),
                  height: 1,
                ),
              ),
              Text(
                totalText,
                style: const TextStyle(
                  fontFamily: kPatientNrtBoldFont,
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
            style: TextStyle(
              fontFamily: kPatientNrtBoldFont,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kBodyMuted.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumGoldBookingButton extends StatefulWidget {
  const _PremiumGoldBookingButton({
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
  State<_PremiumGoldBookingButton> createState() =>
      _PremiumGoldBookingButtonState();
}

class _PremiumGoldBookingButtonState extends State<_PremiumGoldBookingButton>
    with SingleTickerProviderStateMixin {
  static const double _kPressedScale = 0.96;

  late final AnimationController _scaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 115),
    reverseDuration: const Duration(milliseconds: 135),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: _kPressedScale,
  ).animate(
    CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
    ),
  );

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (!widget.enabled || widget.submitting) return;
    HapticFeedback.lightImpact();
    _scaleController.forward();
  }

  void _pressEnd() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.submitting;
    final shell = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: active
            ? _kMetallicGoldGradient
            : const LinearGradient(
                colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
              ),
        border: Border.all(
          color: active
              ? _kGoldLight.withValues(alpha: 0.65)
              : Colors.transparent,
          width: 0.85,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _kGoldDark.withValues(alpha: 0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: _kGoldMid.withValues(alpha: 0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: widget.submitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: kPatientNrtBoldFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: active ? Colors.white : const Color(0xFFE5E7EB),
                    shadows: active
                        ? const [
                            Shadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) => _pressEnd(),
      onTapCancel: _pressEnd,
      onTap: active ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: active ? _scale.value : 1.0,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: shell,
      ),
    );
  }
}
