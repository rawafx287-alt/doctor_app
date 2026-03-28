import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../auth/app_logout.dart';
import '../firestore/appointment_queries.dart';
import '../firestore/calendar_block_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../patient/create_patient_appointment.dart';
import 'calendar_slot_logic.dart';

const String _kMasterCalendarBrandTitle = 'HR Nora';

/// Month grid: green = open slots, red = fully booked / no open slots.
const Color _kCalGreenFill = Color(0xFF0F3D28);
const Color _kCalGreenBorder = Color(0xFF22C55E);
const Color _kCalRedFill = Color(0xFF3D1418);
const Color _kCalRedBorder = Color(0xFFEF4444);
/// Day has hours but every slot is booked / blocked.
const Color _kCalAmberFill = Color(0xFF3D2A0F);
const Color _kCalAmberBorder = Color(0xFFF59E0B);

/// Month master calendar: availability (green/red) and per-day slot sheet.
class MasterCalendarScreen extends StatefulWidget {
  const MasterCalendarScreen({
    super.key,
    this.doctorId,
    required this.canManage,
    this.showDoctorPicker = false,
    this.isRootShell = false,
  });

  /// When [showDoctorPicker] is true, user must choose a doctor first.
  final String? doctorId;
  final bool canManage;
  final bool showDoctorPicker;
  final bool isRootShell;

  @override
  State<MasterCalendarScreen> createState() => _MasterCalendarScreenState();
}

