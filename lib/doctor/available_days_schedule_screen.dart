import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/available_days_queries.dart';
import '../firestore/firestore_index_error_log.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../auth/firestore_user_doc_id.dart';
import 'day_management_screen.dart';

/// Doctor / Secretary: [TableCalendar] for [available_days] — red closed, green open, badge = bookings (doctor only).
class AvailableDaysScheduleScreen extends StatefulWidget {
  const AvailableDaysScheduleScreen({
    super.key,
    this.embedded = false,
    this.managedDoctorUserId,
  });

  /// Embedded in [DoctorHomeScreen] (no app bar).
  final bool embedded;

  /// Secretary: managed doctor. Null = current user (doctor).
  final String? managedDoctorUserId;

  @override
  State<AvailableDaysScheduleScreen> createState() =>
      _AvailableDaysScheduleScreenState();
}

class _AvailableDaysScheduleScreenState extends State<AvailableDaysScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String? get _doctorUid {
    final m = widget.managedDoctorUserId?.trim();
    if (m != null && m.isNotEmpty) return m;
    final byDoc = firestoreUserDocId(FirebaseAuth.instance.currentUser).trim();
    if (byDoc.isNotEmpty) return byDoc;
    final byUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    return byUid.isEmpty ? null : byUid;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Booking count badge only on the doctor's own calendar (not secretary view).
  bool get _showBookingBadge => widget.managedDoctorUserId == null;

