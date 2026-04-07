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
  final normalized = normalizeScheduleDateOverridesMap(data['schedule_date_overrides']);
  if (normalized.isEmpty) return null;
  return normalized;
}

Set<String> _bookedTimeKeysFromAppointmentDocs(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final set = <String>{};
  for (final doc in docs) {
    final data = doc.data();
    if (!appointmentDocBlocksSlotForNewPatientBooking(data)) continue;
    final t = (data[AppointmentFields.time] ?? '').toString().trim();
    if (t.isEmpty) continue;
    final parts = t.split(':');
    if (parts.length < 2) continue;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final mi = int.tryParse(parts[1].trim()) ?? 0;
    set.add('${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}');
  }
  return set;
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

  final did = doctorId.trim();
  final timeStr = formatSlotMinutesKey(slotStartMinutes);
  final dayStart = DateTime(dateLocal.year, dateLocal.month, dateLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  Map<String, dynamic>? dd;
  var blockMaps = <Map<String, dynamic>>[];
  var blockDocList = <DocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? serverDaySnap;
  try {
    final doctorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(did)
        .get(const GetOptions(source: Source.server));
    dd = doctorDoc.data();
    final daySnap = await fetchCalendarDayStatusDocumentFromServer(
      dayStart,
      doctorUserId: did,
    );
    serverDaySnap = daySnap;
    final blockSnap = await calendarBlocksForDoctorDateRange(
      doctorUserId: did,
      rangeStartInclusiveLocal: dayStart,
      rangeEndExclusiveLocal: dayEnd,
    ).get(const GetOptions(source: Source.server));
    blockDocList = List<DocumentSnapshot<Map<String, dynamic>>>.from(blockSnap.docs);
    if (daySnap.exists &&
        !blockDocList.any((d) => d.id.trim() == daySnap.id.trim())) {
      blockDocList = [...blockDocList, daySnap];
    }
    blockMaps = blockDocList
        .where((e) => e.exists)
        .map((e) => e.data())
        .whereType<Map<String, dynamic>>()
        .toList();
  } catch (_) {
    // Continue with empty blocks; sequential check may be skipped if window unknown.
  }

  final weekly = _weeklyScheduleFromDoctorData(dd);
  final overrides = _scheduleOverridesFromDoctorData(dd);
  if (serverDaySnap == null ||
      patientDayGateFromDayStatusDocument(serverDaySnap, did) !=
          PatientCalendarDayGate.open) {
    return 'booking_date_closed';
  }
  final dayBlocks = blocksForCalendarDay(dayStart, blockMaps);
  final win = workingWindowForDateWithOverrides(dayStart, weekly, overrides);
  if (win == null) return 'booking_date_closed';
  if (calendarDayHasIsClosedFlag(dayBlocks)) {
    return 'booking_date_closed';
  }
  final step = appointmentSlotMinutesForDateWithAllBlocks(dayStart, blockMaps);
  final allowedStarts = slotStartMinutesForWindow(
    win.startMinutes,
    win.endMinutes,
    step: step,
  );
  if (!allowedStarts.contains(slotStartMinutes)) {
    return 'booking_slot_invalid';
  }

  final sameDay = await appointmentsForDoctorDateRange(
    doctorUserId: did,
    rangeStartInclusiveLocal: dayStart,
    rangeEndExclusiveLocal: dayEnd,
  ).get();

  final bookedKeys = _bookedTimeKeysFromAppointmentDocs(sameDay.docs);
  final nextSequential = earliestSequentialFreeSlotStartMinutes(allowedStarts, bookedKeys);
  if (nextSequential == null) return 'booking_date_fully_booked';
  if (slotStartMinutes != nextSequential) return 'booking_sequential_must_pick_first';

  for (final doc in sameDay.docs) {
    final data = doc.data();
    if (!appointmentDocBlocksSlotForNewPatientBooking(data)) continue;
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
    final fromServer =
        canonicalDoctorNameForStorage(dd ?? <String, dynamic>{});
    if (fromServer.isNotEmpty) doctorNameToSave = fromServer;
  } catch (_) {}

  final queueNumber = await nextDailyQueueNumberForDoctor(
    doctorUserId: did,
    dayStartLocal: dayStart,
  );

  await FirebaseFirestore.instance.collection(AppointmentFields.collection).add({
    AppointmentFields.patientId: uid,
    AppointmentFields.userId: uid,
    AppointmentFields.doctorId: did,
    AppointmentFields.doctorName: doctorNameToSave.isEmpty ? '—' : doctorNameToSave,
    AppointmentFields.patientName:
        patientName.trim().isEmpty ? '—' : patientName.trim(),
    AppointmentFields.date: Timestamp.fromDate(dayStart),
    AppointmentFields.time: timeStr,
    AppointmentFields.status: 'pending',
    AppointmentFields.isBooked: true,
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
    if (!appointmentDocBlocksSlotForNewPatientBooking(data)) continue;
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

  final queueNumber = await nextDailyQueueNumberForDoctor(
    doctorUserId: doctorId,
    dayStartLocal: dayStart,
  );

  await FirebaseFirestore.instance.collection(AppointmentFields.collection).add({
    AppointmentFields.patientId: patientId,
    if (patientId.trim().isNotEmpty) AppointmentFields.userId: patientId.trim(),
    AppointmentFields.doctorId: doctorId,
    AppointmentFields.doctorName: doctorNameToSave.isEmpty ? '—' : doctorNameToSave,
    AppointmentFields.patientName:
        patientName.trim().isEmpty ? '—' : patientName.trim(),
    AppointmentFields.date: Timestamp.fromDate(dayStart),
    AppointmentFields.time: timeStr,
    AppointmentFields.status: 'pending',
    AppointmentFields.isBooked: true,
    AppointmentFields.queueNumber: queueNumber,
    AppointmentFields.createdAt: FieldValue.serverTimestamp(),
    AppointmentFields.createdByStaff: createdByUid,
  });

  return null;
}
