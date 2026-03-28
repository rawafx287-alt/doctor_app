import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../calendar/calendar_slot_logic.dart';
import '../firestore/appointment_queries.dart';
import '../firestore/calendar_block_queries.dart';
import '../models/doctor_localized_content.dart';

Map<String, dynamic>? _weeklyScheduleFromDoctorData(Map<String, dynamic>? data) {
  if (data == null) return null;
  final w = data['weekly_schedule'];
  if (w is! Map) return null;
  return Map<String, dynamic>.from(
    w.map((k, v) => MapEntry(k.toString(), v)),
  );
}

Map<String, dynamic>? _scheduleOverridesFromDoctorData(Map<String, dynamic>? data) {
  if (data == null) return null;
  final raw = data['schedule_date_overrides'];
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(
    raw.map((k, v) => MapEntry(k.toString(), v)),
  );
}

/// Shared Firestore write for a patient booking (same shape as [DoctorDetailsScreen]).
Future<String?> createPatientAppointment({
  required String doctorId,
  required DateTime dateLocal,
  required int slotStartMinutes,
  required String patientName,
  String doctorDisplayFallback = '',
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return 'login_required';

  final timeStr = formatSlotMinutesKey(slotStartMinutes);
  final dayStart = DateTime(dateLocal.year, dateLocal.month, dateLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  try {
    final doctorDoc =
        await FirebaseFirestore.instance.collection('users').doc(doctorId).get();
    final dd = doctorDoc.data();
    final weekly = _weeklyScheduleFromDoctorData(dd);
    final overrides = _scheduleOverridesFromDoctorData(dd);
    if (workingWindowForDateWithOverrides(dayStart, weekly, overrides) == null) {
      return 'booking_date_closed';
    }
    final blockSnap = await calendarBlocksForDoctorDateRange(
      doctorUserId: doctorId,
      rangeStartInclusiveLocal: dayStart,
      rangeEndExclusiveLocal: dayEnd,
    ).get();
    final blockMaps = blockSnap.docs.map((e) => e.data()).toList();
    if (calendarDayHasIsClosedFlag(blocksForCalendarDay(dayStart, blockMaps))) {
      return 'booking_date_closed';
    }
  } catch (_) {
    // Firestore/read failure: do not block booking here; confirm flow validates when possible.
  }

  final sameDay = await appointmentsForDoctorDateRange(
    doctorUserId: doctorId,
    rangeStartInclusiveLocal: dayStart,
    rangeEndExclusiveLocal: dayEnd,
  ).get();

  for (final doc in sameDay.docs) {
    final data = doc.data();
    final st =
        (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
    if (st == 'cancelled') continue;
    final t = (data[AppointmentFields.time] ?? '').toString().trim();
    if (t.isEmpty) continue;
    final parts = t.split(':');
    if (parts.length < 2) continue;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final mi = int.tryParse(parts[1].trim()) ?? 0;
    final norm = '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
    if (norm == timeStr) return 'booking_slot_conflict';
  }

  var doctorNameToSave = doctorDisplayFallback.trim();
  try {
    final doctorDoc = await FirebaseFirestore.instance.collection('users').doc(doctorId).get();
    final fromServer = canonicalDoctorNameForStorage(doctorDoc.data() ?? <String, dynamic>{});
    if (fromServer.isNotEmpty) doctorNameToSave = fromServer;
  } catch (_) {}

  var queueNumber = 1;
  try {
    final countAgg = await appointmentsForDoctorDateRange(
      doctorUserId: doctorId,
      rangeStartInclusiveLocal: dayStart,
      rangeEndExclusiveLocal: dayEnd,
    ).count().get();
    queueNumber = (countAgg.count ?? 0) + 1;
  } catch (_) {
    queueNumber = (DateTime.now().millisecondsSinceEpoch % 90) + 10;
  }

  await FirebaseFirestore.instance.collection(AppointmentFields.collection).add({
    AppointmentFields.patientId: uid,
    AppointmentFields.doctorId: doctorId,
    AppointmentFields.doctorName: doctorNameToSave.isEmpty ? '—' : doctorNameToSave,
    AppointmentFields.patientName:
        patientName.trim().isEmpty ? '—' : patientName.trim(),
    AppointmentFields.date: Timestamp.fromDate(dayStart),
    AppointmentFields.time: timeStr,
    AppointmentFields.status: 'pending',
    AppointmentFields.queueNumber: queueNumber,
    AppointmentFields.createdAt: FieldValue.serverTimestamp(),
  });

  return null;
}

/// Staff-created appointment (walk-in / phone). [patientId] may be empty.
Future<String?> createStaffAppointment({
  required String doctorId,
  required DateTime dateLocal,
  required int slotStartMinutes,
  required String patientName,
  required String createdByUid,
  String patientId = '',
}) async {
  final timeStr = formatSlotMinutesKey(slotStartMinutes);
  final dayStart = DateTime(dateLocal.year, dateLocal.month, dateLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final sameDay = await appointmentsForDoctorDateRange(
    doctorUserId: doctorId,
    rangeStartInclusiveLocal: dayStart,
    rangeEndExclusiveLocal: dayEnd,
  ).get();

  for (final doc in sameDay.docs) {
    final data = doc.data();
    final st =
        (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
    if (st == 'cancelled') continue;
    final t = (data[AppointmentFields.time] ?? '').toString().trim();
    if (t.isEmpty) continue;
    final parts = t.split(':');
    if (parts.length < 2) continue;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final mi = int.tryParse(parts[1].trim()) ?? 0;
    final norm = '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
    if (norm == timeStr) return 'booking_slot_conflict';
  }

  var doctorNameToSave = '';
  try {
    final doctorDoc = await FirebaseFirestore.instance.collection('users').doc(doctorId).get();
    doctorNameToSave = canonicalDoctorNameForStorage(doctorDoc.data() ?? <String, dynamic>{});
  } catch (_) {}

  var queueNumber = 1;
  try {
    final countAgg = await appointmentsForDoctorDateRange(
      doctorUserId: doctorId,
      rangeStartInclusiveLocal: dayStart,
      rangeEndExclusiveLocal: dayEnd,
    ).count().get();
    queueNumber = (countAgg.count ?? 0) + 1;
  } catch (_) {
    queueNumber = (DateTime.now().millisecondsSinceEpoch % 90) + 10;
  }

  await FirebaseFirestore.instance.collection(AppointmentFields.collection).add({
    AppointmentFields.patientId: patientId,
    AppointmentFields.doctorId: doctorId,
    AppointmentFields.doctorName: doctorNameToSave.isEmpty ? '—' : doctorNameToSave,
    AppointmentFields.patientName:
        patientName.trim().isEmpty ? '—' : patientName.trim(),
    AppointmentFields.date: Timestamp.fromDate(dayStart),
    AppointmentFields.time: timeStr,
    AppointmentFields.status: 'pending',
    AppointmentFields.queueNumber: queueNumber,
    AppointmentFields.createdAt: FieldValue.serverTimestamp(),
    AppointmentFields.createdByStaff: createdByUid,
  });

  return null;
}
