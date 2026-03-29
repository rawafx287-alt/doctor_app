import 'dart:async';

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

  /// Firestore document id for day-status rows — must match doctor save (`yyyy-MM-dd`).
  static String dayStatusDocumentId(DateTime localDateOnly) {
    final y = localDateOnly.year;
    final m = localDateOnly.month.toString().padLeft(2, '0');
    final d = localDateOnly.day.toString().padLeft(2, '0');
    return '$y-$m-$d'.trim();
  }

  /// Optional reason for manual blocks: [kindOff] or [kindEmergency].
  static const String blockKind = 'blockKind';

  static const String kindOff = 'off';
  static const String kindEmergency = 'emergency';

  /// Per-calendar-day slot length (Schedule Management); does not block time ranges.
  /// Fields: [AppointmentFields.doctorId], [AppointmentFields.date], optional `appointmentDuration` (int minutes).
  static const String kindDaySettings = 'daySettings';

  /// Whole-day closure from Schedule Management (“داخستنی ئەم ڕۆژە”); patient booking must treat day as off.
  static const String kindClosedDay = 'closedDay';

  /// When true on a [calendar_blocks] doc for that calendar day, patients cannot book.
  static const String isClosed = 'isClosed';

  /// Whole-day open/closed flag written by schedule save (`yyyy-MM-dd` doc id).
  /// Patient booking treats missing [isOpen] on any day block as locked.
  static const String isOpen = 'isOpen';

  /// Redundant string key matching the document id (`yyyy-MM-dd`) for debugging/queries.
  static const String dateKey = 'dateKey';
}

/// Debug hint when [calendarBlocksForDoctorDateRange] fails with a missing index.
const String kCalendarBlocksDoctorDateIndexHint =
    'Composite index — collection: calendar_blocks | fields: doctorId (Ascending), '
    'date (Ascending). Query: where doctorId ==; where date >=; where date <; '
    'orderBy date asc.';

/// `calendar_blocks/{yyyy-MM-dd}` from the server (skips offline cache) for booking checks.
Future<DocumentSnapshot<Map<String, dynamic>>> fetchCalendarDayStatusDocumentFromServer(
  DateTime localDateOnly, {
  required String doctorUserId,
}) {
  final did = doctorUserId.trim();
  final dateKey = CalendarBlockFields.dayStatusDocumentId(localDateOnly).trim();
  // ignore: avoid_print
  print('Searching for: $did on date: $dateKey');
  return FirebaseFirestore.instance
      .collection(CalendarBlockFields.collection)
      .doc(dateKey)
      .get(const GetOptions(source: Source.server));
}

/// True if [doc] belongs to [year]-[month] (local calendar): `yyyy-MM-dd` id or [AppointmentFields.date].
bool calendarBlockDocInPatientMonth(
  DocumentSnapshot<Map<String, dynamic>> doc,
  int year,
  int month,
) {
  final monthStart = DateTime(year, month, 1);
  final monthEndExclusive = DateTime(year, month + 1, 1);
  final idPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  final match = idPattern.firstMatch(doc.id.trim());
  if (match != null) {
    final dy = int.tryParse(match.group(1)!);
    final dm = int.tryParse(match.group(2)!);
    return dy == year && dm == month;
  }
  final data = doc.data();
  if (data == null) return false;
  final ts = data[AppointmentFields.date];
  if (ts is Timestamp) {
    final dt = ts.toDate();
    final n = DateTime(dt.year, dt.month, dt.day);
    return !n.isBefore(monthStart) && n.isBefore(monthEndExclusive);
  }
  return false;
}