class _MasterCalendarScreenState extends State<MasterCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _pickedDoctorId;

  @override
  void initState() {
    super.initState();
    _pickedDoctorId = widget.doctorId;
    _selectedDay = DateTime.now();
  }

  String? get _effectiveDoctorId =>
      widget.showDoctorPicker ? _pickedDoctorId : widget.doctorId;

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _monthEndExclusive(DateTime d) => DateTime(d.year, d.month + 1, 1);

  Set<String> _bookedKeysForDay(
    DateTime day,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> apptDocs,
  ) {
    final y = day.year;
    final m = day.month;
    final d = day.day;
    final set = <String>{};
    for (final doc in apptDocs) {
      final data = doc.data();
      final st =
          (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
      if (st == 'cancelled') continue;
      final ts = data[AppointmentFields.date];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.year != y || dt.month != m || dt.day != d) continue;
      final t = (data[AppointmentFields.time] ?? '').toString().trim();
      if (t.isEmpty) continue;
      final parts = t.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final mi = int.tryParse(parts[1].trim()) ?? 0;
      set.add(
        '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}',
      );
    }
    return set;
  }

  Map<DateTime, MasterDayVisual> _visualsForMonth({
    required DateTime focusedMonth,
    required Map<String, dynamic>? weekly,
    Map<String, dynamic>? dateOverrides,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> apptDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blockDocs,
    Map<String, dynamic>? doctorProfileData,
  }) {
    final blockMaps = blockDocs.map((e) => e.data()).toList();
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final map = <DateTime, MasterDayVisual>{};

    for (var d = first;
        !d.isAfter(last);
        d = d.add(const Duration(days: 1))) {
      final key = DateTime(d.year, d.month, d.day);
      final dayBlocks = blocksForCalendarDay(key, blockMaps);
      final booked = _bookedKeysForDay(key, apptDocs);
      final step = effectiveAppointmentSlotMinutes(
        dateOnly: key,
        dateOverrides: dateOverrides,
        doctorUserData: doctorProfileData,
      );
      map[key] = classifyDay(
        dateOnly: key,
        weeklySchedule: weekly,
        dateOverrides: dateOverrides,
        bookedTimeKeys: booked,
        dayBlocks: dayBlocks,
        slotStepMinutes: step,
      );
    }
    return map;
  }

  Widget _connectStyleMonthCell({
    required DateTime day,
    required DateTime focusedMonth,
    required MasterDayVisual? visual,
    required bool isToday,
    required bool isSelected,
  }) {
    final isOutside = day.month != focusedMonth.month;
    Color fill;
    Color edgeColor;
    switch (visual) {
      case MasterDayVisual.hasAvailability:
        fill = _kCalGreenFill;
        edgeColor = _kCalGreenBorder;
      case MasterDayVisual.fullyBooked:
        fill = _kCalAmberFill;
        edgeColor = _kCalAmberBorder;
      case MasterDayVisual.nonWorking:
      default:
        fill = _kCalRedFill;
        edgeColor = _kCalRedBorder;
    }
    if (isOutside) {
      fill = fill.withValues(alpha: 0.45);
      edgeColor = edgeColor.withValues(alpha: 0.45);
    }

    final textColor = isOutside
        ? const Color(0xFF829AB1).withValues(alpha: 0.5)
        : const Color(0xFFE8EEF4);

    final Border cellBorder;
    if (isToday) {
      cellBorder = Border.all(color: const Color(0xFF38BDF8), width: 2);
    } else if (isSelected) {
      cellBorder = Border.all(color: const Color(0xFF6366F1), width: 2);
    } else {
      cellBorder = Border.all(
        color: edgeColor,
        width: visual == MasterDayVisual.hasAvailability ? 1.4 : 1.2,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: cellBorder,
        boxShadow: [
          if (!isOutside && visual == MasterDayVisual.hasAvailability)
            BoxShadow(
              color: _kCalGreenBorder.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          if (!isOutside && visual == MasterDayVisual.fullyBooked)
            BoxShadow(
              color: _kCalAmberBorder.withValues(alpha: 0.14),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontFamily: 'KurdishFont',
          fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 15,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _openDaySheet({
    required BuildContext context,
    required DateTime day,
    required Map<String, dynamic>? weekly,
    Map<String, dynamic>? dateOverrides,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> monthAppointments,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> monthBlocks,
    required int slotDurationMinutes,
  }) async {
    final doctorId = _effectiveDoctorId;
    if (doctorId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: AppLocaleScope.of(ctx).textDirection,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.92,
            builder: (_, scroll) {
              return _DayAgendaPanel(
                scrollController: scroll,
                day: day,
                doctorId: doctorId,
                weekly: weekly,
                dateOverrides: dateOverrides,
                monthAppointments: monthAppointments,
                monthBlocks: monthBlocks,
                slotDurationMinutes: slotDurationMinutes,
                canManage: widget.canManage,
                onChanged: () => setState(() {}),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dir = AppLocaleScope.of(context).textDirection;
    final doctorId = _effectiveDoctorId;

    return Directionality(
      textDirection: dir,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          leading: widget.isRootShell
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: s.translate('tooltip_back'),
                ),
          automaticallyImplyLeading: !widget.isRootShell,
          actions: [
            if (widget.isRootShell)
              IconButton(
                tooltip: s.translate('tooltip_logout'),
                onPressed: () => performAppLogout(context),
                icon: const Icon(Icons.logout_rounded),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  _kMasterCalendarBrandTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: 0.6,
                    color: const Color(0xFFD9E2EC),
                    shadows: [
                      Shadow(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  s.translate('master_calendar_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'KurdishFont',
                    color: const Color(0xFF829AB1).withValues(alpha: 0.95),
                    fontSize: 13,
                  ),
                ),
              ),
              if (widget.showDoctorPicker) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'Doctor')
                        .where('isApproved', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const LinearProgressIndicator(minHeight: 2);
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return Text(
                          s.translate('master_calendar_no_doctors'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'KurdishFont',
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _pickedDoctorId != null &&
                                docs.any((d) => d.id == _pickedDoctorId)
                            ? _pickedDoctorId
                            : null,
                        dropdownColor: const Color(0xFF1D1E33),
                        decoration: InputDecoration(
                          labelText: s.translate('master_calendar_pick_doctor'),
                          labelStyle: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'KurdishFont',
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1D1E33),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                        ),
                        items: docs
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  localizedDoctorFullName(
                                    d.data(),
                                    AppLocaleScope.of(context).effectiveLanguage,
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'KurdishFont',
                                    color: Color(0xFFD9E2EC),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _pickedDoctorId = v),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: doctorId == null
                    ? Center(
                        child: Text(
                          s.translate('master_calendar_pick_doctor'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                      )
                    : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(doctorId)
                            .snapshots(),
                        builder: (context, docSnap) {
                          final snapData = docSnap.data?.data();
                          final weeklyRaw = snapData?['weekly_schedule'];
                          final weekly = weeklyRaw is Map<String, dynamic> ? weeklyRaw : null;
                          final ovRaw = snapData?['schedule_date_overrides'];
                          final Map<String, dynamic>? dateOverrides = ovRaw is Map
                              ? Map<String, dynamic>.from(
                                  ovRaw.map((k, v) => MapEntry(k.toString(), v)),
                                )
                              : null;
                          final monthStart = _monthStart(_focusedDay);
                          final monthEnd = _monthEndExclusive(_focusedDay);

                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            key: ValueKey('$doctorId-${monthStart.toIso8601String()}'),
                            stream: appointmentsForDoctorDateRange(
                              doctorUserId: doctorId,
                              rangeStartInclusiveLocal: monthStart,
                              rangeEndExclusiveLocal: monthEnd,
                            ).snapshots(),
                            builder: (context, apptSnap) {
                              if (apptSnap.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      s.translate(
                                        'doctors_load_error_detail',
                                        params: {'error': '${apptSnap.error}'},
                                      ),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontFamily: 'KurdishFont',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                key: ValueKey('blk-$doctorId-${monthStart.toIso8601String()}'),
                                stream: calendarBlocksForDoctorDateRange(
                                  doctorUserId: doctorId,
                                  rangeStartInclusiveLocal: monthStart,
                                  rangeEndExclusiveLocal: monthEnd,
                                ).snapshots(),
                                builder: (context, blockSnap) {
                                  final appts = apptSnap.data?.docs ?? [];
                                  final blocks = blockSnap.data?.docs ?? [];
                                  final visuals = _visualsForMonth(
                                    focusedMonth: _focusedDay,
                                    weekly: weekly,
                                    dateOverrides: dateOverrides,
                                    apptDocs: appts,
                                    blockDocs: blocks,
                                    doctorProfileData: snapData,
                                  );

                                  return SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Column(
                                        children: [
                                          _LegendRow(loc: S.of(context)),
                                          const SizedBox(height: 10),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF12152A),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.white10),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(6, 10, 6, 14),
                                              child: TableCalendar<void>(
                                                firstDay: DateTime.utc(2024, 1, 1),
                                                lastDay: DateTime.utc(2035, 12, 31),
                                                focusedDay: _focusedDay,
                                                rowHeight: 52,
                                                daysOfWeekHeight: 36,
                                                selectedDayPredicate: (d) =>
                                                    _selectedDay != null &&
                                                    isSameDay(_selectedDay!, d),
                                                calendarFormat: CalendarFormat.month,
                                                availableCalendarFormats: const {
                                                  CalendarFormat.month: 'Month',
                                                },
                                                startingDayOfWeek:
                                                    StartingDayOfWeek.saturday,
                                                locale: Localizations.localeOf(context)
                                                    .toLanguageTag(),
                                                daysOfWeekStyle: DaysOfWeekStyle(
                                                  weekdayStyle: TextStyle(
                                                    color: const Color(0xFF94A3B8),
                                                    fontFamily: 'KurdishFont',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  weekendStyle: TextStyle(
                                                    color: const Color(0xFF94A3B8),
                                                    fontFamily: 'KurdishFont',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                headerStyle: HeaderStyle(
                                                  formatButtonVisible: false,
                                                  titleCentered: true,
                                                  headerPadding: EdgeInsets.zero,
                                                  titleTextStyle: const TextStyle(
                                                    color: Color(0xFFE8EEF4),
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: 'KurdishFont',
                                                  ),
                                                  leftChevronIcon: const Icon(
                                                    Icons.chevron_left_rounded,
                                                    color: Color(0xFF42A5F5),
                                                  ),
                                                  rightChevronIcon: const Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: Color(0xFF42A5F5),
                                                  ),
                                                ),
                                                calendarStyle: const CalendarStyle(
                                                  outsideDaysVisible: true,
                                                  markersMaxCount: 0,
                                                  cellMargin: EdgeInsets.zero,
                                                  defaultDecoration:
                                                      BoxDecoration(shape: BoxShape.rectangle),
                                                  weekendDecoration:
                                                      BoxDecoration(shape: BoxShape.rectangle),
                                                  outsideDecoration:
                                                      BoxDecoration(shape: BoxShape.rectangle),
                                                  todayDecoration:
                                                      BoxDecoration(shape: BoxShape.rectangle),
                                                  selectedDecoration:
                                                      BoxDecoration(shape: BoxShape.rectangle),
                                                  disabledDecoration:
                                                      BoxDecoration(shape: BoxShape.rectangle),
                                                  defaultTextStyle: TextStyle(
                                                    fontSize: 0.1,
                                                    color: Colors.transparent,
                                                  ),
                                                  weekendTextStyle: TextStyle(
                                                    fontSize: 0.1,
                                                    color: Colors.transparent,
                                                  ),
                                                  outsideTextStyle: TextStyle(
                                                    fontSize: 0.1,
                                                    color: Colors.transparent,
                                                  ),
                                                  todayTextStyle: TextStyle(
                                                    fontSize: 0.1,
                                                    color: Colors.transparent,
                                                  ),
                                                  selectedTextStyle: TextStyle(
                                                    fontSize: 0.1,
                                                    color: Colors.transparent,
                                                  ),
                                                ),
                                                onPageChanged: (focused) {
                                                  setState(() {
                                                    _focusedDay = focused;
                                                  });
                                                },
                                                onDaySelected: (sel, foc) {
                                                  setState(() {
                                                    _selectedDay = sel;
                                                    _focusedDay = foc;
                                                  });
                                                  _openDaySheet(
                                                    context: context,
                                                    day: sel,
                                                    weekly: weekly,
                                                    dateOverrides: dateOverrides,
                                                    monthAppointments: appts,
                                                    monthBlocks: blocks,
                                                    slotDurationMinutes:
                                                        effectiveAppointmentSlotMinutes(
                                                      dateOnly: DateTime(
                                                        sel.year,
                                                        sel.month,
                                                        sel.day,
                                                      ),
                                                      dateOverrides:
                                                          dateOverrides,
                                                      doctorUserData: snapData,
                                                    ),
                                                  );
                                                },
                                                calendarBuilders: CalendarBuilders(
                                                  defaultBuilder: (context, day, fd) {
                                                    final key = DateTime(
                                                      day.year,
                                                      day.month,
                                                      day.day,
                                                    );
                                                    final sel = _selectedDay != null &&
                                                        isSameDay(_selectedDay!, day);
                                                    return _connectStyleMonthCell(
                                                      day: day,
                                                      focusedMonth: fd,
                                                      visual: visuals[key],
                                                      isToday: isSameDay(day, DateTime.now()),
                                                      isSelected: sel,
                                                    );
                                                  },
                                                  todayBuilder: (context, day, fd) {
                                                    final key = DateTime(
                                                      day.year,
                                                      day.month,
                                                      day.day,
                                                    );
                                                    final sel = _selectedDay != null &&
                                                        isSameDay(_selectedDay!, day);
                                                    return _connectStyleMonthCell(
                                                      day: day,
                                                      focusedMonth: fd,
                                                      visual: visuals[key],
                                                      isToday: true,
                                                      isSelected: sel,
                                                    );
                                                  },
                                                  selectedBuilder: (context, day, fd) {
                                                    final key = DateTime(
                                                      day.year,
                                                      day.month,
                                                      day.day,
                                                    );
                                                    return _connectStyleMonthCell(
                                                      day: day,
                                                      focusedMonth: fd,
                                                      visual: visuals[key],
                                                      isToday: isSameDay(day, DateTime.now()),
                                                      isSelected: true,
                                                    );
                                                  },
                                                  outsideBuilder: (context, day, fd) {
                                                    final key = DateTime(
                                                      day.year,
                                                      day.month,
                                                      day.day,
                                                    );
                                                    final sel = _selectedDay != null &&
                                                        isSameDay(_selectedDay!, day);
                                                    return _connectStyleMonthCell(
                                                      day: day,
                                                      focusedMonth: fd,
                                                      visual: visuals[key],
                                                      isToday: isSameDay(day, DateTime.now()),
                                                      isSelected: sel,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (widget.canManage) ...[
                                            const SizedBox(height: 16),
                                            OutlinedButton.icon(
                                              onPressed: _selectedDay == null
                                                  ? null
                                                  : () => _blockWholeDay(
                                                        context,
                                                        doctorId,
                                                        _selectedDay!,
                                                      ),
                                              icon: const Icon(Icons.block_rounded,
                                                  color: Color(0xFFFF8A80)),
                                              label: Text(
                                                s.translate('master_calendar_block_day'),
                                                style: const TextStyle(
                                                  fontFamily: 'KurdishFont',
                                                  color: Color(0xFFFF8A80),
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                  color: Color(0xFFFF8A80),
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 24),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _blockWholeDay(
    BuildContext context,
    String doctorId,
    DateTime day,
  ) async {
    final s = S.of(context);
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_busy_rounded, color: Color(0xFFFF8A80)),
              title: Text(
                s.translate('master_calendar_block_day_off'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFD9E2EC),
                ),
              ),
              onTap: () => Navigator.pop(ctx, CalendarBlockFields.kindOff),
            ),
            ListTile(
              leading: const Icon(Icons.emergency_rounded, color: Color(0xFFFF7043)),
              title: Text(
                s.translate('master_calendar_block_day_emergency'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFD9E2EC),
                ),
              ),
              onTap: () => Navigator.pop(ctx, CalendarBlockFields.kindEmergency),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !context.mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final start = DateTime(day.year, day.month, day.day);
    try {
      await FirebaseFirestore.instance
          .collection(CalendarBlockFields.collection)
          .add({
        AppointmentFields.doctorId: doctorId,
        AppointmentFields.date: Timestamp.fromDate(start),
        'wholeDay': true,
        CalendarBlockFields.blockKind: kind,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('master_calendar_block_saved'),
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${s.translate('save_error')}: $e',
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    }
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.loc});

  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color fill, Color border) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1.2),
        ),
      );
    }

    Widget item(Widget d, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          d,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF829AB1),
                fontSize: 11,
                fontFamily: 'KurdishFont',
              ),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        item(
          dot(_kCalGreenFill, _kCalGreenBorder),
          loc.translate('master_calendar_legend_green'),
        ),
        item(
          dot(_kCalAmberFill, _kCalAmberBorder),
          loc.translate('master_calendar_legend_amber'),
        ),
        item(
          dot(_kCalRedFill, _kCalRedBorder),
          loc.translate('master_calendar_legend_red_off'),
        ),
      ],
    );
  }
}

String _blockSubtitleForData(BuildContext context, Map<String, dynamic> data) {
  final s = S.of(context);
  final k = (data[CalendarBlockFields.blockKind] ?? '').toString();
  if (k == CalendarBlockFields.kindEmergency) {
    return s.translate('master_calendar_blocked_emergency');
  }
  if (k == CalendarBlockFields.kindOff) {
    return s.translate('master_calendar_blocked_off');
  }
  return s.translate('master_calendar_slot_blocked');
}

class _DayAgendaPanel extends StatelessWidget {
  const _DayAgendaPanel({
    required this.scrollController,
    required this.day,
    required this.doctorId,
    required this.weekly,
    this.dateOverrides,
    required this.monthAppointments,
    required this.monthBlocks,
    required this.slotDurationMinutes,
    required this.canManage,
    required this.onChanged,
  });

  final ScrollController scrollController;
  final DateTime day;
  final String doctorId;
  final Map<String, dynamic>? weekly;
  final Map<String, dynamic>? dateOverrides;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> monthAppointments;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> monthBlocks;
  final int slotDurationMinutes;
  final bool canManage;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final key = DateTime(day.year, day.month, day.day);
    final win = workingWindowForDateWithOverrides(key, weekly, dateOverrides);

    final apptsToday = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in monthAppointments) {
      final data = doc.data();
      final ts = data[AppointmentFields.date];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.year != key.year || dt.month != key.month || dt.day != key.day) {
        continue;
      }
      final t = (data[AppointmentFields.time] ?? '').toString().trim();
      if (t.isEmpty) continue;
      final parts = t.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final mi = int.tryParse(parts[1].trim()) ?? 0;
      final norm =
          '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
      apptsToday[norm] = doc;
    }

    final slots = win == null
        ? <int>[]
        : slotStartMinutesForWindow(
            win.startMinutes,
            win.endMinutes,
            step: slotDurationMinutes,
          );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          DateFormat.yMMMEd().format(key),
          style: const TextStyle(
            color: Color(0xFFD9E2EC),
            fontFamily: 'KurdishFont',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        if (win == null)
          Text(
            s.translate('master_calendar_day_off'),
            style: const TextStyle(
              color: Color(0xFF829AB1),
              fontFamily: 'KurdishFont',
            ),
          )
        else
          ...slots.map((m) {
            final label = formatSlotMinutesKey(m);
            final end = m + slotDurationMinutes;

            String? blockId;
            Map<String, dynamic>? blockData;
            for (final doc in monthBlocks) {
              final data = doc.data();
              final ts = data[AppointmentFields.date];
              if (ts is! Timestamp) continue;
              final dt = ts.toDate();
              if (dt.year != key.year ||
                  dt.month != key.month ||
                  dt.day != key.day) {
                continue;
              }
              if (_slotOverlapsBlockPublic(m, end, data)) {
                blockId = doc.id;
                blockData = data;
                break;
              }
            }

            final appt = apptsToday[label];
            final st = appt != null
                ? (appt.data()[AppointmentFields.status] ?? 'pending')
                    .toString()
                    .toLowerCase()
                : '';
            final isCancelled = st == 'cancelled';
            final booked = appt != null && !isCancelled;

            if (blockId != null && blockData != null) {
              return _SlotTile(
                timeLabel: label,
                subtitle: _blockSubtitleForData(context, blockData),
                statusStripColor: const Color(0xFF94A3B8),
                trailing: canManage
                    ? TextButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection(CalendarBlockFields.collection)
                              .doc(blockId)
                              .delete();
                          onChanged();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          s.translate('master_calendar_unblock'),
                          style: const TextStyle(fontFamily: 'KurdishFont'),
                        ),
                      )
                    : null,
              );
            }

            if (booked) {
              final aptDoc = appt;
              final name =
                  (aptDoc.data()[AppointmentFields.patientName] ?? '—').toString();
              return _SlotTile(
                timeLabel: label,
                subtitle:
                    '${s.translate('master_calendar_booked')}: $name (${aptDoc.data()[AppointmentFields.status] ?? 'pending'})',
                statusStripColor: _kCalRedBorder,
                trailing: canManage
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Color(0xFF829AB1)),
                        onSelected: (v) async {
                          if (v == 'cancel') {
                            await aptDoc.reference.update({
                              AppointmentFields.status: 'cancelled',
                              AppointmentFields.updatedAt:
                                  FieldValue.serverTimestamp(),
                            });
                          } else if (v == 'done') {
                            await aptDoc.reference.update({
                              AppointmentFields.status: 'completed',
                              AppointmentFields.updatedAt:
                                  FieldValue.serverTimestamp(),
                            });
                          }
                          onChanged();
                          if (context.mounted) Navigator.pop(context);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'done',
                            child: Text(
                              s.translate('master_calendar_mark_complete'),
                              style: const TextStyle(fontFamily: 'KurdishFont'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text(
                              s.translate('master_calendar_cancel_appt'),
                              style: const TextStyle(fontFamily: 'KurdishFont'),
                            ),
                          ),
                        ],
                      )
                    : null,
              );
            }

            return _SlotTile(
              timeLabel: label,
              subtitle: s.translate('master_calendar_slot_free'),
              statusStripColor: _kCalGreenBorder,
              onTap: canManage
                  ? () => _staffFreeSlotActions(
                        context,
                        doctorId,
                        key,
                        m,
                        slotDurationMinutes,
                        onChanged,
                      )
                  : () => _patientBookSlot(context, doctorId, key, m),
            );
          }),
      ],
    );
  }

  static bool _slotOverlapsBlockPublic(
    int slotStart,
    int slotEndExclusive,
    Map<String, dynamic> block,
  ) {
    if (block['wholeDay'] == true) return true;
    final sm = (block['startMinutes'] as num?)?.toInt();
    final em = (block['endMinutes'] as num?)?.toInt();
    if (sm == null || em == null) return false;
    return slotStart < em && slotEndExclusive > sm;
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.timeLabel,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.statusStripColor,
  });

  final String timeLabel;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? statusStripColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF252640),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: trailing == null ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (statusStripColor != null) ...[
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusStripColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Color(0xFF42A5F5),
                      fontWeight: FontWeight.w800,
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF829AB1),
                      fontFamily: 'KurdishFont',
                      fontSize: 13,
                    ),
                  ),
                ),
                ...(trailing != null ? [trailing!] : const <Widget>[]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _staffFreeActionsSheet(
  BuildContext context,
  String doctorId,
  DateTime day,
  int slotMinutes,
  int slotDurationMinutes,
  VoidCallback onChanged,
) async {
  final s = S.of(context);
  final outerCtx = context;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1D1E33),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_rounded, color: Color(0xFF42A5F5)),
              title: Text(
                s.translate('master_calendar_add_walkin'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFD9E2EC),
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final nameController = TextEditingController();
                final rootCtx = context;
                final ok = await showDialog<bool>(
                  context: rootCtx,
                  builder: (dctx) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF1D1E33),
                      title: Text(
                        s.translate('master_calendar_add_walkin'),
                        style: const TextStyle(
                          fontFamily: 'KurdishFont',
                          color: Color(0xFFD9E2EC),
                        ),
                      ),
                      content: TextField(
                        controller: nameController,
                        style: const TextStyle(
                          color: Color(0xFFD9E2EC),
                          fontFamily: 'KurdishFont',
                        ),
                        decoration: InputDecoration(
                          labelText: s.translate('doctor_appt_patient_name_label'),
                          labelStyle: const TextStyle(color: Color(0xFF829AB1)),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: Text(s.translate('action_cancel')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, true),
                          child: Text(s.translate('confirm_booking')),
                        ),
                      ],
                    );
                  },
                );
                if (ok != true || !rootCtx.mounted) return;
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final err = await createStaffAppointment(
                  doctorId: doctorId,
                  dateLocal: day,
                  slotStartMinutes: slotMinutes,
                  patientName: nameController.text,
                  createdByUid: uid,
                );
                nameController.dispose();
                if (!rootCtx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        s.translate(err),
                        style: const TextStyle(fontFamily: 'KurdishFont'),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        s.translate('master_calendar_saved'),
                        style: const TextStyle(fontFamily: 'KurdishFont'),
                      ),
                    ),
                  );
                }
                onChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_rounded, color: Color(0xFFFF8A80)),
              title: Text(
                s.translate('master_calendar_block_slot_off'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFD9E2EC),
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                try {
                  await FirebaseFirestore.instance
                      .collection(CalendarBlockFields.collection)
                      .add({
                    AppointmentFields.doctorId: doctorId,
                    AppointmentFields.date: Timestamp.fromDate(
                      DateTime(day.year, day.month, day.day),
                    ),
                    'wholeDay': false,
                    'startMinutes': slotMinutes,
                    'endMinutes': slotMinutes + slotDurationMinutes,
                    CalendarBlockFields.blockKind: CalendarBlockFields.kindOff,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': uid,
                  });
                  if (outerCtx.mounted) {
                    ScaffoldMessenger.of(outerCtx).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.translate('master_calendar_block_saved'),
                          style: const TextStyle(fontFamily: 'KurdishFont'),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (outerCtx.mounted) {
                    ScaffoldMessenger.of(outerCtx).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
                onChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency_rounded, color: Color(0xFFFF7043)),
              title: Text(
                s.translate('master_calendar_block_slot_emergency'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFD9E2EC),
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                try {
                  await FirebaseFirestore.instance
                      .collection(CalendarBlockFields.collection)
                      .add({
                    AppointmentFields.doctorId: doctorId,
                    AppointmentFields.date: Timestamp.fromDate(
                      DateTime(day.year, day.month, day.day),
                    ),
                    'wholeDay': false,
                    'startMinutes': slotMinutes,
                    'endMinutes': slotMinutes + slotDurationMinutes,
                    CalendarBlockFields.blockKind: CalendarBlockFields.kindEmergency,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': uid,
                  });
                  if (outerCtx.mounted) {
                    ScaffoldMessenger.of(outerCtx).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.translate('master_calendar_block_saved'),
                          style: const TextStyle(fontFamily: 'KurdishFont'),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (outerCtx.mounted) {
                    ScaffoldMessenger.of(outerCtx).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
                onChanged();
              },
            ),
          ],
        ),
      );
    },
  );
}

