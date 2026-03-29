import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../firestore/available_days_queries.dart';
import '../firestore/firestore_index_error_log.dart';
import '../locale/app_localizations.dart';
import 'booking_summary_screen.dart';

/// Patient: [TableCalendar] — green open days, red closed; tap open day to book (no time picker).
class PatientAvailableDaysList extends StatefulWidget {
  const PatientAvailableDaysList({
    super.key,
    required this.doctorId,
    required this.patientName,
    required this.doctorDisplayName,
    required this.mergedDoctorData,
  });

  final String doctorId;
  final String patientName;
  final String doctorDisplayName;
  final Map<String, dynamic> mergedDoctorData;

  @override
  State<PatientAvailableDaysList> createState() =>
      _PatientAvailableDaysListState();
}

class _PatientAvailableDaysListState extends State<PatientAvailableDaysList> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String get _doctorUid => widget.doctorId.trim();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _openSummary(
    BuildContext context, {
    required String availableDayDocId,
    required DateTime dateLocal,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BookingSummaryScreen(
          availableDayDocId: availableDayDocId,
          doctorId: _doctorUid,
          patientName: widget.patientName,
          doctorDisplayName: widget.doctorDisplayName,
          mergedDoctorData: widget.mergedDoctorData,
          dateLocal: dateLocal,
        ),
      ),
    );
  }

  void _onDaySelected(
    BuildContext context,
    DateTime selected,
    DateTime focused,
    Map<String, Map<String, dynamic>> openByDocId,
  ) {
    final s = S.of(context);
    final today = _dateOnly(DateTime.now());
    final sel = _dateOnly(selected);
    if (sel.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('available_days_patient_past_day'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });

    final docId = availableDayDocumentId(
      doctorUserId: _doctorUid,
      dateLocal: sel,
    );
    final data = openByDocId[docId];
    if (data == null || !availableDayIsOpen(data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('available_days_patient_closed_day'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    _openSummary(
      context,
      availableDayDocId: docId,
      dateLocal: sel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.translate('available_days_patient_title'),
          style: const TextStyle(
            color: Color(0xFFE8EEF4),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'KurdishFont',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.translate('available_days_patient_hint_calendar'),
          style: const TextStyle(
            color: Color(0xFF829AB1),
            fontSize: 13,
            fontFamily: 'KurdishFont',
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: watchAvailableDaysInRange(
            doctorUserId: _doctorUid,
            rangeStartInclusiveLocal: monthStart,
            rangeEndExclusiveLocal: monthEnd,
          ),
          builder: (context, daySnap) {
            if (daySnap.hasError) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => logFirestoreIndexHelpOnce(
                  daySnap.error,
                  tag: 'patient_available_days_cal',
                  expectedCompositeIndexHint:
                      kAvailableDaysDoctorDateRangeIndexHint,
                ),
              );
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  s.translate(
                    'doctors_load_error_detail',
                    params: {'error': '${daySnap.error}'},
                  ),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontFamily: 'KurdishFont',
                    fontSize: 12,
                  ),
                ),
              );
            }

            final openByDocId = <String, Map<String, dynamic>>{};
            for (final d in daySnap.data?.docs ?? []) {
              openByDocId[d.id] = d.data();
            }

            final loading = daySnap.connectionState == ConnectionState.waiting &&
                !daySnap.hasData;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: Color(0xFF42A5F5),
                    ),
                  ),
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
                          rowHeight: 48,
                          daysOfWeekHeight: 32,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            weekendStyle: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontFamily: 'KurdishFont',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            headerPadding: EdgeInsets.zero,
                            titleTextStyle: const TextStyle(
                              color: Color(0xFFE8EEF4),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'KurdishFont',
                            ),
                            leftChevronIcon: const Icon(
                              Icons.chevron_left_rounded,
                              color: Color(0xFF42A5F5),
                              size: 22,
                            ),
                            rightChevronIcon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF42A5F5),
                              size: 22,
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
                            setState(() => _focusedDay = focused);
                          },
                          onDaySelected: (sel, foc) => _onDaySelected(
                            context,
                            sel,
                            foc,
                            openByDocId,
                          ),
                          calendarBuilders: CalendarBuilders<void>(
                            defaultBuilder: (ctx, day, fDay) =>
                                _patientDayCell(
                              day: day,
                              focusedDay: fDay,
                              openByDocId: openByDocId,
                            ),
                            todayBuilder: (ctx, day, fDay) => _patientDayCell(
                              day: day,
                              focusedDay: fDay,
                              openByDocId: openByDocId,
                              isToday: true,
                            ),
                            selectedBuilder: (ctx, day, fDay) =>
                                _patientDayCell(
                              day: day,
                              focusedDay: fDay,
                              openByDocId: openByDocId,
                              isSelected: true,
                            ),
                            outsideBuilder: (ctx, day, fDay) =>
                                _patientDayCell(
                              day: day,
                              focusedDay: fDay,
                              openByDocId: openByDocId,
                              isOutsideMonth: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
          },
        ),
      ],
    );
  }

  Widget _patientDayCell({
    required DateTime day,
    required DateTime focusedDay,
    required Map<String, Map<String, dynamic>> openByDocId,
    bool isToday = false,
    bool isSelected = false,
    bool isOutsideMonth = false,
  }) {
    final docId = availableDayDocumentId(
      doctorUserId: _doctorUid,
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

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
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
            fontSize: 14,
            color:
                isOutside ? const Color(0xFF64748B) : const Color(0xFFE8EEF4),
          ),
        ),
      ),
    );
  }
}