/// Patient calendar: real-time [calendar_blocks] for this doctor.
///
/// Merges (1) `where doctorId == …` with (2) direct `doc(yyyy-MM-dd).snapshots()`
/// for each day in the month so day-status rows still appear if
/// [AppointmentFields.doctorId] was omitted on the document.
///
/// First emission waits until the range query has delivered at least one
/// snapshot, every per-day listener has fired once, or a short deadline — so the
/// UI does not paint the whole month as closed while listeners are still
/// catching up.
Stream<List<DocumentSnapshot<Map<String, dynamic>>>> watchPatientCalendarBlocksForMonth({
  required String doctorUserId,
  required DateTime focusedMonthLocal,
}) {
  final uid = doctorUserId.trim();
  final y = focusedMonthLocal.year;
  final m = focusedMonthLocal.month;
  final monthStart = DateTime(y, m, 1);
  final lastDay = DateTime(y, m + 1, 0);

  final firestore = FirebaseFirestore.instance;

  final queryStream = firestore
      .collection(CalendarBlockFields.collection)
      .where(AppointmentFields.doctorId, isEqualTo: uid)
      .snapshots(includeMetadataChanges: true);

  final refs = <DocumentReference<Map<String, dynamic>>>[];
  for (var d = monthStart; !d.isAfter(lastDay); d = d.add(const Duration(days: 1))) {
    refs.add(
      firestore
          .collection(CalendarBlockFields.collection)
          .doc(CalendarBlockFields.dayStatusDocumentId(d).trim()),
    );
  }

  return Stream<List<DocumentSnapshot<Map<String, dynamic>>>>.multi((listener) {
    QuerySnapshot<Map<String, dynamic>>? querySnap;
    final latestDay = List<DocumentSnapshot<Map<String, dynamic>>?>.filled(refs.length, null);
    var queryHeard = false;
    final dayHeard = List<bool>.filled(refs.length, false);
    var deadlinePassed = false;
    String? lastDebugSig;

    bool dayRefDocAllowed(Map<String, dynamic>? data) {
      if (data == null) return false;
      final dd = data[AppointmentFields.doctorId]?.toString().trim() ?? '';
      return dd.isEmpty || dd == uid;
    }

    bool canEmit() =>
        queryHeard || deadlinePassed || dayHeard.every((e) => e);

    void emit() {
      final byId = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final d in querySnap?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
        final id = d.id.trim();
        if (calendarBlockDocInPatientMonth(d, y, m)) {
          byId[id] = d;
        }
      }
      for (var i = 0; i < refs.length; i++) {
        final s = latestDay[i];
        if (s == null || !s.exists) continue;
        final data = s.data();
        if (!dayRefDocAllowed(data)) continue;
        byId[s.id.trim()] = s;
      }
      final keys = byId.keys.toList()..sort();
      final sig = '${keys.length}:${keys.join(",")}';
      if (sig != lastDebugSig) {
        lastDebugSig = sig;
        // Exact same wording as [fetchCalendarDayStatusDocumentFromServer] (sample keys).
        if (keys.isEmpty) {
          // ignore: avoid_print
          print('Searching for: $uid on date: (no merged docs this emit)');
        } else {
          final show = keys.length <= 5 ? keys : [...keys.take(2), '...', ...keys.skip(keys.length - 2)];
          for (final id in show) {
            if (id == '...') {
              // ignore: avoid_print
              print('Searching for: $uid on date: ... (${keys.length} total ids)');
              continue;
            }
            // ignore: avoid_print
            print('Searching for: $uid on date: $id');
          }
        }
      }
      listener.add(byId.values.toList());
    }

    void maybeEmit() {
      if (!canEmit()) return;
      emit();
    }

    final deadline = Timer(const Duration(milliseconds: 2500), () {
      deadlinePassed = true;
      maybeEmit();
    });

    final subs = <StreamSubscription<dynamic>>[];

    subs.add(
      queryStream.listen(
        (QuerySnapshot<Map<String, dynamic>> snap) {
          querySnap = snap;
          queryHeard = true;
          maybeEmit();
        },
        onError: (_) {
          queryHeard = true;
          maybeEmit();
        },
      ),
    );

    for (var i = 0; i < refs.length; i++) {
      final idx = i;
      subs.add(
        refs[idx].snapshots(includeMetadataChanges: true).listen(
          (DocumentSnapshot<Map<String, dynamic>> s) {
            latestDay[idx] = s;
            dayHeard[idx] = true;
            maybeEmit();
          },
          onError: (_) {
            dayHeard[idx] = true;
            maybeEmit();
          },
        ),
      );
    }

    listener.onCancel = () async {
      deadline.cancel();
      for (final s in subs) {
        await s.cancel();
      }
    };
  }, isBroadcast: true);
}
