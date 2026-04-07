import 'package:cloud_firestore/cloud_firestore.dart';

import 'appointment_queries.dart';

/// [available_days] — doctor-published dates patients can book (capacity per day).
abstract final class AvailableDayFields {
  static const String collection = 'available_days';

  /// Must match [AppointmentFields.doctorId] (capital **I** in `Id`).
  static const String doctorId = 'doctorId';

  /// [Timestamp] at local midnight for that calendar day.
  static const String date = 'date';

  static const String maxAppointments = 'maxAppointments';
  static const String currentBookings = 'currentBookings';

  /// When true, patients may book; closed days stay in Firestore with [isOpen] false.
  static const String isOpen = 'isOpen';

  /// Clinic opening time for that day, **`HH:mm`** 24h (e.g. `16:00`).
  static const String startTime = 'startTime';

  /// Slot length in minutes (e.g. 15, 30, 45, 60).
  static const String appointmentDuration = 'appointmentDuration';

  /// Last bookable window end, **`HH:mm`** 24h (closing time).
  static const String closingTime = 'closingTime';
}

/// Defaults for documents created before scheduling fields existed.
const String kDefaultAvailableDayStartTime = '09:00';
const String kDefaultAvailableDayClosingTime = '20:00';
const int kDefaultAppointmentDurationMinutes = 30;

/// Normalize [raw] to `HH:mm` or return [kDefaultAvailableDayStartTime].
String normalizeAvailableDayStartTimeHhMm(dynamic raw) {
  if (raw == null) return kDefaultAvailableDayStartTime;
  final s = raw.toString().trim();
  final parts = s.split(':');
  if (parts.length != 2) return kDefaultAvailableDayStartTime;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null) return kDefaultAvailableDayStartTime;
  if (h < 0 || h > 23 || m < 0 || m > 59) {
    return kDefaultAvailableDayStartTime;
  }
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

int normalizeAppointmentDurationMinutes(dynamic raw) {
  final n = (raw is num) ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  if (n == null || n < 1) return kDefaultAppointmentDurationMinutes;
  if (n > 24 * 60) return 24 * 60;
  return n;
}

String normalizeAvailableDayClosingTimeHhMm(dynamic raw) {
  if (raw == null) return kDefaultAvailableDayClosingTime;
  final s = raw.toString().trim();
  final parts = s.split(':');
  if (parts.length != 2) return kDefaultAvailableDayClosingTime;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null) return kDefaultAvailableDayClosingTime;
  if (h < 0 || h > 23 || m < 0 || m > 59) {
    return kDefaultAvailableDayClosingTime;
  }
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// All slot **start** times from opening through closing − duration (inclusive window).
List<DateTime> generatedSlotStartsForDay({
  required DateTime dateOnly,
  required String startTimeHhMm,
  required String closingTimeHhMm,
  required int durationMinutes,
}) {
  final dur = durationMinutes.clamp(1, 24 * 60);
  final sp = startTimeHhMm.trim().split(':');
  final ep = closingTimeHhMm.trim().split(':');
  if (sp.length != 2 || ep.length != 2) return [];
  final sh = int.tryParse(sp[0].trim());
  final sm = int.tryParse(sp[1].trim());
  final eh = int.tryParse(ep[0].trim());
  final em = int.tryParse(ep[1].trim());
  if (sh == null || sm == null || eh == null || em == null) return [];
  final startDt = DateTime(dateOnly.year, dateOnly.month, dateOnly.day, sh, sm);
  final endBoundary =
      DateTime(dateOnly.year, dateOnly.month, dateOnly.day, eh, em);
  if (!endBoundary.isAfter(startDt)) return [];
  var cursor = startDt;
  final out = <DateTime>[];
  while (true) {
    final slotEnd = cursor.add(Duration(minutes: dur));
    if (slotEnd.isAfter(endBoundary)) break;
    out.add(cursor);
    cursor = cursor.add(Duration(minutes: dur));
  }
  return out;
}

int maxBookableSlotsForDayData(Map<String, dynamic> data, DateTime dateOnly) {
  final start = normalizeAvailableDayStartTimeHhMm(data[AvailableDayFields.startTime]);
  final end = normalizeAvailableDayClosingTimeHhMm(data[AvailableDayFields.closingTime]);
  final dur = normalizeAppointmentDurationMinutes(
    data[AvailableDayFields.appointmentDuration],
  );
  return generatedSlotStartsForDay(
    dateOnly: dateOnly,
    startTimeHhMm: start,
    closingTimeHhMm: end,
    durationMinutes: dur,
  ).length;
}

