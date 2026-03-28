import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../calendar/calendar_slot_logic.dart';
import '../firestore/appointment_queries.dart';
import '../firestore/calendar_block_queries.dart';
import '../firestore/firestore_index_error_log.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../specialty_categories.dart';
import 'my_appointments_screen.dart';

String _bookingTimeKeyFromMinutes(int m) {
  final h = m ~/ 60;
  final min = m % 60;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

String _bookingNormalizeStoredTime(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) return raw.trim();
  final h = int.tryParse(parts[0].trim()) ?? 0;
  final mi = int.tryParse(parts[1].trim()) ?? 0;
  return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
}

Set<String> _bookingBookedTimeKeysFromDocs(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final set = <String>{};
  for (final d in docs) {
    final data = d.data();
    final st =
        (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
    if (st == 'cancelled') continue;
    final time = (data[AppointmentFields.time] ?? '').toString().trim();
    if (time.isEmpty) continue;
    set.add(_bookingNormalizeStoredTime(time));
  }
  return set;
}

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
  static const String _bookingBrandTitle = 'HR Nora';

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;
  DateTime _patientCalendarFocusedDay = DateTime.now();
  bool _patientCalendarPrimed = false;
  final GlobalKey _bookingSectionKey = GlobalKey();

  static const Color _pcGreenFill = Color(0xFF0F3D28);
  static const Color _pcGreenBorder = Color(0xFF22C55E);
  static const Color _pcRedFill = Color(0xFF3D1418);
  static const Color _pcRedBorder = Color(0xFFEF4444);
  static const Color _pcAmberFill = Color(0xFF3D2A0F);
  static const Color _pcAmberBorder = Color(0xFFF59E0B);

  @override
  void didUpdateWidget(covariant DoctorDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctorId != widget.doctorId) {
      _patientCalendarPrimed = false;
      _patientCalendarFocusedDay = DateTime.now();
      _selectedDate = null;
      _selectedTime = null;
    }
  }

  TimeOfDay _timeFromMinutes(int m) {
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String _formatMinutes(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _scheduleOverridesMap(dynamic raw) {
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  bool _hasAnyBookableWindow(
    Map<String, dynamic>? weekly,
    Map<String, dynamic>? overrides,
  ) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 120; i++) {
      if (workingWindowForDateWithOverrides(d, weekly, overrides) != null) {
        return true;
      }
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  DateTime _patientMonthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _patientMonthEndExclusive(DateTime d) =>
      DateTime(d.year, d.month + 1, 1);

  Set<String> _patientApptBookedKeysForDay(
    DateTime day,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> apptDocs,
  ) {
    final y = day.year;
    final m = day.month;
    final d = day.day;
    final set = <String>{};
    for (final doc in apptDocs) {
      final data = doc.data();
      final st =
          (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
      if (st == 'cancelled') continue;
      final ts = data[AppointmentFields.date];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.year != y || dt.month != m || dt.day != d) continue;
      final t = (data[AppointmentFields.time] ?? '').toString().trim();
      if (t.isEmpty) continue;
      final parts = t.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final mi = int.tryParse(parts[1].trim()) ?? 0;
      set.add(
        '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}',
      );
    }
    return set;
  }

  Map<DateTime, MasterDayVisual> _patientBookingVisualsForMonth({
    required DateTime focusedMonth,
    required Map<String, dynamic>? weekly,
    required Map<String, dynamic>? overrides,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> apptDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockDocs,
    required Map<String, dynamic>? doctorProfile,
  }) {
    final blockMaps = blockDocs.map((e) => e.data()).toList();
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final map = <DateTime, MasterDayVisual>{};

    for (var d = first;
        !d.isAfter(last);
        d = d.add(const Duration(days: 1))) {
      final key = DateTime(d.year, d.month, d.day);
      final dayBlocks = blocksForCalendarDay(key, blockMaps);
      final booked = _patientApptBookedKeysForDay(key, apptDocs);
      map[key] = classifyDay(
        dateOnly: key,
        weeklySchedule: weekly,
        dateOverrides: overrides,
        bookedTimeKeys: booked,
        dayBlocks: dayBlocks,
        slotStepMinutes: effectiveAppointmentSlotMinutes(
          dateOnly: key,
          dateOverrides: overrides,
          doctorUserData: doctorProfile,
        ),
      );
    }
    return map;
  }

  DateTime? _firstPatientDateWithAvailability(
    Map<String, dynamic>? weekly,
    Map<String, dynamic>? overrides,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> apptDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> blockDocs,
    Map<String, dynamic>? doctorProfile,
  ) {
    final blockMaps = blockDocs.map((e) => e.data()).toList();
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 120; i++) {
      final booked = _patientApptBookedKeysForDay(d, apptDocs);
      final dayBlocks = blocksForCalendarDay(d, blockMaps);
      final v = classifyDay(
        dateOnly: d,
        weeklySchedule: weekly,
        dateOverrides: overrides,
        bookedTimeKeys: booked,
        dayBlocks: dayBlocks,
        slotStepMinutes: effectiveAppointmentSlotMinutes(
          dateOnly: d,
          dateOverrides: overrides,
          doctorUserData: doctorProfile,
        ),
      );
      if (v == MasterDayVisual.hasAvailability) return d;
      d = d.add(const Duration(days: 1));
    }
    return null;
  }

  void _setSelectedDateSlots(
    DateTime date,
    Map<String, dynamic>? weekly,
    Map<String, dynamic>? overrides, {
    Map<String, dynamic>? doctorProfile,
  }) {
    final win = workingWindowForDateWithOverrides(date, weekly, overrides);
    if (win == null) {
      _selectedTime = null;
      return;
    }
    final step = effectiveAppointmentSlotMinutes(
      dateOnly: date,
      dateOverrides: overrides,
      doctorUserData: doctorProfile,
    );
    final slots = slotStartMinutesForWindow(
      win.startMinutes,
      win.endMinutes,
      step: step,
    );
    _selectedTime = slots.isNotEmpty ? _timeFromMinutes(slots.first) : null;
  }

  Widget _patientBookingDayCell({
    required DateTime day,
    required DateTime focusedMonth,
    required MasterDayVisual? visual,
    required bool isToday,
    required bool isSelected,
    bool isOutside = false,
  }) {
    Color fill;
    Color edgeColor;
    switch (visual) {
      case MasterDayVisual.hasAvailability:
        fill = _pcGreenFill;
        edgeColor = _pcGreenBorder;
      case MasterDayVisual.fullyBooked:
        fill = _pcAmberFill;
        edgeColor = _pcAmberBorder;
      case MasterDayVisual.nonWorking:
      default:
        fill = _pcRedFill;
        edgeColor = _pcRedBorder;
    }
    if (isOutside) {
      fill = fill.withValues(alpha: 0.45);
      edgeColor = edgeColor.withValues(alpha: 0.45);
    }

    final textColor = isOutside
        ? const Color(0xFF829AB1).withValues(alpha: 0.5)
        : const Color(0xFFE8EEF4);

    final Border cellBorder;
    if (isToday) {
      cellBorder = Border.all(color: const Color(0xFF38BDF8), width: 2);
    } else if (isSelected) {
      cellBorder = Border.all(color: const Color(0xFF6366F1), width: 2);
    } else {
      cellBorder = Border.all(
        color: edgeColor,
        width: visual == MasterDayVisual.hasAvailability ? 1.4 : 1.2,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: cellBorder,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontFamily: 'KurdishFont',
          fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 15,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _confirmAppointment(
    String patientName,
    String doctorDisplayName,
    Map<String, dynamic>? weekly,
    Map<String, dynamic>? overrides,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final s = S.of(context);
    final win = _selectedDate != null
        ? workingWindowForDateWithOverrides(_selectedDate!, weekly, overrides)
        : null;
    if (win == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('booking_select_datetime'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final timeStr =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      final dayStart = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final sameDay = await appointmentsForDoctorDateRange(
        doctorUserId: widget.doctorId,
        rangeStartInclusiveLocal: dayStart,
        rangeEndExclusiveLocal: dayEnd,
      ).get();
      for (final doc in sameDay.docs) {
        final data = doc.data();
        final st =
            (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
        if (st == 'cancelled') continue;
        if (_bookingNormalizeStoredTime(
              (data[AppointmentFields.time] ?? '').toString(),
            ) ==
            timeStr) {
          if (!mounted) return;
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                s.translate('booking_slot_conflict'),
                style: const TextStyle(fontFamily: 'KurdishFont'),
              ),
            ),
          );
          return;
        }
      }

      // Always persist the doctor's display name from Firestore (users.fullName), not only UI cache.
      var doctorNameToSave = doctorDisplayName.trim();
      try {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.doctorId)
            .get();
        final fromServer =
            canonicalDoctorNameForStorage(doctorDoc.data() ?? <String, dynamic>{});
        if (fromServer.isNotEmpty) {
          doctorNameToSave = fromServer;
        }
      } catch (_) {
        /* use doctorDisplayName */
      }
      if (doctorNameToSave.isEmpty) {
        doctorNameToSave = s.translate('doctor_default');
      }

      var queueNumber = 1;
      try {
        final countAgg = await appointmentsForDoctorDateRange(
          doctorUserId: widget.doctorId,
          rangeStartInclusiveLocal: dayStart,
          rangeEndExclusiveLocal: dayEnd,
        ).count().get();
        queueNumber = (countAgg.count ?? 0) + 1;
      } catch (_) {
        queueNumber = (DateTime.now().millisecondsSinceEpoch % 90) + 10;
      }

      await FirebaseFirestore.instance.collection(AppointmentFields.collection).add({
        AppointmentFields.patientId: uid,
        AppointmentFields.doctorId: widget.doctorId,
        AppointmentFields.doctorName: doctorNameToSave,
        AppointmentFields.patientName: patientName,
        AppointmentFields.date: Timestamp.fromDate(_selectedDate!),
        AppointmentFields.time: timeStr,
        AppointmentFields.status: 'pending',
        AppointmentFields.queueNumber: queueNumber,
        AppointmentFields.createdAt: FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final dir = AppLocaleScope.of(ctx).textDirection;
          final s = S.of(ctx);
          return Directionality(
            textDirection: dir,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1D1E33),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                s.translate('booking_success_title'),
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFD9E2EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                s.translate('booking_success_body'),
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFF829AB1),
                  height: 1.4,
                ),
              ),
              actionsAlignment: MainAxisAlignment.start,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    s.translate('ok'),
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

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const MyAppointmentsScreen(),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('save_error_detail', params: {'error': '$e'}),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final appTextDir = AppLocaleScope.of(context).textDirection;
    final isRtlLayout = appTextDir == ui.TextDirection.rtl;
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    var doctorName = localizedDoctorFullName(widget.doctorData, lang);
    if (doctorName.isEmpty) {
      doctorName =
          (widget.doctorData['fullName'] ?? s.translate('doctor_default')).toString();
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
              .doc(widget.doctorId)
              .snapshots(),
          builder: (context, snap) {
            final merged = <String, dynamic>{
              ...widget.doctorData,
              if (snap.data?.data() != null) ...snap.data!.data()!,
            };
            final mergedSpecialty = (merged['specialty'] ?? specialty).toString();
            var doctorDisplayName = localizedDoctorFullName(merged, lang);
            if (doctorDisplayName.isEmpty) {
              doctorDisplayName = (merged['fullName'] ?? doctorName).toString();
            }
            final profileImageUrl = (merged['profileImageUrl'] ?? '').toString().trim();
            final weeklyRaw = merged['weekly_schedule'];
            final weeklyMap =
                weeklyRaw is Map<String, dynamic> ? weeklyRaw : null;
            final overrides = _scheduleOverridesMap(merged['schedule_date_overrides']);
            final hasSchedule = _hasAnyBookableWindow(weeklyMap, overrides);
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
                : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                    builder: (context, patientSnap) {
                      final patientName = (patientSnap.data?.data()?['fullName'] ??
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
                                        errorBuilder: (context, error, stackTrace) => Container(
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
                                          'value': translatedSpecialtyForFirestore(
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
                                        s.translate('doctor_profile_hospital_label'),
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
                                        s.translate('doctor_profile_address_label'),
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
                                      duration: const Duration(milliseconds: 420),
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
                                  side: const BorderSide(color: Color(0xFF42A5F5)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            KeyedSubtree(
                              key: _bookingSectionKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  if (!hasSchedule)
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1D1E33),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Text(
                                        s.translate('no_schedule_yet'),
                                        textAlign: TextAlign.start,
                                        style: const TextStyle(
                                          color: Color(0xFF829AB1),
                                          fontFamily: 'KurdishFont',
                                          height: 1.4,
                                        ),
                                      ),
                                    )
                                  else ...[
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _bookingBrandTitle,
                                            style: const TextStyle(
                                              color: Color(0xFFE8EEF4),
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.4,
                                              fontFamily: 'KurdishFont',
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: 44,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF42A5F5),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            s.translate('booking_title'),
                                            textAlign: TextAlign.start,
                                            style: const TextStyle(
                                              color: Color(0xFF9FB3C8),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'KurdishFont',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          s.translate('label_date'),
                                          textAlign: TextAlign.start,
                                          style: const TextStyle(
                                            color: Color(0xFF829AB1),
                                            fontSize: 13,
                                            fontFamily: 'KurdishFont',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          s.translate(
                                            'booking_calendar_legend_patient',
                                          ),
                                          textAlign: TextAlign.start,
                                          style: const TextStyle(
                                            color: Color(0xFF829AB1),
                                            fontSize: 11,
                                            fontFamily: 'KurdishFont',
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Builder(
                                          builder: (context) {
                                            final monthStart = _patientMonthStart(
                                              _patientCalendarFocusedDay,
                                            );
                                            final monthEnd =
                                                _patientMonthEndExclusive(
                                              _patientCalendarFocusedDay,
                                            );
                                            return StreamBuilder<
                                                QuerySnapshot<
                                                    Map<String, dynamic>>>(
                                              key: ValueKey(
                                                'pca-${widget.doctorId}-${monthStart.toIso8601String()}',
                                              ),
                                              stream: appointmentsForDoctorDateRange(
                                                doctorUserId: widget.doctorId,
                                                rangeStartInclusiveLocal:
                                                    monthStart,
                                                rangeEndExclusiveLocal:
                                                    monthEnd,
                                              ).snapshots(),
                                              builder: (context, apptSnap) {
                                                if (apptSnap.hasError) {
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback(
                                                    (_) =>
                                                        logFirestoreIndexHelpOnce(
                                                      apptSnap.error,
                                                      tag:
                                                          'patient_booking_appointments',
                                                      expectedCompositeIndexHint:
                                                          kAppointmentsDoctorDateStatusIndexHint,
                                                    ),
                                                  );
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    child: Text(
                                                      s.translate(
                                                        'doctors_load_error_detail',
                                                        params: {
                                                          'error':
                                                              '${apptSnap.error}',
                                                        },
                                                      ),
                                                      style: const TextStyle(
                                                        color: Colors.redAccent,
                                                        fontFamily:
                                                            'KurdishFont',
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return StreamBuilder<
                                                    QuerySnapshot<
                                                        Map<String, dynamic>>>(
                                                  key: ValueKey(
                                                    'pcb-${widget.doctorId}-${monthStart.toIso8601String()}',
                                                  ),
                                                  stream:
                                                      calendarBlocksForDoctorDateRange(
                                                    doctorUserId:
                                                        widget.doctorId,
                                                    rangeStartInclusiveLocal:
                                                        monthStart,
                                                    rangeEndExclusiveLocal:
                                                        monthEnd,
                                                  ).snapshots(),
                                                  builder: (context, blockSnap) {
                                                    if (blockSnap.hasError) {
                                                      WidgetsBinding.instance
                                                          .addPostFrameCallback(
                                                        (_) =>
                                                            logFirestoreIndexHelpOnce(
                                                          blockSnap.error,
                                                          tag:
                                                              'patient_booking_calendar_blocks',
                                                          expectedCompositeIndexHint:
                                                              kCalendarBlocksDoctorDateIndexHint,
                                                        ),
                                                      );
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(12),
                                                        child: Text(
                                                          s.translate(
                                                            'doctors_load_error_detail',
                                                            params: {
                                                              'error':
                                                                  '${blockSnap.error}',
                                                            },
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors
                                                                .redAccent,
                                                            fontFamily:
                                                                'KurdishFont',
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    final loading = (apptSnap
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting &&
                                                        !apptSnap.hasData) ||
                                                        (blockSnap
                                                                    .connectionState ==
                                                                ConnectionState
                                                                    .waiting &&
                                                            !blockSnap.hasData);
                                                    final appts =
                                                        apptSnap.data?.docs ??
                                                            [];
                                                    final blocks =
                                                        blockSnap.data?.docs ??
                                                            [];
                                                    final visuals =
                                                        _patientBookingVisualsForMonth(
                                                      focusedMonth:
                                                          _patientCalendarFocusedDay,
                                                      weekly: weeklyMap,
                                                      overrides: overrides,
                                                      apptDocs: appts,
                                                      blockDocs: blocks,
                                                      doctorProfile: merged,
                                                    );

                                                    if (!_patientCalendarPrimed &&
                                                        hasSchedule &&
                                                        apptSnap.hasData &&
                                                        blockSnap.hasData) {
                                                      WidgetsBinding.instance
                                                          .addPostFrameCallback(
                                                              (_) {
                                                        if (!mounted ||
                                                            _patientCalendarPrimed) {
                                                          return;
                                                        }
                                                        _patientCalendarPrimed =
                                                            true;
                                                        final first =
                                                            _firstPatientDateWithAvailability(
                                                          weeklyMap,
                                                          overrides,
                                                          appts,
                                                          blocks,
                                                          merged,
                                                        );
                                                        if (!mounted) return;
                                                        setState(() {
                                                          if (first != null) {
                                                            _selectedDate =
                                                                first;
                                                            _patientCalendarFocusedDay =
                                                                DateTime(
                                                              first.year,
                                                              first.month,
                                                              first.day,
                                                            );
                                                            _setSelectedDateSlots(
                                                              first,
                                                              weeklyMap,
                                                              overrides,
                                                              doctorProfile:
                                                                  merged,
                                                            );
                                                          }
                                                        });
                                                      });
                                                    }

                                                    final todayNorm =
                                                        DateTime(
                                                      DateTime.now().year,
                                                      DateTime.now().month,
                                                      DateTime.now().day,
                                                    );
                                                    final selectedWin =
                                                        _selectedDate != null
                                                            ? workingWindowForDateWithOverrides(
                                                                _selectedDate!,
                                                                weeklyMap,
                                                                overrides,
                                                              )
                                                            : null;
                                                    final selVis =
                                                        _selectedDate != null
                                                            ? visuals[DateTime(
                                                                _selectedDate!
                                                                    .year,
                                                                _selectedDate!
                                                                    .month,
                                                                _selectedDate!
                                                                    .day,
                                                              )]
                                                            : null;
                                                    final slotForSelected =
                                                        _selectedDate != null
                                                            ? effectiveAppointmentSlotMinutes(
                                                                dateOnly:
                                                                    _selectedDate!,
                                                                dateOverrides:
                                                                    overrides,
                                                                doctorUserData:
                                                                    merged,
                                                              )
                                                            : 30;
                                                    final slots = selectedWin !=
                                                            null
                                                        ? slotStartMinutesForWindow(
                                                            selectedWin
                                                                .startMinutes,
                                                            selectedWin
                                                                .endMinutes,
                                                            step:
                                                                slotForSelected,
                                                          )
                                                        : <int>[];
                                                    final showSlots =
                                                        _selectedDate !=
                                                                null &&
                                                            selVis ==
                                                                MasterDayVisual
                                                                    .hasAvailability &&
                                                            selectedWin != null;

                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        if (loading)
                                                          const Padding(
                                                            padding: EdgeInsets
                                                                .only(
                                                                    bottom: 8),
                                                            child:
                                                                LinearProgressIndicator(
                                                              minHeight: 2,
                                                              color: Color(
                                                                  0xFF42A5F5),
                                                            ),
                                                          ),
                                                        DecoratedBox(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFF12152A),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .white10),
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .fromLTRB(
                                                              6,
                                                              8,
                                                              6,
                                                              12,
                                                            ),
                                                            child:
                                                                TableCalendar<
                                                                    void>(
                                                              firstDay:
                                                                  DateTime.utc(
                                                                      2024,
                                                                      1,
                                                                      1),
                                                              lastDay:
                                                                  DateTime.utc(
                                                                      2035,
                                                                      12,
                                                                      31),
                                                              focusedDay:
                                                                  _patientCalendarFocusedDay,
                                                              rowHeight: 48,
                                                              daysOfWeekHeight:
                                                                  34,
                                                              selectedDayPredicate:
                                                                  (d) =>
                                                                      _selectedDate !=
                                                                          null &&
                                                                      isSameDay(
                                                                          _selectedDate!,
                                                                          d),
                                                              calendarFormat:
                                                                  CalendarFormat
                                                                      .month,
                                                              availableCalendarFormats: const {
                                                                CalendarFormat
                                                                    .month:
                                                                    'Month',
                                                              },
                                                              startingDayOfWeek:
                                                                  StartingDayOfWeek
                                                                      .saturday,
                                                              locale: Localizations
                                                                      .localeOf(
                                                                          context)
                                                                  .toLanguageTag(),
                                                              enabledDayPredicate:
                                                                  (d) {
                                                                final n = DateTime(
                                                                    d.year,
                                                                    d.month,
                                                                    d.day);
                                                                return !n.isBefore(
                                                                    todayNorm);
                                                              },
                                                              daysOfWeekStyle:
                                                                  DaysOfWeekStyle(
                                                                weekdayStyle:
                                                                    const TextStyle(
                                                                  color: Color(
                                                                      0xFF94A3B8),
                                                                  fontFamily:
                                                                      'KurdishFont',
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                                weekendStyle:
                                                                    const TextStyle(
                                                                  color: Color(
                                                                      0xFF94A3B8),
                                                                  fontFamily:
                                                                      'KurdishFont',
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              headerStyle:
                                                                  HeaderStyle(
                                                                formatButtonVisible:
                                                                    false,
                                                                titleCentered:
                                                                    true,
                                                                titleTextStyle:
                                                                    const TextStyle(
                                                                  color: Color(
                                                                      0xFFE8EEF4),
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontFamily:
                                                                      'KurdishFont',
                                                                ),
                                                                leftChevronIcon:
                                                                    const Icon(
                                                                  Icons
                                                                      .chevron_left_rounded,
                                                                  color: Color(
                                                                      0xFF42A5F5),
                                                                ),
                                                                rightChevronIcon:
                                                                    const Icon(
                                                                  Icons
                                                                      .chevron_right_rounded,
                                                                  color: Color(
                                                                      0xFF42A5F5),
                                                                ),
                                                              ),
                                                              calendarStyle:
                                                                  const CalendarStyle(
                                                                outsideDaysVisible:
                                                                    true,
                                                                markersMaxCount:
                                                                    0,
                                                                cellMargin:
                                                                    EdgeInsets
                                                                        .zero,
                                                                defaultDecoration:
                                                                    BoxDecoration(
                                                                        shape: BoxShape
                                                                            .rectangle),
                                                                weekendDecoration:
                                                                    BoxDecoration(
                                                                        shape: BoxShape
                                                                            .rectangle),
                                                                outsideDecoration:
                                                                    BoxDecoration(
                                                                        shape: BoxShape
                                                                            .rectangle),
                                                                todayDecoration:
                                                                    BoxDecoration(
                                                                        shape: BoxShape
                                                                            .rectangle),
                                                                selectedDecoration:
                                                                    BoxDecoration(
                                                                        shape: BoxShape
                                                                            .rectangle),
                                                                defaultTextStyle:
                                                                    TextStyle(
                                                                        fontSize:
                                                                            0.1,
                                                                        color: Colors
                                                                            .transparent),
                                                                weekendTextStyle:
                                                                    TextStyle(
                                                                        fontSize:
                                                                            0.1,
                                                                        color: Colors
                                                                            .transparent),
                                                                outsideTextStyle:
                                                                    TextStyle(
                                                                        fontSize:
                                                                            0.1,
                                                                        color: Colors
                                                                            .transparent),
                                                                todayTextStyle:
                                                                    TextStyle(
                                                                        fontSize:
                                                                            0.1,
                                                                        color: Colors
                                                                            .transparent),
                                                                selectedTextStyle:
                                                                    TextStyle(
                                                                        fontSize:
                                                                            0.1,
                                                                        color: Colors
                                                                            .transparent),
                                                              ),
                                                              onPageChanged:
                                                                  (f) {
                                                                setState(() =>
                                                                    _patientCalendarFocusedDay =
                                                                        f);
                                                              },
                                                              onDaySelected:
                                                                  (sel, foc) {
                                                                final key =
                                                                    DateTime(
                                                                  sel.year,
                                                                  sel.month,
                                                                  sel.day,
                                                                );
                                                                final v =
                                                                    visuals[
                                                                        key];
                                                                if (v ==
                                                                    MasterDayVisual
                                                                        .nonWorking) {
                                                                  ScaffoldMessenger
                                                                          .of(
                                                                              context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                      content:
                                                                          Text(
                                                                        s.translate(
                                                                            'booking_date_closed'),
                                                                        style: const TextStyle(
                                                                            fontFamily:
                                                                                'KurdishFont'),
                                                                      ),
                                                                    ),
                                                                  );
                                                                  return;
                                                                }
                                                                if (v ==
                                                                    MasterDayVisual
                                                                        .fullyBooked) {
                                                                  ScaffoldMessenger
                                                                          .of(
                                                                              context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                      content:
                                                                          Text(
                                                                        s.translate(
                                                                            'booking_date_fully_booked'),
                                                                        style: const TextStyle(
                                                                            fontFamily:
                                                                                'KurdishFont'),
                                                                      ),
                                                                    ),
                                                                  );
                                                                  return;
                                                                }
                                                                if (v ==
                                                                    MasterDayVisual
                                                                        .hasAvailability) {
                                                                  setState(
                                                                      () {
                                                                    _selectedDate =
                                                                        sel;
                                                                    _patientCalendarFocusedDay =
                                                                        foc;
                                                                    _setSelectedDateSlots(
                                                                      sel,
                                                                      weeklyMap,
                                                                      overrides,
                                                                      doctorProfile:
                                                                          merged,
                                                                    );
                                                                  });
                                                                }
                                                              },
                                                              calendarBuilders:
                                                                  CalendarBuilders(
                                                                defaultBuilder:
                                                                    (context,
                                                                        d,
                                                                        fd) {
                                                                  final k =
                                                                      DateTime(
                                                                    d.year,
                                                                    d.month,
                                                                    d.day,
                                                                  );
                                                                  final sel = _selectedDate !=
                                                                          null &&
                                                                      isSameDay(
                                                                          _selectedDate!,
                                                                          d);
                                                                  return _patientBookingDayCell(
                                                                    day: d,
                                                                    focusedMonth:
                                                                        fd,
                                                                    visual: visuals[
                                                                        k],
                                                                    isToday: isSameDay(
                                                                        d,
                                                                        DateTime
                                                                            .now()),
                                                                    isSelected:
                                                                        sel,
                                                                  );
                                                                },
                                                                todayBuilder:
                                                                    (context,
                                                                        d,
                                                                        fd) {
                                                                  final k =
                                                                      DateTime(
                                                                    d.year,
                                                                    d.month,
                                                                    d.day,
                                                                  );
                                                                  final sel = _selectedDate !=
                                                                          null &&
                                                                      isSameDay(
                                                                          _selectedDate!,
                                                                          d);
                                                                  return _patientBookingDayCell(
                                                                    day: d,
                                                                    focusedMonth:
                                                                        fd,
                                                                    visual: visuals[
                                                                        k],
                                                                    isToday:
                                                                        true,
                                                                    isSelected:
                                                                        sel,
                                                                  );
                                                                },
                                                                selectedBuilder:
                                                                    (context,
                                                                        d,
                                                                        fd) {
                                                                  final k =
                                                                      DateTime(
                                                                    d.year,
                                                                    d.month,
                                                                    d.day,
                                                                  );
                                                                  return _patientBookingDayCell(
                                                                    day: d,
                                                                    focusedMonth:
                                                                        fd,
                                                                    visual: visuals[
                                                                        k],
                                                                    isToday: isSameDay(
                                                                        d,
                                                                        DateTime
                                                                            .now()),
                                                                    isSelected:
                                                                        true,
                                                                  );
                                                                },
                                                                outsideBuilder:
                                                                    (context,
                                                                        d,
                                                                        fd) {
                                                                  final k =
                                                                      DateTime(
                                                                    d.year,
                                                                    d.month,
                                                                    d.day,
                                                                  );
                                                                  final sel = _selectedDate !=
                                                                          null &&
                                                                      isSameDay(
                                                                          _selectedDate!,
                                                                          d);
                                                                  return _patientBookingDayCell(
                                                                    day: d,
                                                                    focusedMonth:
                                                                        fd,
                                                                    visual: visuals[
                                                                        k],
                                                                    isToday: isSameDay(
                                                                        d,
                                                                        DateTime
                                                                            .now()),
                                                                    isSelected:
                                                                        sel,
                                                                    isOutside:
                                                                        true,
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        if (showSlots) ...[
                                              const SizedBox(height: 18),
                                              Text(
                                                s.translate('label_times'),
                                                textAlign: TextAlign.start,
                                                style: const TextStyle(
                                                  color: Color(0xFF829AB1),
                                                  fontSize: 13,
                                                  fontFamily: 'KurdishFont',
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                s.translate(
                                                  'time_window',
                                                  params: {
                                                    'start': _formatMinutes(
                                                      selectedWin.startMinutes,
                                                    ),
                                                    'end': _formatMinutes(
                                                      selectedWin.endMinutes,
                                                    ),
                                                  },
                                                ),
                                                textAlign: TextAlign.start,
                                                style: const TextStyle(
                                                  color: Color(0xFF829AB1),
                                                  fontSize: 12,
                                                  fontFamily: 'KurdishFont',
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              if (slots.isEmpty)
                                                Text(
                                                  s.translate('no_times_set'),
                                                  textAlign: TextAlign.start,
                                                  style: const TextStyle(
                                                    color: Color(0xFF829AB1),
                                                    fontFamily: 'KurdishFont',
                                                  ),
                                                )
                                              else if (_selectedDate == null)
                                                Text(
                                                  s.translate(
                                                    'booking_select_datetime',
                                                  ),
                                                  textAlign: TextAlign.start,
                                                  style: const TextStyle(
                                                    color: Color(0xFF829AB1),
                                                    fontFamily: 'KurdishFont',
                                                  ),
                                                )
                                              else
                                                _BookedTimeSlotPicker(
                                                  doctorId: widget.doctorId,
                                                  selectedDate: _selectedDate!,
                                                  slots: slots,
                                                  selectedMinutes:
                                                      _selectedTime != null
                                                          ? _toMinutes(
                                                              _selectedTime!,
                                                            )
                                                          : null,
                                                  isRtlLayout: isRtlLayout,
                                                  onMinutesChanged: (m) {
                                                    setState(() {
                                                      _selectedTime = m != null
                                                          ? _timeFromMinutes(m)
                                                          : null;
                                                    });
                                                  },
                                                ),
                                              const SizedBox(height: 22),
                                              ElevatedButton(
                                                onPressed: _saving
                                                    ? null
                                                    : () => _confirmAppointment(
                                                          patientName,
                                                          doctorDisplayName,
                                                          weeklyMap,
                                                          overrides,
                                                        ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF42A5F5),
                                                  foregroundColor:
                                                      const Color(0xFF102A43),
                                                  minimumSize: const Size(
                                                    double.infinity,
                                                    54,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      14,
                                                    ),
                                                  ),
                                                ),
                                                child: _saving
                                                    ? const SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2.2,
                                                        ),
                                                      )
                                                    : Text(
                                                        s.translate(
                                                          'confirm_booking',
                                                        ),
                                                        style: const TextStyle(
                                                          fontFamily:
                                                              'KurdishFont',
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                              ),
                                            ],
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
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

/// Live Firestore availability for one doctor + calendar day; disables taken slots.
class _BookedTimeSlotPicker extends StatefulWidget {
  const _BookedTimeSlotPicker({
    required this.doctorId,
    required this.selectedDate,
    required this.slots,
    required this.selectedMinutes,
    required this.onMinutesChanged,
    required this.isRtlLayout,
  });

  final String doctorId;
  final DateTime selectedDate;
  final List<int> slots;
  final int? selectedMinutes;
  final ValueChanged<int?> onMinutesChanged;
  final bool isRtlLayout;

  @override
  State<_BookedTimeSlotPicker> createState() => _BookedTimeSlotPickerState();
}

class _BookedTimeSlotPickerState extends State<_BookedTimeSlotPicker> {
  Set<String>? _prevBooked;
  String? _sessionKey;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final start = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final end = start.add(const Duration(days: 1));
    final session = '${widget.doctorId}|${start.toIso8601String()}';
    if (_sessionKey != session) {
      _sessionKey = session;
      _prevBooked = null;
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appointmentsForDoctorDateRange(
        doctorUserId: widget.doctorId,
        rangeStartInclusiveLocal: start,
        rangeEndExclusiveLocal: end,
      ).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => logFirestoreIndexHelpOnce(
              snap.error,
              tag: 'patient_booking_day_slots',
              expectedCompositeIndexHint:
                  kAppointmentsDoctorDateStatusIndexHint,
            ),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.translate('doctors_load_error_detail', params: {'error': '${snap.error}'}),
              style: const TextStyle(
                color: Colors.redAccent,
                fontFamily: 'KurdishFont',
                fontSize: 12,
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF42A5F5),
                ),
              ),
            ),
          );
        }

        final booked = _bookingBookedTimeKeysFromDocs(snap.data?.docs ?? []);

        final selectedStr = widget.selectedMinutes != null
            ? _bookingTimeKeyFromMinutes(widget.selectedMinutes!)
            : null;
        final selectedIsBooked =
            selectedStr != null && booked.contains(selectedStr);

        if (selectedIsBooked) {
          int? pick;
          for (final m in widget.slots) {
            if (!booked.contains(_bookingTimeKeyFromMinutes(m))) {
              pick = m;
              break;
            }
          }
          final shouldUpdate = pick != widget.selectedMinutes;
          if (shouldUpdate) {
            final prev = _prevBooked;
            final showTakenSnack =
                prev != null && !prev.contains(selectedStr) && booked.contains(selectedStr);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              widget.onMinutesChanged(pick);
              if (showTakenSnack && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      S.of(context).translate('booking_slot_just_taken'),
                      style: const TextStyle(fontFamily: 'KurdishFont'),
                    ),
                  ),
                );
              }
            });
          }
        }

        _prevBooked = Set<String>.from(booked);

        const blueFill = Color(0xFF1565C0);
        const blueBorder = Color(0xFF42A5F5);
        const blueLabel = Color(0xFFE3F2FD);
        const bookedFill = Color(0xFF2A2D35);
        const bookedBorder = Color(0xFF6B7280);
        const bookedLabel = Color(0xFF9CA3AF);
        const availFill = Color(0xFF0F3D28);
        const availBorder = Color(0xFF22C55E);
        const availLabel = Color(0xFFBBF7D0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: widget.isRtlLayout ? WrapAlignment.end : WrapAlignment.start,
              spacing: 8,
              runSpacing: 8,
              children: widget.slots.map((m) {
                final timeStr = _bookingTimeKeyFromMinutes(m);
                final isBooked = booked.contains(timeStr);
                final isSelected =
                    !isBooked && widget.selectedMinutes != null && widget.selectedMinutes == m;

                final tile = Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isBooked ? null : () => widget.onMinutesChanged(m),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isBooked
                            ? bookedFill
                            : isSelected
                                ? blueFill
                                : availFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isBooked
                              ? bookedBorder
                              : isSelected
                                  ? blueBorder
                                  : availBorder,
                          width: isBooked || isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          fontFamily: 'KurdishFont',
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 14,
                          color: isBooked
                              ? bookedLabel
                              : isSelected
                                  ? blueLabel
                                  : availLabel,
                        ),
                      ),
                    ),
                  ),
                );

                if (isBooked) {
                  return Tooltip(
                    message: s.translate('booking_slot_booked_hint'),
                    child: tile,
                  );
                }
                return tile;
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              s.translate('booking_slot_legend'),
              textAlign: TextAlign.start,
              style: const TextStyle(
                color: Color(0xFF829AB1),
                fontSize: 11,
                fontFamily: 'KurdishFont',
                height: 1.35,
              ),
            ),
          ],
        );
      },
    );
  }
}
