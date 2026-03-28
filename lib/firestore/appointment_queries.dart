import 'package:cloud_firestore/cloud_firestore.dart';

/// [appointments] collection — field names must match composite indexes exactly.
/// Use [doctorId] (capital **I** in `Id`), never `doctorld` or `doctor_id`.
abstract final class AppointmentFields {
  static const String collection = 'appointments';

  /// Firestore field **`doctorId`** (capital **I** in `Id`). Do not use `doctorid` / `doctorld` / `doctor_id`.
  static const String doctorId = 'doctorId';

  static const String date = 'date';
  static const String status = 'status';
  static const String patientId = 'patientId';

  /// Other document keys (not part of the default composite index).
  static const String doctorName = 'doctorName';
  static const String patientName = 'patientName';
  static const String time = 'time';
  static const String queueNumber = 'queueNumber';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String createdByStaff = 'createdByStaff';
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
