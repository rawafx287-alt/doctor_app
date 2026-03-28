import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../calendar/calendar_slot_logic.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../locale/schedule_weekday_key.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final List<_DaySchedule> _schedules = [
    _DaySchedule(
      id: 'saturday',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'sunday',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'monday',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'tuesday',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'wednesday',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'thursday',
      isAvailable: false,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 14, minute: 0),
    ),
    _DaySchedule(
      id: 'friday',
      isAvailable: false,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
  ];

  Map<String, dynamic> _dateOverrides = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _defaultsExpanded = false;
  /// Default from profile; used when a date has no per-day [kAppointmentSlotMinutesField].
  int _profileAppointmentSlotMinutes = 30;

  static const List<int> _daySlotDurationChoices = [15, 20, 30, 45, 60];

  int _coerceDaySlotMinutes(int? value, int fallback) {
    if (value == null) return fallback;
    if (_daySlotDurationChoices.contains(value)) return value;
    return fallback;
  }

  Map<String, dynamic> _weeklyFirestoreMap() {
    final map = <String, dynamic>{};
    for (final day in _schedules) {
      map[day.id] = {
        'day': '',
        'enabled': day.isAvailable,
        'startMinutes': _toMinutes(day.startTime),
        'endMinutes': _toMinutes(day.endTime),
      };
    }
    return map;
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
        for (var i = 0; i < _schedules.length; i++) {
          final id = _schedules[i].id;
          final dayData = weekly[id];
          if (dayData is! Map) continue;

          final start = _fromMinutes(dayData['startMinutes']);
          final end = _fromMinutes(dayData['endMinutes']);
          final enabled = dayData['enabled'] == true;

          _schedules[i] = _schedules[i].copyWith(
            isAvailable: enabled,
            startTime: start ?? _schedules[i].startTime,
            endTime: end ?? _schedules[i].endTime,
          );
        }
      }

      final rawOv = data?['schedule_date_overrides'];
      if (rawOv is Map) {
        _dateOverrides = Map<String, dynamic>.from(
          rawOv.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        _dateOverrides = {};
      }

      _profileAppointmentSlotMinutes =
          appointmentSlotMinutesFromUserData(data);
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

  ({int startMinutes, int endMinutes})? _resolvedWindow(DateTime day) {
    return workingWindowForDateWithOverrides(
      DateTime(day.year, day.month, day.day),
      _weeklyFirestoreMap(),
      _dateOverrides,
    );
  }

  bool _isBlockedOverride(DateTime day) {
    final key = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    final raw = _dateOverrides[key];
    return raw is Map && raw['blocked'] == true;
  }

  Future<void> _pickTime(int index, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _schedules[index].startTime : _schedules[index].endTime,
      builder: (context, child) {
        return Directionality(
          textDirection: AppLocaleScope.of(context).textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;

    setState(() {
      _schedules[index] = _schedules[index].copyWith(
        startTime: isStart ? picked : _schedules[index].startTime,
        endTime: isStart ? _schedules[index].endTime : picked,
      );
    });
  }

  Future<void> _openDayEditor(DateTime day) async {
    final s = S.of(context);
    final key = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    final weeklyOnly = workingWindowForDate(day, _weeklyFirestoreMap());
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

    if (!mounted) return;

    var sbBlocked = blocked;
    var sbCustom = custom;
    var sbStart = startT;
    var sbEnd = endT;

    final slotRaw =
        raw is Map ? raw[kAppointmentSlotMinutesField] : null;
    var sbSlot = _coerceDaySlotMinutes(
      slotRaw is int
          ? slotRaw
          : slotRaw is num
              ? slotRaw.toInt()
              : null,
      _profileAppointmentSlotMinutes,
    );

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
                  const SizedBox(height: 16),
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
                          fontSize: 12,
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
                                style: const TextStyle(fontFamily: 'KurdishFont'),
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
                                style: const TextStyle(fontFamily: 'KurdishFont'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  if (!sbBlocked) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        s.translate('schedule_day_appointment_duration'),
                        style: const TextStyle(
                          color: Color(0xFF829AB1),
                          fontSize: 13,
                          fontFamily: 'KurdishFont',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF12152A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: sbSlot,
                            dropdownColor: const Color(0xFF252640),
                            iconEnabledColor: const Color(0xFF42A5F5),
                            style: const TextStyle(
                              color: Color(0xFFD9E2EC),
                              fontFamily: 'KurdishFont',
                              fontSize: 15,
                            ),
                            items: _daySlotDurationChoices
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
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        s.translate('schedule_day_appointment_duration_hint'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontFamily: 'KurdishFont',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        if (sbBlocked) {
                          _dateOverrides[key] = {'blocked': true};
                        } else if (!sbCustom) {
                          if (sbSlot == _profileAppointmentSlotMinutes) {
                            _dateOverrides.remove(key);
                          } else {
                            _dateOverrides[key] = {
                              kAppointmentSlotMinutesField: sbSlot,
                            };
                          }
                        } else {
                          _dateOverrides[key] = {
                            'startMinutes': _toMinutes(sbStart),
                            'endMinutes': _toMinutes(sbEnd),
                            kAppointmentSlotMinutesField: sbSlot,
                          };
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: const Color(0xFF102A43),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      s.translate('schedule_apply_day'),
                      style: const TextStyle(
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final s = S.of(context);
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_user_missing'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'weekly_schedule': _weeklyFirestoreMap(),
          'schedule_date_overrides': _dateOverrides,
          'scheduleUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('schedule_save_ok'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('schedule_save_error_generic'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
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
              const SizedBox(height: 8),
              ExpansionTile(
                initiallyExpanded: _defaultsExpanded,
                onExpansionChanged: (e) => setState(() => _defaultsExpanded = e),
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(
                  s.translate('schedule_weekday_defaults_title'),
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    itemCount: _schedules.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (context, index) {
                      final item = _schedules[index];
                      final dayTitle = s.translate(scheduleDayTranslationKey(item.id));
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dayTitle,
                                    style: const TextStyle(
                                      color: Color(0xFFD9E2EC),
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'KurdishFont',
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: item.isAvailable,
                                  activeThumbColor: const Color(0xFF42A5F5),
                                  onChanged: (v) {
                                    setState(() {
                                      _schedules[index] = _schedules[index].copyWith(isAvailable: v);
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (item.isAvailable)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _pickTime(index, isStart: true),
                                      child: Text(
                                        '${s.translate('schedule_time_start')} ${_formatTime(item.startTime)}',
                                        style: const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _pickTime(index, isStart: false),
                                      child: Text(
                                        '${s.translate('schedule_time_end')} ${_formatTime(item.endTime)}',
                                        style: const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          );

    final saveBar = Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, savePaddingBottom),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSchedule,
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

class _DaySchedule {
  const _DaySchedule({
    required this.id,
    required this.isAvailable,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final bool isAvailable;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  _DaySchedule copyWith({
    String? id,
    bool? isAvailable,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return _DaySchedule(
      id: id ?? this.id,
      isAvailable: isAvailable ?? this.isAvailable,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
