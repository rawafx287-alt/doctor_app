import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
    final st =
        (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
    if (st == 'cancelled') continue;
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

/// Next daily ticket for [doctorUserId] on [dayStartLocal] (non-cancelled count + 1).
Future<int> nextDailyQueueNumberForDoctor({
  required String doctorUserId,
  required DateTime dayStartLocal,
}) async {
  final dayStart = DateTime(
    dayStartLocal.year,
    dayStartLocal.month,
    dayStartLocal.day,
  );
  final dayEnd = dayStart.add(const Duration(days: 1));
  final snap = await appointmentsForDoctorDateRange(
    doctorUserId: doctorUserId.trim(),
    rangeStartInclusiveLocal: dayStart,
    rangeEndExclusiveLocal: dayEnd,
  ).get();
  return countNonCancelledAppointments(snap.docs) + 1;
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