  Future<void> _showOpenDayDialog(
    BuildContext context,
    String uid,
    DateTime day,
  ) async {
    final s = S.of(context);
    final picked = _dateOnly(day);
    TimeOfDay openingTime = const TimeOfDay(hour: 16, minute: 0);
    TimeOfDay closingTime = const TimeOfDay(hour: 20, minute: 0);
    int durationMinutes = 30;
    const durationChoices = [15, 30, 45, 60];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final localeTag = Localizations.localeOf(ctx).toLanguageTag();
            final openingDt = DateTime(
              2000,
              1,
              1,
              openingTime.hour,
              openingTime.minute,
            );
            final openingLabel = DateFormat.jm(localeTag).format(openingDt);
            final closingDt = DateTime(
              2000,
              1,
              1,
              closingTime.hour,
              closingTime.minute,
            );
            final closingLabel = DateFormat.jm(localeTag).format(closingDt);

            return AlertDialog(
              backgroundColor: const Color(0xFF1D1E33),
              title: Text(
                s.translate('available_days_open_day_title'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFFD9E2EC),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      DateFormat.yMMMEd(localeTag).format(picked),
                      style: const TextStyle(
                        fontFamily: 'KurdishFont',
                        color: Color(0xFFE8EEF4),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.translate('available_days_opening_time_label'),
                        style: const TextStyle(
                          fontFamily: 'KurdishFont',
                          color: Color(0xFF829AB1),
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        openingLabel,
                        style: const TextStyle(
                          fontFamily: 'KurdishFont',
                          color: Color(0xFFE8EEF4),
                          fontSize: 16,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFF42A5F5),
                      ),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: openingTime,
                        );
                        if (t != null) setSt(() => openingTime = t);
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.translate('available_days_closing_time_label'),
                        style: const TextStyle(
                          fontFamily: 'KurdishFont',
                          color: Color(0xFF829AB1),
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        closingLabel,
                        style: const TextStyle(
                          fontFamily: 'KurdishFont',
                          color: Color(0xFFE8EEF4),
                          fontSize: 16,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.schedule_send_rounded,
                        color: Color(0xFF42A5F5),
                      ),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: closingTime,
                        );
                        if (t != null) setSt(() => closingTime = t);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.translate('available_days_duration_label'),
                      style: const TextStyle(
                        fontFamily: 'KurdishFont',
                        color: Color(0xFF829AB1),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: durationMinutes,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2A2D45),
                          style: const TextStyle(
                            fontFamily: 'KurdishFont',
                            color: Color(0xFFE8EEF4),
                            fontSize: 16,
                          ),
                          items: [
                            for (final m in durationChoices)
                              DropdownMenuItem<int>(
                                value: m,
                                child: Text(
                                  s.translate(
                                    'duration_minutes_option',
                                    params: {'n': '$m'},
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) setSt(() => durationMinutes = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    s.translate('action_cancel'),
                    style: const TextStyle(
                      fontFamily: 'KurdishFont',
                      color: Color(0xFF829AB1),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: const Color(0xFF102A43),
                  ),
                  child: Text(
                    s.translate('available_days_open_day_save'),
                    style: const TextStyle(fontFamily: 'KurdishFont'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !context.mounted) return;
    final hh = openingTime.hour.toString().padLeft(2, '0');
    final mm = openingTime.minute.toString().padLeft(2, '0');
    final ch = closingTime.hour.toString().padLeft(2, '0');
    final cm = closingTime.minute.toString().padLeft(2, '0');
    try {
      await openAvailableDay(
        doctorUserId: uid,
        dateLocal: picked,
        startTimeHhMm: '$hh:$mm',
        closingTimeHhMm: '$ch:$cm',
        appointmentDurationMinutes: durationMinutes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$e',
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    }
  }

  void _handleDayTap(
    BuildContext context,
    String uid,
    DateTime selected,
    DateTime focused,
    Map<String, Map<String, dynamic>> openByDocId,
  ) {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    final docId = availableDayDocumentId(
      doctorUserId: uid,
      dateLocal: _dateOnly(selected),
    );
    final data = openByDocId[docId];
    if (data != null && availableDayIsOpen(data)) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DayManagementScreen(
            doctorUserId: uid,
            availableDayDocId: docId,
            dateLocal: _dateOnly(selected),
          ),
        ),
      );
    } else {
      _showOpenDayDialog(context, uid, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final uid = _doctorUid;
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);

    final body = uid == null
        ? Center(
            child: Text(
              s.translate('login_required'),
              style: const TextStyle(
                color: Color(0xFF829AB1),
                fontFamily: 'KurdishFont',
              ),
            ),
          )
        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: watchAvailableDaysInRange(
              doctorUserId: uid,
              rangeStartInclusiveLocal: monthStart,
              rangeEndExclusiveLocal: monthEnd,
            ),
            builder: (context, daySnap) {
              if (daySnap.hasError) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => logFirestoreIndexHelpOnce(
                    daySnap.error,
                    tag: 'available_days_calendar',
                    expectedCompositeIndexHint:
                        kAvailableDaysDoctorDateRangeIndexHint,
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    s.translate(
                      'doctors_load_error_detail',
                      params: {'error': '${daySnap.error}'},
                    ),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: appointmentsForDoctorDateRange(
                  doctorUserId: uid,
                  rangeStartInclusiveLocal: monthStart,
                  rangeEndExclusiveLocal: monthEnd,
                ).snapshots(),
                builder: (context, apptSnap) {
                  if (apptSnap.hasError) {
                    return Padding(
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
                      ),
                    );
                  }

                  final openByDocId = <String, Map<String, dynamic>>{};
                  for (final d in daySnap.data?.docs ?? []) {
                    openByDocId[d.id] = d.data();
                  }

                  final bookingCounts = countBookingsByAvailableDayDocId(
                    apptSnap.data?.docs ?? const [],
                  );

                  final loadingDays =
                      daySnap.connectionState == ConnectionState.waiting &&
                          !daySnap.hasData;
                  final loadingAppts =
                      apptSnap.connectionState == ConnectionState.waiting &&
                          !apptSnap.hasData;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      widget.embedded ? 8 : 12,
                      12,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (loadingDays || loadingAppts)
                          const LinearProgressIndicator(
                            minHeight: 2,
                            color: Color(0xFF42A5F5),
                          ),
                        if (loadingDays || loadingAppts)
                          const SizedBox(height: 8),
                        Text(
                          s.translate('available_days_calendar_legend'),
                          style: const TextStyle(
                            fontFamily: 'KurdishFont',
                            color: Color(0xFF829AB1),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF12152A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 10, 6, 14),
                            child: TableCalendar<int>(
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
                              startingDayOfWeek: StartingDayOfWeek.saturday,
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
                              eventLoader: (day) {
                                final docId = availableDayDocumentId(
                                  doctorUserId: uid,
                                  dateLocal: _dateOnly(day),
                                );
                                final row = openByDocId[docId];
                                final open =
                                    row != null && availableDayIsOpen(row);
                                final c = bookingCounts[docId] ?? 0;
                                final isOutside = day.month !=
                                        _focusedDay.month ||
                                    day.year != _focusedDay.year;
                                if (!_showBookingBadge ||
                                    !open ||
                                    c < 1 ||
                                    isOutside) {
                                  return [];
                                }
                                return <int>[c];
                              },
                              calendarStyle: CalendarStyle(
                                outsideDaysVisible: true,
                                markersMaxCount: 1,
                                // Center the day cell; badge is [Positioned] in [markerBuilder].
                                markersAlignment: Alignment.center,
                                canMarkersOverflow: true,
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
                                setState(() => _focusedDay = focused);
                              },
                              onDaySelected: (sel, foc) => _handleDayTap(
                                context,
                                uid,
                                sel,
                                foc,
                                openByDocId,
                              ),
                              calendarBuilders: CalendarBuilders<int>(
                                markerBuilder: (context, day, events) {
                                  if (events.isEmpty) return null;
                                  final count = events.first;
                                  if (count < 1) return null;
                                  final label =
                                      count > 99 ? '99' : '$count';
                                  // Fixed corner overlay — does not change day-number layout.
                                  return PositionedDirectional(
                                    top: 2,
                                    end: 2,
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: DecoratedBox(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF06B6D4),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x40000000),
                                              blurRadius: 3,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              label,
                                              style: const TextStyle(
                                                fontFamily: 'KurdishFont',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                defaultBuilder: (ctx, day, fDay) =>
                                    _dayCell(
                                      day: day,
                                      focusedDay: fDay,
                                      uid: uid,
                                      openByDocId: openByDocId,
                                    ),
                                todayBuilder: (ctx, day, fDay) => _dayCell(
                                  day: day,
                                  focusedDay: fDay,
                                  uid: uid,
                                  openByDocId: openByDocId,
                                  isToday: true,
                                ),
                                selectedBuilder: (ctx, day, fDay) => _dayCell(
                                  day: day,
                                  focusedDay: fDay,
                                  uid: uid,
                                  openByDocId: openByDocId,
                                  isSelected: true,
                                ),
                                outsideBuilder: (ctx, day, fDay) => _dayCell(
                                  day: day,
                                  focusedDay: fDay,
                                  uid: uid,
                                  openByDocId: openByDocId,
                                  isOutsideMonth: true,
                                ),
                              ),
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

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: widget.embedded
            ? null
            : AppBar(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: const Color(0xFFD9E2EC),
                title: Text(
                  s.translate('schedule_screen_title'),
                  style: const TextStyle(fontFamily: 'KurdishFont'),
                ),
              ),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _dayCell({
    required DateTime day,
    required DateTime focusedDay,
    required String uid,
    required Map<String, Map<String, dynamic>> openByDocId,
    bool isToday = false,
    bool isSelected = false,
    bool isOutsideMonth = false,
  }) {
    final docId = availableDayDocumentId(
      doctorUserId: uid,
      dateLocal: _dateOnly(day),
    );
    final row = openByDocId[docId];
    final open = row != null && availableDayIsOpen(row);

    final isOutside = isOutsideMonth ||
        day.month != focusedDay.month ||
        day.year != focusedDay.year;

    final fill = isOutside
        ? const Color(0xFF151828)
        : (open ? const Color(0xFF1A2E22) : const Color(0xFF2E1E20));
    final stroke = isOutside
        ? Colors.white10
        : (open
            ? const Color(0xFF34D399).withValues(alpha: 0.45)
            : const Color(0xFFF87171).withValues(alpha: 0.35));

    final borderColor = isSelected
        ? const Color(0xFF7DD3FC)
        : (isToday && !isSelected
            ? const Color(0xFFFCD34D)
            : stroke);
    final double borderWidth =
        isSelected ? 2.5 : (isToday && !isSelected ? 1.5 : 1.0);

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isOutside
                  ? const Color(0xFF64748B)
                  : const Color(0xFFE8EEF4),
            ),
          ),
        ),
      ),
    );
  }
}
