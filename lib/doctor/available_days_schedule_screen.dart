import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:table_calendar/table_calendar.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/available_days_queries.dart';
import '../firestore/firestore_index_error_log.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../auth/firestore_user_doc_id.dart';
import '../theme/staff_premium_theme.dart';
import 'day_management_screen.dart';

/// Metallic silver rim — 0.8 px stroke, matches patient profile / brand cards.
const LinearGradient _kCalendarSilverRimGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF0F0F0), Color(0xFFD1D1D1), Color(0xFFE0E0E0)],
  stops: [0.0, 0.48, 1.0],
);

/// Open day cell fill (deep medical green).
const Color _kScheduleOpenDayFill = Color(0xFF004D40);

/// Closed day cell fill (deep rich red).
const Color _kScheduleClosedDayFill = Color(0xFFB71C1C);

String _scheduleWeekdayTranslationKey(DateTime d) {
  switch (d.weekday) {
    case DateTime.monday:
      return 'weekday_mon';
    case DateTime.tuesday:
      return 'weekday_tue';
    case DateTime.wednesday:
      return 'weekday_wed';
    case DateTime.thursday:
      return 'weekday_thu';
    case DateTime.friday:
      return 'weekday_fri';
    case DateTime.saturday:
      return 'weekday_sat';
    case DateTime.sunday:
    default:
      return 'weekday_sun';
  }
}

