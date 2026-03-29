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
