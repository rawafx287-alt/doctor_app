import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'root_notifications_firestore.dart';
import '../firestore/available_days_queries.dart' show normalizeAppointmentTimeToHhMm;

/// [appointments] collection — field names must match composite indexes exactly.
/// Use [doctorId] (capital **I** in `Id`), never `doctorld` or `doctor_id`.
abstract final class AppointmentFields {
  static const String collection = 'appointments';

  /// Firestore field **`doctorId`** (capital **I** in `Id`). Do not use `doctorid` / `doctorld` / `doctor_id`.
  static const String doctorId = 'doctorId';

  static const String date = 'date';
  static const String status = 'status';
  static const String patientId = 'patientId';

  /// Same value as [patientId] for patient-owned rows; matches composite indexes using `userId`.
  static const String userId = 'userId';

  /// Other document keys (not part of the default composite index).
  static const String doctorName = 'doctorName';
  static const String patientName = 'patientName';
  static const String time = 'time';
  static const String queueNumber = 'queueNumber';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String createdByStaff = 'createdByStaff';

  /// `doctor` | `clinic_closed` — why the appointment was cancelled (optional).
  static const String cancellationReason = 'cancellationReason';

  /// Links an [appointments] row to an [available_days] document (patient self-booking).
  static const String availableDayDocId = 'availableDayDocId';

  /// `Cash` | `FIB` | `FastPay` | `FIB_FastPay` — set when patient completes booking + payment step.
  static const String paymentMethod = 'paymentMethod';

  /// `pending_cash` | `pending_verification` | `confirmed` — payment / verification lifecycle.
  static const String paymentStatus = 'paymentStatus';

  /// Firebase Storage download URL for digital payment receipt (primary field).
  static const String receiptImageUrl = 'receiptImageUrl';

  /// Legacy alias; prefer [receiptImageUrl]. Kept in sync for older clients.
  static const String receiptUrl = 'receiptUrl';

  // --- Patient booking form ([BookingDetailsPage]) — stored on appointment doc ---
  static const String bookingAge = 'bookingAge';
  static const String bloodGroup = 'bloodGroup';
  static const String bookingPhone = 'bookingPhone';
  static const String bookingGender = 'bookingGender';
  static const String bookingMedicalNotes = 'bookingMedicalNotes';
  static const String bookingCityArea = 'bookingCityArea';

  /// Optional; set `true` when a patient holds the slot, cleared when the slot is freed.
  static const String isBooked = 'isBooked';

  /// Per-slot secretary toggle: when `false` the slot is closed/unavailable for patients.
  /// Default is `true` when missing.
  static const String isAvailable = 'isAvailable';
}

/// Archive for doctor/secretary rejections — does **not** replace live [appointments] queries.
abstract final class RejectedAppointmentFields {
  static const String collection = 'rejected_appointments';

  static const String originalAppointmentId = 'originalAppointmentId';
  static const String rejectedAt = 'rejectedAt';

  /// Local calendar day key `yyyy/MM/dd` (matches string [AppointmentFields.date] rows).
  static const String rejectedDayKey = 'rejectedDayKey';
}