String _scheduleDigitsForLanguage(String asciiDigits, HrNoraLanguage lang) {
  if (lang == HrNoraLanguage.en) return asciiDigits;
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final unit in asciiDigits.runes) {
    final ch = String.fromCharCode(unit);
    final v = int.tryParse(ch);
    if (v != null && v >= 0 && v <= 9) {
      b.write(eastern[v]);
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

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

class _AvailableDaysScheduleScreenState
    extends State<AvailableDaysScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Timer? _todayClockTimer;

  String? get _doctorUid {
    final m = widget.managedDoctorUserId?.trim();
    if (m != null && m.isNotEmpty) return m;
    final byDoc = firestoreUserDocId(FirebaseAuth.instance.currentUser).trim();
    if (byDoc.isNotEmpty) return byDoc;
    final byUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    return byUid.isEmpty ? null : byUid;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _todayClockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _todayClockTimer?.cancel();
    super.dispose();
  }

  /// Booking count badge only on the doctor's own calendar (not secretary view).
  bool get _showBookingBadge => widget.managedDoctorUserId == null;

  static const Color _kTodayCardFill = Color(0xFFF0F8FF);

  /// Card under the grid: label + gold icon + weekday line + Y/M/D numerals (LTR).
  Widget _buildTodayDateCard(BuildContext context, AppLocalizations strings) {
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    final appDir = Directionality.of(context);
    final now = DateTime.now();
    final weekdayName = strings.translate(_scheduleWeekdayTranslationKey(now));
    final dayPart = _scheduleDigitsForLanguage('${now.day}', lang);
    final monthPart = _scheduleDigitsForLanguage('${now.month}', lang);
    final yearPart = _scheduleDigitsForLanguage('${now.year}', lang);
    final dateNumericLtr = '$yearPart / $monthPart / $dayPart';

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kTodayCardFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: kStaffSilverBorder,
            width: kStaffCardOutlineWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.translate('schedule_today_heading'),
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kStaffMutedText,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.event_note, size: 22, color: kStaffLuxGold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Directionality(
                        textDirection: appDir,
                        child: Text(
                          weekdayName,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.35,
                            color: kStaffBodyText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            dateNumericLtr,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.35,
                              color: kStaffBodyText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
              backgroundColor: kStaffCardSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: kStaffSilverBorder,
                  width: kStaffCardOutlineWidth,
                ),
              ),
              title: Text(
                s.translate('available_days_open_day_title'),
                style: staffHeaderTextStyle(fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      DateFormat.yMMMEd(localeTag).format(picked),
                      style: staffHeaderTextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.translate('available_days_opening_time_label'),
                        style: staffLabelTextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        openingLabel,
                        style: staffHeaderTextStyle(fontSize: 16),
                      ),
                      trailing: const Icon(
                        Icons.schedule_rounded,
                        color: kStaffLuxGold,
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
                        style: staffLabelTextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        closingLabel,
                        style: staffHeaderTextStyle(fontSize: 16),
                      ),
                      trailing: const Icon(
                        Icons.schedule_send_rounded,
                        color: kStaffLuxGold,
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
                      style: staffLabelTextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: kStaffSilverBorder,
                          width: kStaffCardOutlineWidth,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: durationMinutes,
                          isExpanded: true,
                          dropdownColor: kStaffCardSurface,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            color: kStaffBodyText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
                    style: staffLabelTextStyle(),
                  ),
                ),
                StaffGoldGradientButton(
                  label: s.translate('available_days_open_day_save'),
                  onPressed: () => Navigator.pop(ctx, true),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  fontSize: 14,
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
            content: Text('$e', style: const TextStyle(fontFamily: 'NRT')),
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
              style: staffLabelTextStyle(),
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
                      fontFamily: 'NRT',
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
                          fontFamily: 'NRT',
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
                            color: kStaffPrimaryNavy,
                          ),
                        if (loadingDays || loadingAppts)
                          const SizedBox(height: 8),
                        Text(
                          s.translate('available_days_calendar_legend'),
                          style: staffLabelTextStyle(
                            fontSize: 12,
                          ).copyWith(height: 1.35, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.8),
                            gradient: _kCalendarSilverRimGradient,
                            boxShadow: [
                              BoxShadow(
                                color: kStaffPrimaryNavy.withValues(
                                  alpha: 0.07,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(0.8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ColoredBox(
                              color: kStaffCardSurface,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  6,
                                  10,
                                  6,
                                  14,
                                ),
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
                                  locale: Localizations.localeOf(
                                    context,
                                  ).toLanguageTag(),
                                  daysOfWeekStyle: DaysOfWeekStyle(
                                    weekdayStyle: TextStyle(
                                      color: kStaffMutedText,
                                      fontFamily: kPatientPrimaryFont,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    weekendStyle: TextStyle(
                                      color: kStaffMutedText,
                                      fontFamily: kPatientPrimaryFont,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  headerStyle: HeaderStyle(
                                    formatButtonVisible: false,
                                    titleCentered: true,
                                    headerPadding: EdgeInsets.zero,
                                    titleTextStyle: TextStyle(
                                      color: kStaffPrimaryNavy,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: kPatientPrimaryFont,
                                    ),
                                    leftChevronIcon: const Icon(
                                      Icons.chevron_left_rounded,
                                      color: kStaffLuxGold,
                                    ),
                                    rightChevronIcon: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: kStaffLuxGold,
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
                                    final isOutside =
                                        day.month != _focusedDay.month ||
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
                                    markersAlignment: Alignment.center,
                                    canMarkersOverflow: true,
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
                                      final lang = AppLocaleScope.of(
                                        context,
                                      ).effectiveLanguage;
                                      final raw =
                                          count > 99 ? '99' : '$count';
                                      final label =
                                          _scheduleDigitsForLanguage(
                                        raw,
                                        lang,
                                      );
                                      return PositionedDirectional(
                                        top: 2,
                                        end: 2,
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: DecoratedBox(
                                            decoration: const BoxDecoration(
                                              color: kStaffPrimaryNavy,
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
                                                    fontFamily:
                                                        kPatientPrimaryFont,
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
                                          context: ctx,
                                          day: day,
                                          focusedDay: fDay,
                                          uid: uid,
                                          openByDocId: openByDocId,
                                        ),
                                    todayBuilder: (ctx, day, fDay) => _dayCell(
                                      context: ctx,
                                      day: day,
                                      focusedDay: fDay,
                                      uid: uid,
                                      openByDocId: openByDocId,
                                      isToday: true,
                                    ),
                                    selectedBuilder: (ctx, day, fDay) =>
                                        _dayCell(
                                          context: ctx,
                                          day: day,
                                          focusedDay: fDay,
                                          uid: uid,
                                          openByDocId: openByDocId,
                                          isSelected: true,
                                        ),
                                    outsideBuilder: (ctx, day, fDay) =>
                                        _dayCell(
                                          context: ctx,
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
                          ),
                        ),
                        _buildTodayDateCard(context, s),
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
        backgroundColor: kStaffShellBackground,
        appBar: widget.embedded
            ? null
            : AppBar(
                backgroundColor: kStaffPrimaryNavy,
                foregroundColor: const Color(0xFFD9E2EC),
                title: Text(
                  s.translate('schedule_screen_title'),
                  style: staffAppBarTitleStyle().copyWith(
                    color: const Color(0xFFD9E2EC),
                  ),
                ),
              ),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _dayCell({
    required BuildContext context,
    required DateTime day,
    required DateTime focusedDay,
    required String uid,
    required Map<String, Map<String, dynamic>> openByDocId,
    bool isToday = false,
    bool isSelected = false,
    bool isOutsideMonth = false,
  }) {
    final displayLang = AppLocaleScope.of(context).effectiveLanguage;
    final dayLabel = _scheduleDigitsForLanguage('${day.day}', displayLang);
    final docId = availableDayDocumentId(
      doctorUserId: uid,
      dateLocal: _dateOnly(day),
    );
    final row = openByDocId[docId];
    final open = row != null && availableDayIsOpen(row);

    final isOutside =
        isOutsideMonth ||
        day.month != focusedDay.month ||
        day.year != focusedDay.year;

    final fill = isOutside
        ? const Color(0xFFECEFF1)
        : (open ? _kScheduleOpenDayFill : _kScheduleClosedDayFill);
    final stroke = isOutside
        ? kStaffSilverBorder.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.22);

    final borderColor = isSelected
        ? kStaffLuxGold
        : (isToday && !isSelected ? kStaffLuxGold : stroke);
    final double borderWidth = isSelected
        ? 2.75
        : (isToday && !isSelected ? 1.75 : 1.0);

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          alignment: Alignment.center,
          child: Text(
            dayLabel,
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isOutside ? kStaffMutedText : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