/// Next patient's slot: opening + [bookingIndex] × duration (0-based).
DateTime? assignedSlotLocal({
  required DateTime dateOnly,
  required String startTimeHhMm,
  required int durationMinutes,
  required int bookingIndexZeroBased,
}) {
  final parts = startTimeHhMm.trim().split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  if (durationMinutes < 1) return null;
  final base = DateTime(dateOnly.year, dateOnly.month, dateOnly.day, h, m);
  return base.add(Duration(minutes: bookingIndexZeroBased * durationMinutes));
}

String formatTimeHhMm(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

/// Normalizes [AppointmentFields.time] strings to `HH:mm` for slot matching.
String normalizeAppointmentTimeToHhMm(dynamic raw) {
  if (raw == null) return '';
  final s = raw.toString().trim();
  final parts = s.split(':');
  if (parts.length < 2) return '';
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null) return '';
  if (h < 0 || h > 23 || m < 0 || m > 59) return '';
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Booked slot keys (`HH:mm`) for this [availableDayDocId], including legacy rows
/// (no [AppointmentFields.availableDayDocId]) on the same calendar day.
Set<String> bookedTimeKeysHhMmForAvailableDay({
  required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> sameDayDocs,
  required String availableDayDocId,
}) {
  final aid = availableDayDocId.trim();
  final out = <String>{};
  for (final d in sameDayDocs) {
    final data = d.data();
    final docAid =
        (data[AppointmentFields.availableDayDocId] ?? '').toString().trim();
    if (docAid.isNotEmpty && docAid != aid) continue;
    final st =
        (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
    if (st == 'cancelled') continue;
    final t = normalizeAppointmentTimeToHhMm(data[AppointmentFields.time]);
    if (t.isEmpty) continue;
    out.add(t);
  }
  return out;
}

/// First slot start in [slots] whose `HH:mm` is not in [bookedKeys], or `null` if full.
DateTime? firstAvailableSlotStart({
  required List<DateTime> slots,
  required Set<String> bookedKeys,
}) {
  for (final s in slots) {
    final k = formatTimeHhMm(s);
    if (!bookedKeys.contains(k)) return s;
  }
  return null;
}

/// Stable document id: `{doctorUid}_{yyyy-MM-dd}`.
String availableDayDocumentId({
  required String doctorUserId,
  required DateTime dateLocal,
}) {
  final y = dateLocal.year;
  final m = dateLocal.month.toString().padLeft(2, '0');
  final d = dateLocal.day.toString().padLeft(2, '0');
  return '${doctorUserId.trim()}_$y-$m-$d';
}

DateTime? availableDayDateOnlyFromData(Map<String, dynamic>? data) {
  if (data == null) return null;
  final ts = data[AvailableDayFields.date];
  if (ts is! Timestamp) return null;
  final x = ts.toDate();
  return DateTime(x.year, x.month, x.day);
}

/// Green / bookable when explicitly open, or legacy docs without [AvailableDayFields.isOpen].
bool availableDayIsOpen(Map<String, dynamic>? data) {
  if (data == null) return false;
  final v = data[AvailableDayFields.isOpen];
  if (v is bool) return v;
  return true;
}

/// From today (local midnight) onward, ordered by [AvailableDayFields.date].
Stream<QuerySnapshot<Map<String, dynamic>>> watchAvailableDaysFromToday({
  required String doctorUserId,
}) {
  final uid = doctorUserId.trim();
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return FirebaseFirestore.instance
      .collection(AvailableDayFields.collection)
      .where(AvailableDayFields.doctorId, isEqualTo: uid)
      .where(
        AvailableDayFields.date,
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      )
      .orderBy(AvailableDayFields.date)
      .snapshots();
}

/// Visible month (or any range) for [TableCalendar] — local calendar bounds.
Stream<QuerySnapshot<Map<String, dynamic>>> watchAvailableDaysInRange({
  required String doctorUserId,
  required DateTime rangeStartInclusiveLocal,
  required DateTime rangeEndExclusiveLocal,
}) {
  final uid = doctorUserId.trim();
  final a = DateTime(
    rangeStartInclusiveLocal.year,
    rangeStartInclusiveLocal.month,
    rangeStartInclusiveLocal.day,
  );
  final b = DateTime(
    rangeEndExclusiveLocal.year,
    rangeEndExclusiveLocal.month,
    rangeEndExclusiveLocal.day,
  );
  return FirebaseFirestore.instance
      .collection(AvailableDayFields.collection)
      .where(AvailableDayFields.doctorId, isEqualTo: uid)
      .where(
        AvailableDayFields.date,
        isGreaterThanOrEqualTo: Timestamp.fromDate(a),
      )
      .where(
        AvailableDayFields.date,
        isLessThan: Timestamp.fromDate(b),
      )
      .orderBy(AvailableDayFields.date)
      .snapshots();
}

/// Composite index hint for console errors.
const String kAvailableDaysDoctorDateIndexHint =
    'Composite index — collection: available_days | fields: doctorId (Ascending), '
    'date (Ascending). Query: where doctorId ==; where date >=; orderBy date asc.';

/// Range query (month view): doctorId + date window.
const String kAvailableDaysDoctorDateRangeIndexHint =
    'Composite index — collection: available_days | fields: doctorId (Ascending), '
    'date (Ascending). Query: where doctorId ==; where date >=; where date <; orderBy date asc.';

/// Opens the day for booking: [isOpen] true, time + duration; preserves [currentBookings].
Future<void> openAvailableDay({
  required String doctorUserId,
  required DateTime dateLocal,
  required String startTimeHhMm,
  required String closingTimeHhMm,
  required int appointmentDurationMinutes,
}) async {
  final uid = doctorUserId.trim();
  final day = DateTime(dateLocal.year, dateLocal.month, dateLocal.day);
  final id = availableDayDocumentId(doctorUserId: uid, dateLocal: day);
  final ref =
      FirebaseFirestore.instance.collection(AvailableDayFields.collection).doc(id);
  final snap = await ref.get();
  final kept = snap.exists
      ? ((snap.data()![AvailableDayFields.currentBookings] as num?)?.toInt() ?? 0)
      : 0;
  final timeNorm = normalizeAvailableDayStartTimeHhMm(startTimeHhMm);
  final dur = appointmentDurationMinutes.clamp(1, 24 * 60);
  final closeNorm = normalizeAvailableDayClosingTimeHhMm(closingTimeHhMm);
  await ref.set(
    {
      AvailableDayFields.doctorId: uid,
      AvailableDayFields.date: Timestamp.fromDate(day),
      AvailableDayFields.isOpen: true,
      AvailableDayFields.currentBookings: kept,
      AvailableDayFields.startTime: timeNorm,
      AvailableDayFields.closingTime: closeNorm,
      AvailableDayFields.appointmentDuration: dur,
    },
    SetOptions(merge: true),
  );
}

Future<void> updateAvailableDayTimeSettings({
  required String availableDayDocId,
  required String startTimeHhMm,
  required String closingTimeHhMm,
  required int appointmentDurationMinutes,
}) async {
  final ref = FirebaseFirestore.instance
      .collection(AvailableDayFields.collection)
      .doc(availableDayDocId.trim());
  final timeNorm = normalizeAvailableDayStartTimeHhMm(startTimeHhMm);
  final closeNorm = normalizeAvailableDayClosingTimeHhMm(closingTimeHhMm);
  final dur = appointmentDurationMinutes.clamp(1, 24 * 60);
  await ref.set(
    {
      AvailableDayFields.startTime: timeNorm,
      AvailableDayFields.closingTime: closeNorm,
      AvailableDayFields.appointmentDuration: dur,
    },
    SetOptions(merge: true),
  );
}

Future<void> setAvailableDayOpenState({
  required String availableDayDocId,
  required bool isOpen,
}) async {
  await FirebaseFirestore.instance
      .collection(AvailableDayFields.collection)
      .doc(availableDayDocId.trim())
      .set(
        {AvailableDayFields.isOpen: isOpen},
        SetOptions(merge: true),
      );
}

Future<void> deleteAvailableDay({
  required String doctorUserId,
  required DateTime dateLocal,
}) async {
  final uid = doctorUserId.trim();
  final day = DateTime(dateLocal.year, dateLocal.month, dateLocal.day);
  final id = availableDayDocumentId(doctorUserId: uid, dateLocal: day);
  await FirebaseFirestore.instance
      .collection(AvailableDayFields.collection)
      .doc(id)
      .delete();
}

/// Returns `null` on success, or a short error code for UI translation.
///
/// Picks the **first free** slot from [generatedSlotStartsForDay] vs existing
/// [appointments] (same day + [availableDayDocId] / legacy). [Transaction] only
/// supports document reads, so appointment rows are loaded with `.get()` before
/// each attempt; loop retries on contention.
Future<String?> bookAvailableDayTransaction({
  required DocumentReference<Map<String, dynamic>> appointmentRef,
  required String availableDayDocId,
  required String patientId,
  required String patientName,
  required String doctorId,
  required String doctorDisplayName,
  String? paymentMethod,
  String? paymentStatus,
  String? receiptImageUrl,
  Map<String, dynamic>? extraAppointmentData,
}) async {
  final pid = patientId.trim();
  final did = doctorId.trim();
  if (pid.isEmpty) return 'login_required';

  final dayRef = FirebaseFirestore.instance
      .collection(AvailableDayFields.collection)
      .doc(availableDayDocId);

  final initial = await dayRef.get();
  if (!initial.exists) return 'available_day_missing';
  final initialData = initial.data()!;
  final docDoctor =
      initialData[AvailableDayFields.doctorId]?.toString().trim() ?? '';
  if (docDoctor != did) return 'available_day_doctor_mismatch';
  if (!availableDayIsOpen(initialData)) return 'available_day_closed';

  final ts0 = initialData[AvailableDayFields.date];
  if (ts0 is! Timestamp) return 'available_day_bad_data';
  final raw0 = ts0.toDate();
  final dayStart = DateTime(raw0.year, raw0.month, raw0.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final startHhMm = normalizeAvailableDayStartTimeHhMm(
    initialData[AvailableDayFields.startTime],
  );
  final closingHhMm = normalizeAvailableDayClosingTimeHhMm(
    initialData[AvailableDayFields.closingTime],
  );
  final durationMin = normalizeAppointmentDurationMinutes(
    initialData[AvailableDayFields.appointmentDuration],
  );

  final slots = generatedSlotStartsForDay(
    dateOnly: dayStart,
    startTimeHhMm: startHhMm,
    closingTimeHhMm: closingHhMm,
    durationMinutes: durationMin,
  );
  if (slots.isEmpty) return 'available_day_bad_data';

  const maxAttempts = 8;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final apptSnap = await appointmentsForDoctorDateRange(
      doctorUserId: did,
      rangeStartInclusiveLocal: dayStart,
      rangeEndExclusiveLocal: dayEnd,
    ).get();

    final bookedKeys = bookedTimeKeysHhMmForAvailableDay(
      sameDayDocs: apptSnap.docs,
      availableDayDocId: availableDayDocId,
    );

    final freeStart = firstAvailableSlotStart(
      slots: slots,
      bookedKeys: bookedKeys,
    );
    if (freeStart == null) return 'available_day_full';

    final timeStr = formatTimeHhMm(freeStart);
    final queueNumber = countNonCancelledAppointments(apptSnap.docs) + 1;

    try {
      final err = await FirebaseFirestore.instance.runTransaction<String?>((
        transaction,
      ) async {
        final snap = await transaction.get(dayRef);
        if (!snap.exists) return 'available_day_missing';
        final data = snap.data()!;
        final dDoctor =
            data[AvailableDayFields.doctorId]?.toString().trim() ?? '';
        if (dDoctor != did) return 'available_day_doctor_mismatch';
        if (!availableDayIsOpen(data)) return 'available_day_closed';

        transaction.update(dayRef, {
          AvailableDayFields.currentBookings: FieldValue.increment(1),
        });

        final apptPayload = <String, dynamic>{
          AppointmentFields.patientId: pid,
          AppointmentFields.userId: pid,
          AppointmentFields.doctorId: did,
          AppointmentFields.doctorName:
              doctorDisplayName.trim().isEmpty ? '—' : doctorDisplayName.trim(),
          AppointmentFields.patientName:
              patientName.trim().isEmpty ? '—' : patientName.trim(),
          AppointmentFields.date: Timestamp.fromDate(dayStart),
          AppointmentFields.time: timeStr,
          'dateTime': Timestamp.fromDate(freeStart),
          AppointmentFields.status: 'pending',
          AppointmentFields.isBooked: true,
          AppointmentFields.queueNumber: queueNumber,
          AppointmentFields.createdAt: FieldValue.serverTimestamp(),
          AppointmentFields.availableDayDocId: availableDayDocId,
          if (paymentMethod != null && paymentMethod.trim().isNotEmpty)
            AppointmentFields.paymentMethod: paymentMethod.trim(),
          if (paymentStatus != null && paymentStatus.trim().isNotEmpty)
            AppointmentFields.paymentStatus: paymentStatus.trim(),
        };
        final receipt = receiptImageUrl?.trim();
        if (receipt != null && receipt.isNotEmpty) {
          apptPayload[AppointmentFields.receiptImageUrl] = receipt;
          apptPayload[AppointmentFields.receiptUrl] = receipt;
        }
        final extra = extraAppointmentData;
        if (extra != null) {
          for (final e in extra.entries) {
            final v = e.value;
            if (v == null) continue;
            if (v is String && v.trim().isEmpty) continue;
            apptPayload[e.key] = v;
          }
        }
        transaction.set(appointmentRef, apptPayload);

        return null;
      });
      if (err == null) return null;
      return err;
    } catch (_) {
      if (attempt == maxAttempts - 1) return 'available_day_tx_failed';
    }
  }
  return 'available_day_tx_failed';
}