void _staffFreeSlotActions(
  BuildContext context,
  String doctorId,
  DateTime day,
  int slotMinutes,
  int slotDurationMinutes,
  VoidCallback onChanged,
) {
  _staffFreeActionsSheet(
    context,
    doctorId,
    day,
    slotMinutes,
    slotDurationMinutes,
    onChanged,
  );
}

Future<void> _patientBookSlot(
  BuildContext context,
  String doctorId,
  DateTime day,
  int slotMinutes,
) async {
  final rootCtx = context;
  final s = S.of(rootCtx);
  final lang = AppLocaleScope.of(rootCtx).effectiveLanguage;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    ScaffoldMessenger.of(rootCtx).showSnackBar(
      SnackBar(
        content: Text(
          s.translate('login_required'),
          style: const TextStyle(fontFamily: 'KurdishFont'),
        ),
      ),
    );
    return;
  }

  final patientSnap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final patientName =
      (patientSnap.data()?['fullName'] ?? '').toString().trim().isEmpty
          ? s.translate('patient_default')
          : (patientSnap.data()?['fullName'] ?? '').toString();

  final doctorSnap =
      await FirebaseFirestore.instance.collection('users').doc(doctorId).get();
  final fallback = localizedDoctorFullName(
    doctorSnap.data() ?? <String, dynamic>{},
    lang,
  );

  final err = await createPatientAppointment(
    doctorId: doctorId,
    dateLocal: day,
    slotStartMinutes: slotMinutes,
    patientName: patientName,
    doctorDisplayFallback: fallback,
  );

  if (!rootCtx.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(rootCtx).showSnackBar(
      SnackBar(
        content: Text(
          s.translate(err),
          style: const TextStyle(fontFamily: 'KurdishFont'),
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: rootCtx,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1D1E33),
      title: Text(
        s.translate('booking_success_title'),
        style: const TextStyle(
          fontFamily: 'KurdishFont',
          color: Color(0xFFD9E2EC),
        ),
      ),
      content: Text(
        s.translate('booking_success_body'),
        style: const TextStyle(
          fontFamily: 'KurdishFont',
          color: Color(0xFF829AB1),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(s.translate('ok')),
        ),
      ],
    ),
  );
}
