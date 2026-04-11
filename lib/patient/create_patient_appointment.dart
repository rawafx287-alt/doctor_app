import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../calendar/calendar_slot_logic.dart';
import '../firestore/appointment_queries.dart';
import '../firestore/available_days_queries.dart';
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

/// On **today** (local), drops slot starts that are not strictly after [DateTime.now].
List<int> _futureSlotStartMinutesForPatientDay({
  required DateTime dayStart,
  required List<int> windowStarts,
}) {
  final nowClock = DateTime.now();
  final todayStart = DateTime(nowClock.year, nowClock.month, nowClock.day);
  if (dayStart.year != todayStart.year ||
      dayStart.month != todayStart.month ||
      dayStart.day != todayStart.day) {
    return windowStarts;
  }
  return windowStarts
      .where((m) {
        final slotDt = DateTime(
          dayStart.year,
          dayStart.month,
          dayStart.day,
          m ~/ 60,
          m % 60,
        );
        return slotDt.isAfter(nowClock);
      })
      .toList();
}

Set<String> _bookedTimeKeysFromAppointmentDocs(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final set = <String>{};
  for (final doc in docs) {
    final data = doc.data();
    if (!appointmentSlotCountsAsBookedOnPatientSchedule(data)) continue;
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
  final allowedStartsEffective = _futureSlotStartMinutesForPatientDay(
    dayStart: dayStart,
    windowStarts: allowedStarts,
  );
  if (allowedStartsEffective.isEmpty) {
    return 'booking_date_fully_booked';
  }
  if (!allowedStartsEffective.contains(slotStartMinutes)) {
    return 'booking_slot_invalid';
  }

  final sameDay = await appointmentsForDoctorDateRange(
    doctorUserId: did,
    rangeStartInclusiveLocal: dayStart,
    rangeEndExclusiveLocal: dayEnd,
  ).get();

  final bookedKeys = _bookedTimeKeysFromAppointmentDocs(sameDay.docs);
  final nextSequential = earliestSequentialFreeSlotStartMinutes(
    allowedStartsEffective,
    bookedKeys,
  );
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

  final slotTs = appointmentTimestampFromLocalDayAndTimeKey(dayStart, timeStr);
  await FirebaseFirestore.instance.collection(AppointmentFields.collection).add({
    AppointmentFields.patientId: uid,
    AppointmentFields.userId: uid,
    AppointmentFields.doctorId: did,
    AppointmentFields.doctorName: doctorNameToSave.isEmpty ? '—' : doctorNameToSave,
    AppointmentFields.patientName:
        patientName.trim().isEmpty ? '—' : patientName.trim(),
    AppointmentFields.date: Timestamp.fromDate(dayStart),
    AppointmentFields.time: timeStr,
    'dateTime': slotTs,
    AppointmentFields.appointmentDateTime: slotTs,
    AppointmentFields.status: kAppointmentStatusBooked,
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

  final slotTs = appointmentTimestampFromLocalDayAndTimeKey(dayStart, timeStr);
  await FirebaseFirestore.instance.collection(AppointmentFields.collection).add({
    AppointmentFields.patientId: patientId,
    if (patientId.trim().isNotEmpty) AppointmentFields.userId: patientId.trim(),
    AppointmentFields.doctorId: doctorId,
    AppointmentFields.doctorName: doctorNameToSave.isEmpty ? '—' : doctorNameToSave,
    AppointmentFields.patientName:
        patientName.trim().isEmpty ? '—' : patientName.trim(),
    AppointmentFields.date: Timestamp.fromDate(dayStart),
    AppointmentFields.time: timeStr,
    'dateTime': slotTs,
    AppointmentFields.appointmentDateTime: slotTs,
    AppointmentFields.status: kAppointmentStatusBooked,
    AppointmentFields.isBooked: true,
    AppointmentFields.queueNumber: queueNumber,
    AppointmentFields.createdAt: FieldValue.serverTimestamp(),
    AppointmentFields.createdByStaff: createdByUid,
  });

  return null;
}

/// Patient self-books the tapped schedule slot (no sequential “first free” rule).
/// Claims an `available` row at [slotStartMinutes] or creates a new appointment.
Future<String?> bookPatientAppointmentAtScheduleSlot({
  required String doctorId,
  required DateTime dateLocal,
  required int slotStartMinutes,
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
  } catch (_) {}

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
  final allowedStartsEffective = _futureSlotStartMinutesForPatientDay(
    dayStart: dayStart,
    windowStarts: allowedStarts,
  );
  if (allowedStartsEffective.isEmpty) {
    return 'booking_date_fully_booked';
  }
  if (!allowedStartsEffective.contains(slotStartMinutes)) {
    return 'schedule_booking_past_slot';
  }

  final merged = await fetchMergedDoctorAppointmentDocsForLocalDay(
    doctorUserId: did,
    dayLocal: dayStart,
  );

  for (final doc in merged) {
    final data = doc.data();
    if (!appointmentDocBlocksSlotForNewPatientBooking(data)) continue;
    final t = normalizeAppointmentTimeToHhMm(data[AppointmentFields.time]);
    if (t == timeStr) return 'booking_slot_conflict';
  }

  DocumentSnapshot<Map<String, dynamic>>? claimSnap;
  for (final doc in merged) {
    final data = doc.data();
    final st =
        (data[AppointmentFields.status] ?? '').toString().trim().toLowerCase();
    if (st != 'available') continue;
    final t = normalizeAppointmentTimeToHhMm(data[AppointmentFields.time]);
    if (t == timeStr) {
      claimSnap = doc;
      break;
    }
  }

  final userSnap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final ud = userSnap.data() ?? <String, dynamic>{};
  var patientName = (ud['displayName'] ?? ud['name'] ?? ud['full_name'] ?? '')
      .toString()
      .trim();
  if (patientName.isEmpty) {
    patientName =
        (FirebaseAuth.instance.currentUser?.displayName ?? '').trim();
  }
  if (patientName.isEmpty) {
    patientName =
        (FirebaseAuth.instance.currentUser?.email ?? '—').toString().trim();
  }

  var doctorNameToSave = '';
  try {
    final fromServer =
        canonicalDoctorNameForStorage(dd ?? <String, dynamic>{});
    if (fromServer.isNotEmpty) doctorNameToSave = fromServer;
  } catch (_) {}

  if (claimSnap != null) {
    final claimRef = claimSnap.reference;
    final slotTs = appointmentTimestampFromLocalDayAndTimeKey(dayStart, timeStr);
    for (var attempt = 0; attempt < 4; attempt++) {
      final queueNumber = await smallestAvailableQueueNumberForDoctor(
        doctorUserId: did,
        dayStartLocal: dayStart,
      );
      try {
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final fresh = await tx.get(claimRef);
          if (!fresh.exists) {
            throw StateError('claim_missing');
          }
          final fd = fresh.data()!;
          final fst =
              (fd[AppointmentFields.status] ?? '').toString().trim().toLowerCase();
          if (fst != 'available') {
            throw StateError('claim_taken');
          }
          if (normalizeAppointmentTimeToHhMm(fd[AppointmentFields.time]) !=
              timeStr) {
            throw StateError('claim_time');
          }
          tx.update(claimRef, {
            AppointmentFields.patientId: uid,
            AppointmentFields.userId: uid,
            AppointmentFields.patientName:
                patientName.isEmpty ? '—' : patientName,
            AppointmentFields.doctorName:
                doctorNameToSave.isEmpty ? '—' : doctorNameToSave,
            AppointmentFields.status: kAppointmentStatusBooked,
            AppointmentFields.isBooked: true,
            AppointmentFields.queueNumber: queueNumber,
            'dateTime': slotTs,
            AppointmentFields.appointmentDateTime: slotTs,
            AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
          });
        });
        return null;
      } catch (_) {
        if (attempt >= 3) return 'booking_slot_just_taken';
        await Future<void>.delayed(
          Duration(milliseconds: 60 * (attempt + 1)),
        );
      }
    }
    return 'booking_slot_conflict';
  }

  final queueNumber = await smallestAvailableQueueNumberForDoctor(
    doctorUserId: did,
    dayStartLocal: dayStart,
  );

  final slotTs = appointmentTimestampFromLocalDayAndTimeKey(dayStart, timeStr);
  await FirebaseFirestore.instance.collection(AppointmentFields.collection).add({
    AppointmentFields.patientId: uid,
    AppointmentFields.userId: uid,
    AppointmentFields.doctorId: did,
    AppointmentFields.doctorName: doctorNameToSave.isEmpty ? '—' : doctorNameToSave,
    AppointmentFields.patientName: patientName.isEmpty ? '—' : patientName,
    AppointmentFields.date: Timestamp.fromDate(dayStart),
    AppointmentFields.time: timeStr,
    'dateTime': slotTs,
    AppointmentFields.appointmentDateTime: slotTs,
    AppointmentFields.status: kAppointmentStatusBooked,
    AppointmentFields.isBooked: true,
    AppointmentFields.queueNumber: queueNumber,
    AppointmentFields.createdAt: FieldValue.serverTimestamp(),
  });

  return null;
}