/// `true` when another patient must not book this time.
///
/// **Completed / done visits stay locked for the rest of that calendar day** (secretary “تەواوبوو”),
/// even if patient fields are cleared later. Only freed placeholders (`available`) and
/// cancelled/rejected rows allow reuse.
bool appointmentDocBlocksSlotForNewPatientBooking(Map<String, dynamic> data) {
  final avail = data[AppointmentFields.isAvailable];
  if (avail == false) return true;
  final s =
      (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
  if (s == 'available') return false;
  if (s == 'cancelled' || s == 'canceled') return false;
  if (s == 'rejected') return false;
  // pending, booked, confirmed, waiting, completed, done, …
  return true;
}

/// Patient schedule UI (بەتاڵ vs booked): must stay in sync with doctor/staff slot rules.
///
/// **Completed / done** always shows as occupied (even if [AppointmentFields.isBooked] is false or
/// patient ids were cleared). Otherwise: explicit [AppointmentFields.isBooked] `false` → free, or
/// follow [appointmentDocBlocksSlotForNewPatientBooking].
bool appointmentSlotCountsAsBookedOnPatientSchedule(Map<String, dynamic> data) {
  final avail = data[AppointmentFields.isAvailable];
  if (avail == false) return true;
  final s =
      (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
  if (s == 'completed' || s == 'complete' || s == 'done') return true;
  final ib = data[AppointmentFields.isBooked];
  if (ib == false) return false;
  return appointmentDocBlocksSlotForNewPatientBooking(data);
}

List<String> _slotKeysHhMmFromSettings({
  required String startTimeHhMm,
  required String closingTimeHhMm,
  required int durationMinutes,
}) {
  int parseMin(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) return -1;
    final h = int.tryParse(m.group(1)!) ?? -1;
    final mi = int.tryParse(m.group(2)!) ?? -1;
    if (h < 0 || h > 23 || mi < 0 || mi > 59) return -1;
    return h * 60 + mi;
  }

  final startMin = parseMin(startTimeHhMm);
  final endMin = parseMin(closingTimeHhMm);
  final dur = durationMinutes.clamp(1, 24 * 60);
  if (startMin < 0 || endMin < 0) return const [];
  if (endMin <= startMin) return const [];
  final out = <String>[];
  for (var m = startMin; m + dur <= endMin; m += dur) {
    final hh = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    out.add('$hh:$mm');
  }
  return out;
}

/// Regenerates **only** `status: available` placeholders for a doctor/day based on
/// the provided schedule settings, without touching real bookings or locked `done/completed` rows.
///
/// Rules:
/// - Keeps any time that is already occupied (anything where [appointmentDocBlocksSlotForNewPatientBooking] is true).
/// - Creates missing `available` docs for free keys.
/// - Deletes old `available` docs that no longer exist in the generated window.
Future<void> regenerateAvailableSlotsForDoctorLocalDay({
  required String doctorUserId,
  required DateTime dayLocal,
  required String startTimeHhMm,
  required String closingTimeHhMm,
  required int durationMinutes,
}) async {
  final did = doctorUserId.trim();
  if (did.isEmpty) return;
  final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final desiredKeys = _slotKeysHhMmFromSettings(
    startTimeHhMm: startTimeHhMm,
    closingTimeHhMm: closingTimeHhMm,
    durationMinutes: durationMinutes,
  );
  if (desiredKeys.isEmpty) return;

  final docs = await fetchMergedDoctorAppointmentDocsForLocalDay(
    doctorUserId: did,
    dayLocal: dayStart,
  );

  final occupiedKeys = <String>{};
  final availableDocsByKey =
      <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

  for (final d in docs) {
    final data = d.data();
    final key = normalizeAppointmentTimeToHhMm(data[AppointmentFields.time]);
    if (key.isEmpty) continue;
    final st = (data[AppointmentFields.status] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (appointmentDocBlocksSlotForNewPatientBooking(data)) {
      occupiedKeys.add(key);
      continue;
    }
    if (st == 'available') {
      availableDocsByKey[key] = d;
    }
  }

  final desired = desiredKeys.toSet();

  // Delete old placeholders outside the new grid.
  for (final e in availableDocsByKey.entries) {
    final k = e.key;
    if (!desired.contains(k)) {
      await e.value.reference.delete();
    }
  }

  // Create missing placeholders for free desired keys.
  final col = FirebaseFirestore.instance.collection(AppointmentFields.collection);
  for (final k in desiredKeys) {
    if (occupiedKeys.contains(k)) continue;
    if (availableDocsByKey.containsKey(k)) continue;
    await col.add({
      AppointmentFields.doctorId: did,
      AppointmentFields.date: Timestamp.fromDate(dayStart),
      AppointmentFields.time: k,
      AppointmentFields.status: 'available',
      AppointmentFields.isBooked: false,
      AppointmentFields.isAvailable: true,
      AppointmentFields.createdAt: FieldValue.serverTimestamp(),
      AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

/// Archives the prior appointment payload, then frees the live [appointments] doc for re-booking.
Future<void> archiveRejectedAppointmentAndFreeSlot({
  required DocumentReference<Map<String, dynamic>> appointmentRef,
  required Map<String, dynamic> priorData,
  required String cancellationReason,
}) async {
  final batch = FirebaseFirestore.instance.batch();

  final rejectedRef = FirebaseFirestore.instance
      .collection(RejectedAppointmentFields.collection)
      .doc();

  final day = appointmentLocalDateOnlyFromData(priorData);
  final dayKey =
      day == null ? '' : DateFormat('yyyy/MM/dd').format(day);

  final archived = Map<String, dynamic>.from(priorData);
  archived[RejectedAppointmentFields.originalAppointmentId] = appointmentRef.id;
  archived[RejectedAppointmentFields.rejectedAt] = FieldValue.serverTimestamp();
  archived[AppointmentFields.status] = 'rejected';
  archived[AppointmentFields.cancellationReason] = cancellationReason;
  if (dayKey.isNotEmpty) {
    archived[RejectedAppointmentFields.rejectedDayKey] = dayKey;
  }

  batch.set(rejectedRef, archived);

  batch.update(appointmentRef, {
    AppointmentFields.status: 'available',
    AppointmentFields.patientName: null,
    AppointmentFields.patientId: null,
    AppointmentFields.userId: FieldValue.delete(),
    AppointmentFields.isBooked: false,
    AppointmentFields.queueNumber: FieldValue.delete(),
    AppointmentFields.cancellationReason: cancellationReason,
    AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
  });

  await batch.commit();
}

/// Rejected rows for one doctor + local day — listens by [RejectedAppointmentFields.rejectedDayKey].
///
/// **Firestore index:** collection `rejected_appointments` —
/// `doctorId` (Ascending), `rejectedDayKey` (Ascending).
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    watchRejectedAppointmentsForDoctorLocalDay({
  required String doctorUserId,
  required DateTime dayLocal,
}) {
  final did = doctorUserId.trim();
  final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final rejectedDayKey = DateFormat('yyyy/MM/dd').format(start);

  return FirebaseFirestore.instance
      .collection(RejectedAppointmentFields.collection)
      .where(AppointmentFields.doctorId, isEqualTo: did)
      .where(RejectedAppointmentFields.rejectedDayKey, isEqualTo: rejectedDayKey)
      .snapshots()
      .map((snap) {
        final list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snap.docs,
        );
        int rejectedMs(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final raw = d.data()[RejectedAppointmentFields.rejectedAt];
          if (raw is Timestamp) return raw.millisecondsSinceEpoch;
          return 0;
        }

        list.sort((a, b) => rejectedMs(b).compareTo(rejectedMs(a)));
        return list;
      });
}

/// Status written for **new** patient bookings (slot held until doctor completes or rejects).
/// Legacy rows may still use `pending`; treat both as equivalent in doctor UI.
const String kAppointmentStatusBooked = 'booked';

/// Statuses that represent an **occupied** slot in Today’s list (app uses `pending`, not `booked`).
bool appointmentStatusIsOccupiedPatientSlot(String raw) {
  final s = raw.trim().toLowerCase();
  return s == 'pending' ||
      s == 'booked' ||
      s == 'confirmed' ||
      s == 'waiting';
}

/// Patient is in the live today queue (show complete/reject, gold highlight, etc.).
bool appointmentStatusIsDoctorWaitingQueue(String raw) {
  final s = raw.trim().toLowerCase();
  return s == 'pending' || s == kAppointmentStatusBooked || s == 'waiting';
}

/// Doctor + local date range on [AppointmentFields.date].
///
/// Field paths (must match your composite index and documents exactly):
/// - [AppointmentFields.doctorId] → **`doctorId`** (capital **I**).
/// - [AppointmentFields.date] → **`date`**
/// - [AppointmentFields.status] → **`status`** (second [orderBy]; every doc should have a string value)
///
/// ## Query shape ↔ Firebase composite index
///
/// **Index (recommended):** `doctorId` ↑, `date` ↑, `status` ↑ (Collection: `appointments`).
///
/// 1. [where] [AppointmentFields.doctorId] `==` [doctorUserId]
/// 2. [where] [AppointmentFields.date] `>=` range start
/// 3. [where] [AppointmentFields.date] `<` range end
/// 4. [orderBy] [AppointmentFields.date] ascending
/// 5. [orderBy] [AppointmentFields.status] ascending
///
/// Use [kAppointmentsDoctorDateStatusIndexHint] in debug logs when troubleshooting.
const String kAppointmentsDoctorDateStatusIndexHint =
    'Composite index — collection: appointments | fields: doctorId (Ascending), '
    'date (Ascending), status (Ascending). Query: where doctorId ==; where date >=; '
    'where date <; orderBy date asc; orderBy status asc.';

/// Composite index for string [AppointmentFields.date] (equality), e.g. `2026/05/06`.
const String kAppointmentsDoctorIdDateStringIndexHint =
    'Composite index — collection: appointments | fields: doctorId (Ascending), '
    'date (Ascending). Query: where doctorId ==; where date == string yyyy/MM/dd.';

Query<Map<String, dynamic>> appointmentsForDoctorDateRange({
  required String doctorUserId,
  required DateTime rangeStartInclusiveLocal,
  required DateTime rangeEndExclusiveLocal,
}) {
  return FirebaseFirestore.instance
      .collection(AppointmentFields.collection)
      .where(AppointmentFields.doctorId, isEqualTo: doctorUserId)
      .where(
        AppointmentFields.date,
        isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStartInclusiveLocal),
      )
      .where(
        AppointmentFields.date,
        isLessThan: Timestamp.fromDate(rangeEndExclusiveLocal),
      )
      .orderBy(AppointmentFields.date, descending: false)
      .orderBy(AppointmentFields.status, descending: false);
}

/// All appointments for [doctorUserId] in a local calendar month (for archive / reporting).
Stream<QuerySnapshot<Map<String, dynamic>>> watchDoctorAppointmentsForLocalMonth({
  required String doctorUserId,
  required int year,
  required int month,
}) {
  final start = DateTime(year, month, 1);
  final end = DateTime(year, month + 1, 1);
  return appointmentsForDoctorDateRange(
    doctorUserId: doctorUserId.trim(),
    rangeStartInclusiveLocal: start,
    rangeEndExclusiveLocal: end,
  ).snapshots();
}

/// Time range granularity for doctor history / archive lists.
enum DoctorArchiveGranularity {
  day,
  week,
  month,
  year,
}

/// Midnight local on the **Saturday** that starts the Saturday–Friday week
/// containing [dayLocal]. (Week runs Saturday → Friday inclusive.)
DateTime archiveWeekRangeStartSaturday(DateTime dayLocal) {
  final d = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final w = d.weekday;
  final daysSinceSaturday = w == DateTime.saturday
      ? 0
      : w == DateTime.sunday
          ? 1
          : w + 1;
  return d.subtract(Duration(days: daysSinceSaturday));
}

/// Unified stream of appointment docs for [DoctorArchiveGranularity].
///
/// [anchorLocal] — calendar day used as anchor: the specific day (daily), any day
/// within the target week (weekly, **Saturday–Friday**), any day in the month
/// (monthly), or any day in the year (yearly). Day/time parts outside the selected
/// granularity are ignored where appropriate.
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    watchDoctorArchiveAppointmentDocs({
  required String doctorUserId,
  required DoctorArchiveGranularity granularity,
  required DateTime anchorLocal,
}) {
  final did = doctorUserId.trim();
  final a = DateTime(anchorLocal.year, anchorLocal.month, anchorLocal.day);

  switch (granularity) {
    case DoctorArchiveGranularity.day:
      return watchDoctorAppointmentsForLocalDay(
        doctorUserId: did,
        dayLocal: a,
      );
    case DoctorArchiveGranularity.week:
      final start = archiveWeekRangeStartSaturday(a);
      final end = start.add(const Duration(days: 7));
      return appointmentsForDoctorDateRange(
        doctorUserId: did,
        rangeStartInclusiveLocal: start,
        rangeEndExclusiveLocal: end,
      ).snapshots().map((s) => s.docs);
    case DoctorArchiveGranularity.month:
      return watchDoctorAppointmentsForLocalMonth(
        doctorUserId: did,
        year: anchorLocal.year,
        month: anchorLocal.month,
      ).map((s) => s.docs);
    case DoctorArchiveGranularity.year:
      final start = DateTime(anchorLocal.year, 1, 1);
      final end = DateTime(anchorLocal.year + 1, 1, 1);
      return appointmentsForDoctorDateRange(
        doctorUserId: did,
        rangeStartInclusiveLocal: start,
        rangeEndExclusiveLocal: end,
      ).snapshots().map((s) => s.docs);
  }
}

/// Real-time bookings tied to one [available_days] document (same field as stored on create).
///
/// Composite index (if the console prompts): `appointments` —
/// [AppointmentFields.doctorId] Ascending, [AppointmentFields.availableDayDocId] Ascending.
const String kAppointmentsDoctorAvailableDayIndexHint =
    'Composite index — collection: appointments | fields: doctorId (Ascending), '
    'availableDayDocId (Ascending). Query: where doctorId ==; where availableDayDocId ==.';

Stream<QuerySnapshot<Map<String, dynamic>>> watchAppointmentsForAvailableDay({
  required String doctorUserId,
  required String availableDayDocId,
}) {
  final did = doctorUserId.trim();
  final aid = availableDayDocId.trim();
  return FirebaseFirestore.instance
      .collection(AppointmentFields.collection)
      .where(AppointmentFields.doctorId, isEqualTo: did)
      .where(AppointmentFields.availableDayDocId, isEqualTo: aid)
      .snapshots();
}

/// Counts non-cancelled [appointments] per [AppointmentFields.availableDayDocId] (for calendar badges).
Map<String, int> countBookingsByAvailableDayDocId(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final map = <String, int>{};
  for (final d in docs) {
    final data = d.data();
    if (!appointmentDocBlocksSlotForNewPatientBooking(data)) continue;
    final id = (data[AppointmentFields.availableDayDocId] ?? '').toString().trim();
    if (id.isEmpty) continue;
    map[id] = (map[id] ?? 0) + 1;
  }
  return map;
}

/// Doctor appointments for one **local** calendar day: merges
///
/// 1. [Timestamp] rows: same range as [appointmentsForDoctorDateRange] (midnight … next midnight).
/// 2. **String** rows: [AppointmentFields.date] `==` [DateFormat] `yyyy/MM/dd` (e.g. `2026/05/06`).
///
/// Create indexes if the debug console links suggest it:
/// - [kAppointmentsDoctorDateStatusIndexHint] (Timestamp branch)
/// - [kAppointmentsDoctorIdDateStringIndexHint] (string branch)
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    watchDoctorAppointmentsForLocalDay({
  required String doctorUserId,
  required DateTime dayLocal,
}) {
  final start =
      DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final endExclusive = start.add(const Duration(days: 1));
  final dateStringKey = DateFormat('yyyy/MM/dd').format(start);

  final streamTs = appointmentsForDoctorDateRange(
    doctorUserId: doctorUserId,
    rangeStartInclusiveLocal: start,
    rangeEndExclusiveLocal: endExclusive,
  ).snapshots();

  final streamStr = FirebaseFirestore.instance
      .collection(AppointmentFields.collection)
      .where(AppointmentFields.doctorId, isEqualTo: doctorUserId)
      .where(AppointmentFields.date, isEqualTo: dateStringKey)
      .snapshots();

  return Stream.multi((controller) {
    QuerySnapshot<Map<String, dynamic>>? lastTs;
    QuerySnapshot<Map<String, dynamic>>? lastStr;

    void emit() {
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final d in lastTs?.docs ?? const []) {
        byId[d.id] = d;
      }
      for (final d in lastStr?.docs ?? const []) {
        byId[d.id] = d;
      }
      controller.add(byId.values.toList());
    }

    final subTs = streamTs.listen(
      (event) {
        lastTs = event;
        emit();
      },
      onError: controller.addError,
    );
    final subStr = streamStr.listen(
      (event) {
        lastStr = event;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subTs.cancel();
      await subStr.cancel();
    };
  });
}

/// When `true`, only `where('userId', isEqualTo: uid)` (no `orderBy`) — use if
/// `failed-precondition` still appears with the indexed query below.
const bool kPatientAppointmentsWhereOnlyNoOrderBy = false;

/// Patient appointments for the signed-in user.
///
/// Matches composite index: **`userId` (Asc), `date` (Asc), `time` (Asc)**:
///
/// ```dart
/// collection('appointments')
///   .where('userId', isEqualTo: patientUid)
///   .orderBy('date', descending: false)
///   .orderBy('time', descending: false)
/// ```
///
/// [dateLocalDay] is **not** applied in Firestore (range + `orderBy` can require a
/// different index). Filter “today” in [PatientAppointmentsScreen] instead.
///
/// Legacy docs without [userId]: backfill from [patientId] or they will not appear.
Query<Map<String, dynamic>> patientAppointmentsQuery({
  required String patientUid,
  DateTime? dateLocalDay,
}) {
  final col = FirebaseFirestore.instance.collection(AppointmentFields.collection);
  final w = col.where(AppointmentFields.userId, isEqualTo: patientUid);
  if (kPatientAppointmentsWhereOnlyNoOrderBy) {
    return w;
  }
  return w
      .orderBy(AppointmentFields.date, descending: false)
      .orderBy(AppointmentFields.time, descending: false);
}

/// True when appointment status is cancelled (either spelling).
bool appointmentStatusIsCancelled(String raw) {
  final s = raw.trim().toLowerCase();
  return s == 'cancelled' || s == 'canceled';
}

/// Doctor-initiated cancellation from the appointments UI.
const String kAppointmentCancellationReasonDoctor = 'doctor';

/// Bulk cancellation when the clinic closes the day in schedule management.
const String kAppointmentCancellationReasonClinicClosed = 'clinic_closed';

/// Bulk cancellation when the doctor closes / marks the day full.
const String kAppointmentCancellationReasonDoctorDayClosed = 'doctor_day_closed';

/// Secretary cancelled the slot from schedule management (same patient push as doctor cancel).
const String kAppointmentCancellationReasonSecretary = 'secretary';

/// Bookings that still count as “active” for day-close bulk operations (not completed/cancelled).
bool appointmentIsActiveForClinicOperations(String raw) {
  return !appointmentStatusIsTerminalForStaffSort(raw);
}

int countActiveAppointmentsForClinicOps(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  var n = 0;
  for (final d in docs) {
    final st =
        (d.data()[AppointmentFields.status] ?? 'pending').toString();
    if (appointmentIsActiveForClinicOperations(st)) n++;
  }
  return n;
}

/// Same merge as [watchDoctorAppointmentsForLocalDay], one-shot for batch updates.
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    fetchMergedDoctorAppointmentDocsForLocalDay({
  required String doctorUserId,
  required DateTime dayLocal,
}) async {
  final did = doctorUserId.trim();
  final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final endExclusive = start.add(const Duration(days: 1));
  final dateStringKey = DateFormat('yyyy/MM/dd').format(start);

  final tsSnap = await appointmentsForDoctorDateRange(
    doctorUserId: did,
    rangeStartInclusiveLocal: start,
    rangeEndExclusiveLocal: endExclusive,
  ).get();

  final strSnap = await FirebaseFirestore.instance
      .collection(AppointmentFields.collection)
      .where(AppointmentFields.doctorId, isEqualTo: did)
      .where(AppointmentFields.date, isEqualTo: dateStringKey)
      .get();

  final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final d in tsSnap.docs) {
    byId[d.id] = d;
  }
  for (final d in strSnap.docs) {
    byId[d.id] = d;
  }
  return byId.values.toList();
}

Future<int> countActiveAppointmentsForDoctorLocalDay({
  required String doctorUserId,
  required DateTime dayLocal,
}) async {
  final docs = await fetchMergedDoctorAppointmentDocsForLocalDay(
    doctorUserId: doctorUserId,
    dayLocal: dayLocal,
  );
  return countActiveAppointmentsForClinicOps(docs);
}

/// Cancels all active (non-terminal) appointments for the doctor on [dayLocal].
/// Returns how many documents were updated.
Future<int> bulkCancelActiveAppointmentsForDoctorLocalDay({
  required String doctorUserId,
  required DateTime dayLocal,
  required String cancellationReason,
}) async {
  final docs = await fetchMergedDoctorAppointmentDocsForLocalDay(
    doctorUserId: doctorUserId,
    dayLocal: dayLocal,
  );
  final active = docs.where((d) {
    final st =
        (d.data()[AppointmentFields.status] ?? 'pending').toString();
    return appointmentIsActiveForClinicOperations(st);
  }).toList();

  const chunk = 450;
  var total = 0;
  final seenClinicDayKeys = <String>{};
  final doctorSnapCache = <String, DoctorNotificationSnapshot>{};

  Future<DoctorNotificationSnapshot> cachedDoctorSnapshot(String did) async {
    final k = did.trim();
    if (k.isEmpty) return const DoctorNotificationSnapshot();
    final hit = doctorSnapCache[k];
    if (hit != null) return hit;
    final snap = await loadDoctorNotificationSnapshot(k);
    doctorSnapCache[k] = snap;
    return snap;
  }

  for (var i = 0; i < active.length; i += chunk) {
    final batch = FirebaseFirestore.instance.batch();
    final slice = active.skip(i).take(chunk).toList();
    for (final doc in slice) {
      batch.update(doc.reference, {
        // Make the slot instantly available again.
        AppointmentFields.status: 'available',
        AppointmentFields.patientName: null,
        AppointmentFields.patientId: null,
        AppointmentFields.userId: FieldValue.delete(),
        AppointmentFields.isBooked: false,
        AppointmentFields.queueNumber: FieldValue.delete(),
        AppointmentFields.cancellationReason: cancellationReason,
        AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    total += slice.length;

    for (final doc in slice) {
      final data = doc.data();
      if (cancellationReason == kAppointmentCancellationReasonClinicClosed) {
        final keys = recipientKeysFromAppointmentData(data);
        if (keys.isEmpty) continue;
        final dk = appointmentNotificationDayKey(data) ?? 'unknown';
        final sorted = keys.toList()..sort();
        final dedupe = '${sorted.join('|')}|$dk';
        if (seenClinicDayKeys.contains(dedupe)) continue;
        seenClinicDayKeys.add(dedupe);
        final dateLabel = formatAppointmentDateForNotificationKu(data);
        final body = kClinicClosurePatientNotificationMessageKu.replaceAll(
          '{date}',
          dateLabel,
        );
        final doctorSnap = await cachedDoctorSnapshot(
          (data[AppointmentFields.doctorId] ?? '').toString(),
        );
        await createPatientRootNotification(
          appointmentData: data,
          appointmentDocId: doc.id,
          title: kPatientPushTitleAppointmentRejectedKu,
          message: body,
          type: 'clinic_closed',
          doctor: doctorSnap,
        );
      } else {
        final copy = patientAppointmentRejectedNotificationCopy(data);
        final doctorSnap = await cachedDoctorSnapshot(
          (data[AppointmentFields.doctorId] ?? '').toString(),
        );
        await createPatientRootNotification(
          appointmentData: data,
          appointmentDocId: doc.id,
          title: copy.$1,
          message: copy.$2,
          doctor: doctorSnap,
        );
      }
    }
  }
  return total;
}

/// `true` when the row should sort **after** active patients (doctor & secretary lists).
/// Matches: pending/active first, then completed/cancelled at bottom.
bool appointmentStatusIsTerminalForStaffSort(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return false;
  return s == 'completed' ||
      s == 'complete' ||
      s == 'done' ||
      s == 'cancelled' ||
      s == 'canceled';
}

int _timeMinutesFromAppointmentField(dynamic timeVal) {
  final s = (timeVal ?? '').toString().trim();
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
  if (m != null) {
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }
  return 1 << 20;
}

/// Slot instant for ordering (uses `dateTime` when set, else [AppointmentFields.date] + [time]).
DateTime appointmentSlotDateTimeForStaffSort(Map<String, dynamic> data) {
  final raw = data['dateTime'];
  if (raw is Timestamp) return raw.toDate();
  final day = appointmentLocalDateOnlyFromData(data);
  final mins = _timeMinutesFromAppointmentField(data[AppointmentFields.time]);
  if (day != null) {
    return DateTime(day.year, day.month, day.day, mins ~/ 60, mins % 60);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _updatedOrCreatedForStaffSort(Map<String, dynamic> data) {
  final u = data[AppointmentFields.updatedAt];
  if (u is Timestamp) return u.toDate();
  final c = data[AppointmentFields.createdAt];
  if (c is Timestamp) return c.toDate();
  return null;
}

/// Primary: active (`isCompleted == false`) first, terminal last — same rule as
/// `(a,b) => a.isCompleted==b.isCompleted ? 0 : a.isCompleted ? 1 : -1`.
/// Secondary: slot time ↑ within active; terminal by [updatedAt]/[createdAt] ↓.
int compareStaffAppointmentDocuments(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final da = a.data();
  final db = b.data();
  final ca = appointmentStatusIsTerminalForStaffSort(
    (da[AppointmentFields.status] ?? 'pending').toString(),
  );
  final cb = appointmentStatusIsTerminalForStaffSort(
    (db[AppointmentFields.status] ?? 'pending').toString(),
  );
  if (ca != cb) {
    return ca ? 1 : -1;
  }
  if (!ca) {
    return appointmentSlotDateTimeForStaffSort(da)
        .compareTo(appointmentSlotDateTimeForStaffSort(db));
  }
  final ua = _updatedOrCreatedForStaffSort(da);
  final ub = _updatedOrCreatedForStaffSort(db);
  if (ua != null && ub != null) return ub.compareTo(ua);
  if (ua != null) return -1;
  if (ub != null) return 1;
  return appointmentSlotDateTimeForStaffSort(db)
      .compareTo(appointmentSlotDateTimeForStaffSort(da));
}

void sortStaffAppointmentsInPlace(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
) {
  list.sort(compareStaffAppointmentDocuments);
}

/// Local calendar day from [AppointmentFields.date] (Timestamp, DateTime, or `yyyy/MM/dd` string).
DateTime? appointmentLocalDateOnlyFromData(Map<String, dynamic> data) {
  final raw = data[AppointmentFields.date];
  if (raw == null) return null;
  if (raw is Timestamp) {
    final d = raw.toDate();
    return DateTime(d.year, d.month, d.day);
  }
  if (raw is DateTime) {
    return DateTime(raw.year, raw.month, raw.day);
  }
  final str = raw.toString().trim();
  if (str.isEmpty) return null;
  final ymd = RegExp(r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})');
  final m = ymd.firstMatch(str);
  if (m != null) {
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
  try {
    final d = DateTime.parse(str);
    return DateTime(d.year, d.month, d.day);
  } catch (_) {
    return null;
  }
}

/// Stable sort key for grouping appointments by calendar day.
String appointmentDayKeyFromData(Map<String, dynamic> data) {
  final d = appointmentLocalDateOnlyFromData(data);
  if (d == null) return '';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Per local calendar day, assigns ticket **1…n** by [AppointmentFields.createdAt]
/// (then document id) among **non-cancelled** appointments only.
Map<String, int> dailyQueueNumberByDocId(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final byDay =
      <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  for (final d in docs) {
    final k = appointmentDayKeyFromData(d.data());
    if (k.isEmpty) continue;
    byDay.putIfAbsent(k, () => []).add(d);
  }
  final out = <String, int>{};
  for (final list in byDay.values) {
    final active = list.where((d) {
      final st =
          (d.data()[AppointmentFields.status] ?? 'pending').toString();
      return !appointmentStatusIsCancelled(st);
    }).toList();
    active.sort((a, b) {
      final ta = a.data()[AppointmentFields.createdAt];
      final tb = b.data()[AppointmentFields.createdAt];
      final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
      final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
      if (ma != mb) return ma.compareTo(mb);
      return a.id.compareTo(b.id);
    });
    for (var i = 0; i < active.length; i++) {
      out[active[i].id] = i + 1;
    }
  }
  return out;
}

/// Counts non-cancelled appointments in [docs] (e.g. same-day query snapshot).
int countNonCancelledAppointments(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  var n = 0;
  for (final d in docs) {
    final st =
        (d.data()[AppointmentFields.status] ?? 'pending').toString();
    if (appointmentStatusIsCancelled(st)) continue;
    n++;
  }
  return n;
}

/// Parses a positive stored [AppointmentFields.queueNumber], or `null`.
int? parseStoredAppointmentQueueNumber(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw > 0 ? raw : null;
  if (raw is num) {
    final v = raw.round();
    return v > 0 ? v : null;
  }
  return int.tryParse(raw.toString().trim());
}

/// When `true`, this row still **holds** its پسوولە for the day (gap-fill skips it).
bool appointmentStatusReservesQueueNumberSlot(String raw) {
  final s = raw.trim().toLowerCase();
  if (s == 'available') return false;
  if (s == 'cancelled' || s == 'canceled') return false;
  if (s == 'rejected') return false;
  return true;
}

/// Smallest positive integer not used as [AppointmentFields.queueNumber] among
/// rows that still reserve a ticket (freed / cancelled slots do not).
Future<int> smallestAvailableQueueNumberForDoctor({
  required String doctorUserId,
  required DateTime dayStartLocal,
}) async {
  final dayStart = DateTime(
    dayStartLocal.year,
    dayStartLocal.month,
    dayStartLocal.day,
  );
  final docs = await fetchMergedDoctorAppointmentDocsForLocalDay(
    doctorUserId: doctorUserId.trim(),
    dayLocal: dayStart,
  );
  final used = <int>{};
  for (final d in docs) {
    final data = d.data();
    if (!appointmentStatusReservesQueueNumberSlot(
      (data[AppointmentFields.status] ?? 'pending').toString(),
    )) {
      continue;
    }
    final q = parseStoredAppointmentQueueNumber(
      data[AppointmentFields.queueNumber],
    );
    if (q != null) used.add(q);
  }
  var n = 1;
  while (used.contains(n)) {
    n++;
  }
  return n;
}

/// Next daily ticket: smallest free number (reuses gaps after reject/cancel).
Future<int> nextDailyQueueNumberForDoctor({
  required String doctorUserId,
  required DateTime dayStartLocal,
}) async {
  final dayStart = DateTime(
    dayStartLocal.year,
    dayStartLocal.month,
    dayStartLocal.day,
  );
  return smallestAvailableQueueNumberForDoctor(
    doctorUserId: doctorUserId,
    dayStartLocal: dayStart,
  );
}

/// English numerals for ticket display; prefers [queueById] from [dailyQueueNumberByDocId].
String formatDailyQueueTicketEnglish(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
  Map<String, int> queueById,
) {
  final data = doc.data();
  final nf = NumberFormat.decimalPattern('en_US');
  final st = (data[AppointmentFields.status] ?? '').toString().toLowerCase();
  if (st == 'cancelled' || st == 'canceled') {
    final raw = data[AppointmentFields.queueNumber];
    int? q;
    if (raw is int) {
      q = raw;
    } else if (raw is num) {
      q = raw.round();
    } else if (raw != null) {
      q = int.tryParse(raw.toString().trim());
    }
    if (q != null && q > 0) return nf.format(q);
    return '—';
  }
  final n = queueById[doc.id];
  if (n != null && n > 0) return nf.format(n);
  final raw = data[AppointmentFields.queueNumber];
  int? q;
  if (raw is int) {
    q = raw;
  } else if (raw is num) {
    q = raw.round();
  } else if (raw != null) {
    q = int.tryParse(raw.toString().trim());
  }
  if (q != null && q > 0) return nf.format(q);
  return '—';
}
