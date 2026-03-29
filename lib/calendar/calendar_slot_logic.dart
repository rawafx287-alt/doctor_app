import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/calendar_block_queries.dart';

/// Primary Firestore field on doctor `users/{uid}` — appointment length in minutes.
const String kAppointmentDurationField = 'appointmentDuration';

/// Legacy field name (still read when [kAppointmentDurationField] is absent).
const String kAppointmentSlotMinutesField = 'appointmentSlotMinutes';

/// When the profile has no duration fields, slot generation and booking use this step.
const int kDefaultAppointmentSlotMinutes = 20;

/// Reads duration from doctor profile: [kAppointmentDurationField], then legacy
/// [kAppointmentSlotMinutesField]; clamps to \[5, 120\], default [kDefaultAppointmentSlotMinutes].
int appointmentSlotMinutesFromUserData(Map<String, dynamic>? data) {
  for (final raw in [
    data?[kAppointmentDurationField],
    data?[kAppointmentSlotMinutesField],
  ]) {
    if (raw is int) return raw.clamp(5, 120);
    if (raw is num) return raw.toInt().clamp(5, 120);
  }
  return kDefaultAppointmentSlotMinutes;
}

/// Slot step from [calendar_blocks] for [dateOnly]: first [CalendarBlockFields.kindDaySettings]
/// doc that matches the day; else [kDefaultAppointmentSlotMinutes].
int appointmentSlotMinutesFromCalendarDayBlockMaps(
  Iterable<Map<String, dynamic>> dayBlocks,
) {
  for (final data in dayBlocks) {
    if (data[CalendarBlockFields.isOpen] != true) continue;
    for (final raw in [
      data[kAppointmentDurationField],
      data[kAppointmentSlotMinutesField],
    ]) {
      if (raw is int) return raw.clamp(5, 120);
      if (raw is num) return raw.toInt().clamp(5, 120);
    }
  }
  for (final data in dayBlocks) {
    if (data[CalendarBlockFields.blockKind] != CalendarBlockFields.kindDaySettings) {
      continue;
    }
    for (final raw in [
      data[kAppointmentDurationField],
      data[kAppointmentSlotMinutesField],
    ]) {
      if (raw is int) return raw.clamp(5, 120);
      if (raw is num) return raw.toInt().clamp(5, 120);
    }
  }
  return kDefaultAppointmentSlotMinutes;
}

/// Uses [blocksForCalendarDay] on [allBlockMaps] (e.g. month query snapshot data).
int appointmentSlotMinutesForDateWithAllBlocks(
  DateTime dateOnly,
  Iterable<Map<String, dynamic>> allBlockMaps,
) {
  return appointmentSlotMinutesFromCalendarDayBlockMaps(
    blocksForCalendarDay(dateOnly, allBlockMaps),
  );
}

