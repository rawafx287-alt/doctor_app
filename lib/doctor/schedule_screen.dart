import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../calendar/calendar_slot_logic.dart';
import '../firestore/appointment_queries.dart';
import '../firestore/calendar_block_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Map<String, dynamic> _dateOverrides = {};
  Map<String, dynamic>? _cachedWeekly;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay;
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<int> _daySlotChoices = [15, 20, 30, 45, 60];

  Map<String, dynamic> _weeklyMap() {
    final w = _cachedWeekly;
    if (w == null || w.isEmpty) return {};
    return Map<String, dynamic>.from(
      w.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final weekly = data?['weekly_schedule'];
      if (weekly is Map) {
        _cachedWeekly = Map<String, dynamic>.from(
          weekly.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        _cachedWeekly = null;
      }

      final rawOv = data?['schedule_date_overrides'];
      if (rawOv is Map) {
        _dateOverrides = Map<String, dynamic>.from(
          rawOv.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        _dateOverrides = {};
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('schedule_load_error'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay? _fromMinutes(dynamic value) {
    if (value is! int || value < 0) return null;
    return TimeOfDay(hour: value ~/ 60, minute: value % 60);
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _formatTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat.jm().format(dt);
  }

  String _daySettingsDocId(String uid, DateTime day) {
    final k = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    return '${uid}_${k}_daySettings';
  }

  Future<int?> _loadDaySettingsSlotMinutes(String uid, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    try {
      final snap = await calendarBlocksForDoctorDateRange(
        doctorUserId: uid,
        rangeStartInclusiveLocal: start,
        rangeEndExclusiveLocal: end,
      ).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data[CalendarBlockFields.blockKind] != CalendarBlockFields.kindDaySettings) {
          continue;
        }
        final raw = data[kAppointmentDurationField] ?? data[kAppointmentSlotMinutesField];
        if (raw is int && _daySlotChoices.contains(raw)) return raw;
        if (raw is num) {
          final i = raw.toInt();
          if (_daySlotChoices.contains(i)) return i;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _persistDaySettingsBlock(String uid, DateTime day, int minutes) async {
    final start = DateTime(day.year, day.month, day.day);
    await FirebaseFirestore.instance
        .collection(CalendarBlockFields.collection)
        .doc(_daySettingsDocId(uid, day))
        .set(
      {
        AppointmentFields.doctorId: uid,
        AppointmentFields.date: Timestamp.fromDate(start),
        CalendarBlockFields.blockKind: CalendarBlockFields.kindDaySettings,
        kAppointmentDurationField: minutes,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _removeDaySettingsBlock(String uid, DateTime day) async {
    try {
      await FirebaseFirestore.instance
          .collection(CalendarBlockFields.collection)
          .doc(_daySettingsDocId(uid, day))
          .delete();
    } catch (_) {}
  }

  int _coerceSheetSlot(int? v) {
    if (v != null && _daySlotChoices.contains(v)) return v;
    return kDefaultAppointmentSlotMinutes;
  }

  ({int startMinutes, int endMinutes})? _resolvedWindow(DateTime day) {
    return workingWindowForDateWithOverrides(
      DateTime(day.year, day.month, day.day),
      _weeklyMap(),
      _dateOverrides,
    );
  }

  bool _isBlockedOverride(DateTime day) {
    final key = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    final raw = _dateOverrides[key];
    return raw is Map && raw['blocked'] == true;
  }

  Future<void> _openDayEditor(DateTime day) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;

    final s = S.of(context);
    final key = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    final weeklyOnly = workingWindowForDate(day, _weeklyMap());
    final raw = _dateOverrides[key];
    final blocked = raw is Map && raw['blocked'] == true;
    var custom = raw is Map &&
        !blocked &&
        raw['startMinutes'] != null &&
        raw['endMinutes'] != null;
    var startT = _fromMinutes(
          raw is Map ? raw['startMinutes'] : null,
        ) ??
        (weeklyOnly != null
            ? TimeOfDay(hour: weeklyOnly.startMinutes ~/ 60, minute: weeklyOnly.startMinutes % 60)
            : const TimeOfDay(hour: 9, minute: 0));
    var endT = _fromMinutes(
          raw is Map ? raw['endMinutes'] : null,
        ) ??
        (weeklyOnly != null
            ? TimeOfDay(hour: weeklyOnly.endMinutes ~/ 60, minute: weeklyOnly.endMinutes % 60)
            : const TimeOfDay(hour: 17, minute: 0));

    final loadedSlot = await _loadDaySettingsSlotMinutes(uid, day);
    var sbSlot = _coerceSheetSlot(loadedSlot);

    if (!mounted) return;

    var sbBlocked = blocked;
    var sbCustom = custom;
    var sbStart = startT;
    var sbEnd = endT;
    var sheetSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.paddingOf(ctx).bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      DateFormat.yMMMEd().format(day),
                      style: const TextStyle(
                        color: Color(0xFFD9E2EC),
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.translate('schedule_day_blocked'),
                        style: const TextStyle(
                          color: Color(0xFFD9E2EC),
                          fontFamily: 'KurdishFont',
                        ),
                      ),
                      value: sbBlocked,
                      activeThumbColor: const Color(0xFFE53935),
                      onChanged: (v) {
                        setModal(() {
                          sbBlocked = v;
                          if (v) sbCustom = false;
                        });
                      },
                    ),
                    if (!sbBlocked) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.translate('schedule_custom_hours'),
                          style: const TextStyle(
                            color: Color(0xFFD9E2EC),
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                        subtitle: Text(
                          s.translate('schedule_use_weekday_default_hint'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'KurdishFont',
                            fontSize: 11,
                          ),
                        ),
                        value: sbCustom,
                        activeThumbColor: const Color(0xFF42A5F5),
                        onChanged: (v) => setModal(() => sbCustom = v),
                      ),
                      if (sbCustom) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final p = await showTimePicker(
                                    context: ctx,
                                    initialTime: sbStart,
                                    builder: (c, ch) => Directionality(
                                      textDirection: AppLocaleScope.of(c).textDirection,
                                      child: ch ?? const SizedBox.shrink(),
                                    ),
                                  );
                                  if (p != null) setModal(() => sbStart = p);
                                },
                                child: Text(
                                  '${s.translate('schedule_time_start')}: ${_formatTime(sbStart)}',
                                  style: const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final p = await showTimePicker(
                                    context: ctx,
                                    initialTime: sbEnd,
                                    builder: (c, ch) => Directionality(
                                      textDirection: AppLocaleScope.of(c).textDirection,
                                      child: ch ?? const SizedBox.shrink(),
                                    ),
                                  );
                                  if (p != null) setModal(() => sbEnd = p);
                                },
                                child: Text(
                                  '${s.translate('schedule_time_end')}: ${_formatTime(sbEnd)}',
                                  style: const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          s.translate('schedule_weekday_slot_label'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontSize: 12,
                            fontFamily: 'KurdishFont',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF12152A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: sbSlot,
                              dropdownColor: const Color(0xFF252640),
                              iconEnabledColor: const Color(0xFF42A5F5),
                              style: const TextStyle(
                                color: Color(0xFFD9E2EC),
                                fontFamily: 'KurdishFont',
                                fontSize: 14,
                              ),
                              items: _daySlotChoices
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        s.translate(
                                          'schedule_day_slot_minutes_option',
                                          params: {'minutes': '$m'},
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setModal(() => sbSlot = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: (sheetSaving || _isSaving)
                          ? null
                          : () async {
                              setState(() {
                                if (sbBlocked) {
                                  _dateOverrides[key] = {'blocked': true};
                                } else if (!sbCustom) {
                                  _dateOverrides.remove(key);
                                } else {
                                  _dateOverrides[key] = {
                                    'startMinutes': _toMinutes(sbStart),
                                    'endMinutes': _toMinutes(sbEnd),
                                  };
                                }
                              });
                              sheetSaving = true;
                              setModal(() {});
                              try {
                                if (sbBlocked) {
                                  await _removeDaySettingsBlock(uid, day);
                                } else {
                                  await _persistDaySettingsBlock(uid, day, sbSlot);
                                }
                              } catch (_) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        s.translate('schedule_save_error_generic'),
                                        style: const TextStyle(fontFamily: 'KurdishFont'),
                                      ),
                                    ),
                                  );
                                }
                                sheetSaving = false;
                                if (ctx.mounted) setModal(() {});
                                return;
                              }
                              final ok = await _saveSchedule();
                              sheetSaving = false;
                              if (!ctx.mounted) return;
                              setModal(() {});
                              if (ok) Navigator.pop(ctx);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: const Color(0xFF102A43),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: sheetSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF102A43),
                              ),
                            )
                          : Text(
                              s.translate('schedule_save_button'),
                              style: const TextStyle(
                                fontFamily: 'KurdishFont',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Persists [schedule_date_overrides] on the user doc (weekly template is not edited here).
  Future<bool> _saveSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final s = S.of(context);
    if (uid == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_user_missing'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return false;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'schedule_date_overrides': _dateOverrides,
          'scheduleUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('schedule_save_ok'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return true;
    } on FirebaseException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('schedule_save_error_generic'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final savePaddingBottom = widget.embedded ? 12.0 + bottomInset : 16.0 + bottomInset;

    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text(
                  s.translate('schedule_calendar_hint'),
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                    fontSize: 13,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF12152A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
                  child: TableCalendar<void>(
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focusedDay,
                    rowHeight: 46,
                    daysOfWeekHeight: 34,
                    selectedDayPredicate: (d) =>
                        _selectedCalendarDay != null && isSameDay(_selectedCalendarDay!, d),
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                    startingDayOfWeek: StartingDayOfWeek.saturday,
                    locale: Localizations.localeOf(context).toLanguageTag(),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontFamily: 'KurdishFont',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      weekendStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontFamily: 'KurdishFont',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: const TextStyle(
                        color: Color(0xFFE8EEF4),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'KurdishFont',
                      ),
                      leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF42A5F5)),
                      rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF42A5F5)),
                    ),
                    calendarStyle: const CalendarStyle(
                      outsideDaysVisible: true,
                      markersMaxCount: 0,
                      cellMargin: EdgeInsets.zero,
                      defaultDecoration: BoxDecoration(shape: BoxShape.rectangle),
                      weekendDecoration: BoxDecoration(shape: BoxShape.rectangle),
                      outsideDecoration: BoxDecoration(shape: BoxShape.rectangle),
                      todayDecoration: BoxDecoration(shape: BoxShape.rectangle),
                      selectedDecoration: BoxDecoration(shape: BoxShape.rectangle),
                      defaultTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
                      weekendTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
                      outsideTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
                      todayTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
                      selectedTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
                    ),
                    onPageChanged: (f) => setState(() => _focusedDay = f),
                    onDaySelected: (sel, foc) {
                      setState(() {
                        _selectedCalendarDay = sel;
                        _focusedDay = foc;
                      });
                      _openDayEditor(sel);
                    },
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, d, fd) => _calendarCell(d, fd),
                      todayBuilder: (context, d, fd) => _calendarCell(d, fd, isToday: true),
                      selectedBuilder: (context, d, fd) => _calendarCell(d, fd, isSelected: true),
                      outsideBuilder: (context, d, fd) => _calendarCell(d, fd, isOutside: true),
                    ),
                  ),
                ),
              ),
            ],
          );

    final saveBar = Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, savePaddingBottom),
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveSchedule(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF42A5F5),
          foregroundColor: const Color(0xFF102A43),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Text(
                s.translate('schedule_save_button'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: widget.embedded
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: s.translate('tooltip_back'),
                ),
                title: Text(
                  s.translate('schedule_screen_title'),
                  style: const TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: const Color(0xFFD9E2EC),
                elevation: 0,
              ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: bodyContent,
              ),
            ),
            saveBar,
          ],
        ),
      ),
    );
  }

  Widget _calendarCell(
    DateTime day,
    DateTime focusedMonth, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final win = _resolvedWindow(day);
    final blocked = _isBlockedOverride(day);
    Color fill;
    Color border;
    if (blocked) {
      fill = const Color(0xFF3D1518);
      border = const Color(0xFFE53935);
    } else if (win != null) {
      fill = const Color(0xFF0F3D28);
      border = const Color(0xFF22C55E);
    } else {
      fill = const Color(0xFF1A1D2E);
      border = Colors.white24;
    }
    if (isOutside) {
      fill = fill.withValues(alpha: 0.45);
      border = border.withValues(alpha: 0.45);
    }
    if (isToday) {
      border = const Color(0xFF38BDF8);
    } else if (isSelected) {
      border = const Color(0xFF6366F1);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: isToday || isSelected ? 2 : 1.2),
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontFamily: 'KurdishFont',
          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          fontSize: 14,
          color: isOutside
              ? const Color(0xFF829AB1).withValues(alpha: 0.5)
              : const Color(0xFFE8EEF4),
        ),
      ),
    );
  }
}
