import 'package:cloud_firestore/cloud_firestore.dart';

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

MasterDayVisual classifyDay({
  required DateTime dateOnly,
  required Map<String, dynamic>? weeklySchedule,
  Map<String, dynamic>? dateOverrides,
  required Set<String> bookedTimeKeys,
  required List<Map<String, dynamic>> dayBlocks,
  int slotStepMinutes = kDefaultAppointmentSlotMinutes,
}) {
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