/// Stable `yyyy-MM-dd` key for [schedule_date_overrides] on the doctor user doc.
String scheduleDateOverrideKey(DateTime dateOnly) {
  final y = dateOnly.year;
  final m = dateOnly.month.toString().padLeft(2, '0');
  final d = dateOnly.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses legacy or alternate keys (`yyyy/MM/dd`, `yyyy-M-d`) to [scheduleDateOverrideKey].
String? canonicalScheduleDateOverrideKey(String rawKey) {
  final k = rawKey.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(k)) return k;
  final m = RegExp(r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$').firstMatch(k);
  if (m != null) {
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return scheduleDateOverrideKey(DateTime(y, mo, d));
  }
  return null;
}

/// Normalizes Firestore [schedule_date_overrides] map keys to [scheduleDateOverrideKey] (`yyyy-MM-dd`).
Map<String, dynamic> normalizeScheduleDateOverridesMap(dynamic raw) {
  if (raw is! Map) return {};
  final out = <String, dynamic>{};
  for (final e in raw.entries) {
    final canon = canonicalScheduleDateOverrideKey(e.key.toString());
    if (canon == null) continue;
    out[canon] = e.value;
  }
  return out;
}

/// Maps a calendar [DateTime] to [weekly_schedule] keys (doctor Firestore).
String? weekdayScheduleKeyForDate(DateTime d) {
  switch (d.weekday) {
    case DateTime.monday:
      return 'monday';
    case DateTime.tuesday:
      return 'tuesday';
    case DateTime.wednesday:
      return 'wednesday';
    case DateTime.thursday:
      return 'thursday';
    case DateTime.friday:
      return 'friday';
    case DateTime.saturday:
      return 'saturday';
    case DateTime.sunday:
      return 'sunday';
    default:
      return null;
  }
}

/// Doctor working window for [date], or null if day off / no schedule.
({int startMinutes, int endMinutes})? workingWindowForDate(
  DateTime date,
  Map<String, dynamic>? weekly,
) {
  if (weekly == null || weekly.isEmpty) return null;
  final key = weekdayScheduleKeyForDate(date);
  if (key == null) return null;
  final raw = weekly[key];
  if (raw is! Map) return null;
  if (raw['enabled'] != true) return null;
  final sm = (raw['startMinutes'] as num?)?.toInt() ?? 0;
  final em = (raw['endMinutes'] as num?)?.toInt() ?? 0;
  if (em <= sm) return null;
  return (startMinutes: sm, endMinutes: em);
}

/// Per-date window from [dateOverrides] (doctor `schedule_date_overrides` map), else [weekly].
///
/// Override value: `{ 'blocked': true }`, or custom window
/// `{ 'startMinutes': int, 'endMinutes': int }` (uses weekly hours when absent).
({int startMinutes, int endMinutes})? workingWindowForDateWithOverrides(
  DateTime date,
  Map<String, dynamic>? weekly,
  Map<String, dynamic>? dateOverrides,
) {
  final key = scheduleDateOverrideKey(DateTime(date.year, date.month, date.day));
  if (dateOverrides != null && dateOverrides.containsKey(key)) {
    final raw = dateOverrides[key];
    if (raw is Map) {
      final m = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      if (m['blocked'] == true) return null;
      if (m['useDefault'] == true) {
        return workingWindowForDate(date, weekly);
      }
      final sm = (m['startMinutes'] as num?)?.toInt();
      final em = (m['endMinutes'] as num?)?.toInt();
      if (sm != null && em != null && em > sm) {
        return (startMinutes: sm, endMinutes: em);
      }
    }
  }
  return workingWindowForDate(date, weekly);
}

List<int> slotStartMinutesForWindow(
  int startMinutes,
  int endMinutes, {
  int step = kDefaultAppointmentSlotMinutes,
}) {
  final list = <int>[];
  for (var m = startMinutes; m < endMinutes; m += step) {
    list.add(m);
  }
  return list;
}

String formatSlotMinutesKey(int m) {
  final h = m ~/ 60;
  final min = m % 60;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

/// Sequential queue (تەسەلسول): first free start in [slotStartsSorted] order.
/// [bookedTimeKeysNormalized] uses the same `HH:mm` strings as [formatSlotMinutesKey].
int? earliestSequentialFreeSlotStartMinutes(
  List<int> slotStartsSorted,
  Set<String> bookedTimeKeysNormalized,
) {
  for (final m in slotStartsSorted) {
    if (!bookedTimeKeysNormalized.contains(formatSlotMinutesKey(m))) return m;
  }
  return null;
}

bool _slotOverlapsBlock(int slotStart, int slotEndExclusive, Map<String, dynamic> block) {
  if (block['wholeDay'] == true) return true;
  final sm = (block['startMinutes'] as num?)?.toInt();
  final em = (block['endMinutes'] as num?)?.toInt();
  if (sm == null || em == null) return false;
  return slotStart < em && slotEndExclusive > sm;
}

/// Blocks for a single calendar day (normalized).
List<Map<String, dynamic>> blocksForCalendarDay(
  DateTime dateOnly,
  Iterable<Map<String, dynamic>> blockDocs,
) {
  final y = dateOnly.year;
  final m = dateOnly.month;
  final d = dateOnly.day;
  final out = <Map<String, dynamic>>[];
  for (final data in blockDocs) {
    final ts = data['date'];
    if (ts is! Timestamp) continue;
    final dt = ts.toDate();
    if (dt.year != y || dt.month != m || dt.day != d) continue;
    out.add(data);
  }
  return out;
}

enum MasterDayVisual { nonWorking, hasAvailability, fullyBooked }

/// Patient calendar: [calendar_blocks] only — no status doc → [unset] (disabled);
/// [isOpen] true/false when a doc applies to this doctor and date.
enum PatientCalendarDayGate { unset, closed, open }

/// Firestore may store [CalendarBlockFields.isOpen] as bool, int, or string.
bool? triStateIsOpenFromData(Map<String, dynamic> data) {
  if (!data.containsKey(CalendarBlockFields.isOpen)) return null;
  final v = data[CalendarBlockFields.isOpen];
  if (v == null) return null;
  if (v == true) return true;
  if (v == false) return false;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return false;
}

bool _doctorIdMatchesDocument(
  Map<String, dynamic> data,
  String doctorUserId,
) {
  final docDoctor = data[AppointmentFields.doctorId]?.toString().trim() ?? '';
  if (docDoctor.isEmpty) return true;
  return docDoctor == doctorUserId.trim();
}

/// Single `calendar_blocks/{yyyy-MM-dd}` read (e.g. [Source.server]).
PatientCalendarDayGate patientDayGateFromDayStatusDocument(
  DocumentSnapshot<Map<String, dynamic>> snap,
  String doctorUserId,
) {
  if (!snap.exists) return PatientCalendarDayGate.unset;
  final data = snap.data();
  if (data == null) return PatientCalendarDayGate.unset;
  if (!_doctorIdMatchesDocument(data, doctorUserId)) {
    return PatientCalendarDayGate.unset;
  }
  final open = triStateIsOpenFromData(data);
  if (open == null) return PatientCalendarDayGate.unset;
  return open ? PatientCalendarDayGate.open : PatientCalendarDayGate.closed;
}

/// Resolves open/closed from `calendar_blocks` docs for [dateOnly].
///
/// 1) Prefers document id `yyyy-MM-dd` (same as [scheduleDateOverrideKey]) when
/// [AppointmentFields.doctorId] matches [doctorUserId] or is absent.
/// 2) Falls back to timestamp-matched blocks via [calendarDayExplicitIsOpen].
PatientCalendarDayGate patientCalendarDayGateFromBlockSnapshots(
  DateTime dateOnly,
  Iterable<DocumentSnapshot<Map<String, dynamic>>> blockDocs,
  String doctorUserId,
) {
  final norm = DateTime(dateOnly.year, dateOnly.month, dateOnly.day);
  final key = scheduleDateOverrideKey(norm);

  for (final doc in blockDocs) {
    if (!doc.exists) continue;
    final data = doc.data();
    if (data == null) continue;
    final dateKeyField = data[CalendarBlockFields.dateKey]?.toString();
    final idMatches = doc.id == key;
    final dateKeyMatches =
        dateKeyField != null && dateKeyField.trim() == key;
    if (!idMatches && !dateKeyMatches) continue;
    if (!_doctorIdMatchesDocument(data, doctorUserId)) {
      continue;
    }
    final open = triStateIsOpenFromData(data);
    if (open != null) {
      return open ? PatientCalendarDayGate.open : PatientCalendarDayGate.closed;
    }
    if (idMatches) break;
  }

  final maps = blockDocs
      .where((e) => e.exists)
      .map((e) => e.data())
      .whereType<Map<String, dynamic>>()
      .toList();
  final explicit = calendarDayExplicitIsOpen(blocksForCalendarDay(norm, maps));
  if (explicit == null) return PatientCalendarDayGate.unset;
  return explicit ? PatientCalendarDayGate.open : PatientCalendarDayGate.closed;
}

/// True if any non–[CalendarBlockFields.kindDaySettings] block marks the clinic closed ([CalendarBlockFields.isClosed]).
bool calendarDayHasIsClosedFlag(Iterable<Map<String, dynamic>> dayBlocks) {
  for (final b in dayBlocks) {
    if (b.containsKey(CalendarBlockFields.isOpen)) continue;
    if (b[CalendarBlockFields.blockKind] == CalendarBlockFields.kindDaySettings) {
      continue;
    }
    if (b[CalendarBlockFields.isClosed] == true) return true;
  }
  return false;
}

/// `true` / `false` when a block carries [CalendarBlockFields.isOpen]; `null` if absent (patient: treat as locked).
bool? calendarDayExplicitIsOpen(Iterable<Map<String, dynamic>> dayBlocks) {
  for (final b in dayBlocks) {
    final t = triStateIsOpenFromData(b);
    if (t != null) return t;
  }
  return null;
}

/// Patient booking calendar: no `isOpen` doc → locked; `isOpen: true` → same visuals as [classifyDay].
MasterDayVisual classifyPatientBookingDay({
  required DateTime dateOnly,
  required Map<String, dynamic>? weeklySchedule,
  Map<String, dynamic>? dateOverrides,
  required Set<String> bookedTimeKeys,
  required List<Map<String, dynamic>> dayBlocks,
  int slotStepMinutes = kDefaultAppointmentSlotMinutes,
}) {
  if (calendarDayExplicitIsOpen(dayBlocks) != true) {
    return MasterDayVisual.nonWorking;
  }
  return classifyDay(
    dateOnly: dateOnly,
    weeklySchedule: weeklySchedule,
    dateOverrides: dateOverrides,
    bookedTimeKeys: bookedTimeKeys,
    dayBlocks: dayBlocks,
    slotStepMinutes: slotStepMinutes,
  );
}

MasterDayVisual classifyDay({
  required DateTime dateOnly,
  required Map<String, dynamic>? weeklySchedule,
  Map<String, dynamic>? dateOverrides,
  required Set<String> bookedTimeKeys,
  required List<Map<String, dynamic>> dayBlocks,
  int slotStepMinutes = kDefaultAppointmentSlotMinutes,
}) {
  if (calendarDayHasIsClosedFlag(dayBlocks)) return MasterDayVisual.nonWorking;

  final win = workingWindowForDateWithOverrides(
    dateOnly,
    weeklySchedule,
    dateOverrides,
  );
  if (win == null) return MasterDayVisual.nonWorking;

  var slots = slotStartMinutesForWindow(win.startMinutes, win.endMinutes, step: slotStepMinutes);
  slots = slots.where((start) {
    final end = start + slotStepMinutes;
    for (final b in dayBlocks) {
      if (b.containsKey(CalendarBlockFields.isOpen)) continue;
      if (b[CalendarBlockFields.blockKind] == CalendarBlockFields.kindDaySettings) {
        continue;
      }
      if (_slotOverlapsBlock(start, end, b)) return false;
    }
    return true;
  }).toList();

  slots = slots.where((start) {
    return !bookedTimeKeys.contains(formatSlotMinutesKey(start));
  }).toList();

  if (slots.isEmpty) return MasterDayVisual.fullyBooked;
  return MasterDayVisual.hasAvailability;
}
