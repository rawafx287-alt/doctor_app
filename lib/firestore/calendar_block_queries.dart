import 'package:cloud_firestore/cloud_firestore.dart';

import 'appointment_queries.dart';

/// [calendar_blocks] — doctor/secretary “closed day” / block documents.
///
/// Field paths must match Firestore and composite indexes exactly:
/// - [AppointmentFields.doctorId] is the string **`doctorId`** (capital **I** in `Id`).
/// - [AppointmentFields.date] is **`date`** ([Timestamp]).
///
/// ## Composite index (this collection is separate from [AppointmentFields.collection])
///
/// The monthly range query needs its **own** index (not the appointments one):
///
/// | Collection ID       | Field      | Order   |
/// |--------------------|------------|---------|
/// | `calendar_blocks`  | `doctorId` | Ascending |
/// | `calendar_blocks`  | `date`     | Ascending |
///
/// Create it in Firebase Console → Firestore → Indexes → Composite, or use the
/// **“Create index”** link from the red error in the app (that URL includes your
/// project id and is the fastest path).
///
/// [orderBy] on [AppointmentFields.date] matches the inequality range and keeps
/// the suggested index aligned with this query shape.
Query<Map<String, dynamic>> calendarBlocksForDoctorDateRange({
  required String doctorUserId,
  required DateTime rangeStartInclusiveLocal,
  required DateTime rangeEndExclusiveLocal,
}) {
  return FirebaseFirestore.instance
      .collection(CalendarBlockFields.collection)
      .where(AppointmentFields.doctorId, isEqualTo: doctorUserId)
      .where(
        AppointmentFields.date,
        isGreaterThanOrEqualTo:
            Timestamp.fromDate(rangeStartInclusiveLocal),
      )
      .where(
        AppointmentFields.date,
        isLessThan: Timestamp.fromDate(rangeEndExclusiveLocal),
      )
      .orderBy(AppointmentFields.date);
}

/// Collection id for read/write — same string the doctor management screen uses.
abstract final class CalendarBlockFields {
  static const collection = 'calendar_blocks';

  /// Optional reason for manual blocks: [kindOff] or [kindEmergency].
  static const String blockKind = 'blockKind';

  static const String kindOff = 'off';
  static const String kindEmergency = 'emergency';

  /// Per-calendar-day slot length (Schedule Management); does not block time ranges.
  /// Fields: [AppointmentFields.doctorId], [AppointmentFields.date], optional `appointmentDuration` (int minutes).
  static const String kindDaySettings = 'daySettings';
}

/// Debug hint when [calendarBlocksForDoctorDateRange] fails with a missing index.
const String kCalendarBlocksDoctorDateIndexHint =
    'Composite index — collection: calendar_blocks | fields: doctorId (Ascending), '
    'date (Ascending). Query: where doctorId ==; where date >=; where date <; '
    'orderBy date asc.';
