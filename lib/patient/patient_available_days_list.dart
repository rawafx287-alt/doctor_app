import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../firestore/available_days_queries.dart';
import '../firestore/firestore_index_error_log.dart';
import '../locale/app_localizations.dart';
import 'booking_summary_screen.dart';

const Color _kDoctorNameNavy = Color(0xFF0D2137);
const Color _kDaysOfWeekBlue = Color(0xFF0D47A1);
const Color _kHintGrey = Color(0xFF455A64);
const Color _kCellText = Color(0xFF37474F);
const Color _kCellMuted = Color(0xFF90A4AE);
const Color _kToastTextGrey = Color(0xFF546E7A);

class _PatientCalendarToast extends StatefulWidget {
  const _PatientCalendarToast({
    required this.message,
    required this.icon,
    required this.onDismissed,
  });

  final String message;
  final IconData icon;
  final VoidCallback onDismissed;

  @override
  State<_PatientCalendarToast> createState() => _PatientCalendarToastState();
}

class _PatientCalendarToastState extends State<_PatientCalendarToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.45),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 2800), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFFE57373).withValues(alpha: 0.45),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.78),
                    const Color(0xFFFFE0B2).withValues(alpha: 0.42),
                    const Color(0xFFFFCDD2).withValues(alpha: 0.38),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD84315).withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: 22,
                      color: const Color(0xFFBF360C).withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'KurdishFont',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.35,
                          color: _kToastTextGrey,
                          letterSpacing: 0.12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  OverlayEntry? _calendarToastEntry;

  String get _doctorUid => widget.doctorId.trim();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Glass toast: fade + slide up from bottom (past / closed day feedback).
  void _showCalendarToast(
    BuildContext context,
    String message, {
    IconData icon = Icons.event_busy_rounded,
  }) {
    _calendarToastEntry?.remove();
    _calendarToastEntry = null;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Center(
              child: _PatientCalendarToast(
                message: message,
                icon: icon,
                onDismissed: () {
                  entry.remove();
                  if (_calendarToastEntry == entry) {
                    _calendarToastEntry = null;
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
    _calendarToastEntry = entry;
    overlay.insert(entry);
  }

  @override
  void dispose() {
    _calendarToastEntry?.remove();
    super.dispose();
  }

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
      _showCalendarToast(
        context,
        s.translate('available_days_patient_past_day'),
        icon: Icons.schedule_rounded,
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
      _showCalendarToast(
        context,
        s.translate('available_days_patient_closed_day'),
        icon: Icons.event_busy_rounded,
      );
      return;
    }

    _openSummary(context, availableDayDocId: docId, dateLocal: sel);
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
            color: _kDoctorNameNavy,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'KurdishFont',
            height: 1.2,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.translate('available_days_patient_hint_calendar'),
          style: const TextStyle(
            color: _kHintGrey,
            fontSize: 13,
            fontFamily: 'KurdishFont',
            fontWeight: FontWeight.w600,
            height: 1.4,
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

            final loading =
                daySnap.connectionState == ConnectionState.waiting &&
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(
                            0xFF90CAF9,
                          ).withValues(alpha: 0.55),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1976D2,
                            ).withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
                          locale: Localizations.localeOf(
                            context,
                          ).toLanguageTag(),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              color: _kDaysOfWeekBlue,
                              fontFamily: 'KurdishFont',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                            weekendStyle: TextStyle(
                              color: _kDaysOfWeekBlue,
                              fontFamily: 'KurdishFont',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            headerPadding: EdgeInsets.zero,
                            titleTextStyle: const TextStyle(
                              color: _kDoctorNameNavy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'KurdishFont',
                            ),
                            leftChevronIcon: const Icon(
                              Icons.chevron_left_rounded,
                              color: Color(0xFF1565C0),
                              size: 22,
                            ),
                            rightChevronIcon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF1565C0),
                              size: 22,
                            ),
                          ),
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: true,
                            markersMaxCount: 0,
                            cellMargin: EdgeInsets.zero,
                            defaultDecoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                            ),
                            weekendDecoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                            ),
                            outsideDecoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                            ),
                            todayDecoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                            ),
                            selectedDecoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                            ),
                            disabledDecoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                            ),
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
                          onDaySelected: (sel, foc) =>
                              _onDaySelected(context, sel, foc, openByDocId),
                          calendarBuilders: CalendarBuilders<void>(
                            defaultBuilder: (ctx, day, fDay) => _patientDayCell(
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
                            outsideBuilder: (ctx, day, fDay) => _patientDayCell(
                              day: day,
                              focusedDay: fDay,
                              openByDocId: openByDocId,
                              isOutsideMonth: true,
                            ),
                          ),
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

    final isOutside =
        isOutsideMonth ||
        day.month != focusedDay.month ||
        day.year != focusedDay.year;

    final today = _dateOnly(DateTime.now());
    final dayOnly = _dateOnly(day);
    final isPast = dayOnly.isBefore(today);

    Color fill;
    Color borderColor;
    double borderWidth;

    if (isSelected) {
      fill = Colors.transparent;
      borderColor = Colors.transparent;
      borderWidth = 0;
    } else if (isOutside) {
      fill = const Color(0xFFEDEEF1);
      borderColor = const Color(0xFFB0BEC5).withValues(alpha: 0.35);
      borderWidth = 0.8;
    } else if (isPast) {
      fill = const Color(0xFFE8EAED);
      borderColor = const Color(0xFFCFD8DC).withValues(alpha: 0.6);
      borderWidth = 0.8;
    } else if (open) {
      fill = const Color(0xFFE3F5E8);
      borderColor = const Color(0xFF66BB6A).withValues(alpha: 0.45);
      borderWidth = 1.0;
    } else {
      fill = const Color(0xFFF0F2F4);
      borderColor = const Color(0xFFB0BEC5).withValues(alpha: 0.4);
      borderWidth = 0.8;
    }

    if (isToday && !isSelected) {
      borderColor = const Color(0xFF1565C0).withValues(alpha: 0.65);
      borderWidth = 1.6;
    }

    Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isOutside || isPast) {
      textColor = _kCellMuted;
    } else if (open) {
      textColor = const Color(0xFF1B5E20);
    } else {
      textColor = _kCellText;
    }

    final radius = BorderRadius.circular(10);

    Widget cellChild = Container(
      decoration: BoxDecoration(
        color: isSelected ? null : fill,
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF64B5F6),
                  Color(0xFF1976D2),
                  Color(0xFF0D47A1),
                ],
                stops: [0.0, 0.45, 1.0],
              )
            : null,
        borderRadius: radius,
        border: isSelected
            ? null
            : Border.all(color: borderColor, width: borderWidth),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.42),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontFamily: 'KurdishFont',
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: textColor,
        ),
      ),
    );

    return Padding(padding: const EdgeInsets.all(2), child: cellChild);
  }
}
