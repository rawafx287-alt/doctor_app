import 'dart:ui' as ui;

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
import '../theme/calendar_crystal_surfaces.dart';
import '../theme/hr_nora_colors.dart';
import '../theme/staff_premium_theme.dart';
import '../widgets/appointment_action_confirm_dialog.dart';
import 'calendar_slot_logic.dart';

const String _kMasterCalendarBrandTitle = 'HR Nora';

// ---------------------------------------------------------------------------
// Secretary calendar — same cell physics as [PatientAvailableDaysList].
// ---------------------------------------------------------------------------
const Color _kSecPatOpenFill = HrNoraColors.openDayFill;
const Color _kSecPatOpenBorder = HrNoraColors.openDayBorder;
const Color _kSecPatClosedFill = HrNoraColors.closedDayFill;
const Color _kSecPatClosedBorder = HrNoraColors.closedDayBorder;
const Color _kSecPatSelectedNavy = Color(0xFF0D47A1);
const Color _kSecPatGoldRing = Color(0xFFD4AF37);
const Color _kSecPatDowBlue = Color(0xFF0D47A1);
const Color _kSecPatHeaderNavy = Color(0xFF0D2137);
const Color _kSecPatChevronBlue = Color(0xFF1565C0);
const Color _kSecPatNumericBlue = Color(0xFF1565C0);

/// Matches [PatientAvailableDaysList._patientDayCell] corner radius.
const double _kSecPatMonthCellRadius = 12.0;

/// Past / outside tiles — same fills as patient booking calendar.
const Color _kSecPatPastFill = Color(0xFFF1F3F5);
const Color _kSecPatPastBorder = Color(0xFFDDE1E6);
const Color _kSecPatPastSlate = Color(0xFF64748B);
const Color _kSecPatOutsideFill = Color(0xFFF7F7F8);
const Color _kSecPatOutsideBorder = Color(0xFFE8EAED);

/// Kurdish DOW labels, Saturday-first (matches [StartingDayOfWeek.saturday]).
const List<String> _kSecretaryDowLabelsSatFirst = [
  'شەم',
  'یەک',
  'دوو',
  'سێ',
  'چوار',
  'پێنج',
  'هەینی',
];

String _secretaryDowLabelForDate(DateTime day) =>
    _kSecretaryDowLabelsSatFirst[(day.weekday + 1) % 7];

/// English (Western) numerals for secretary calendar dates, e.g. `2026 / 4 / 3`.
String _secretaryEnglishNumeralDateYmd(DateTime d) {
  final nf = NumberFormat.decimalPattern('en_US');
  return '${nf.format(d.year)} / ${nf.format(d.month)} / ${nf.format(d.day)}';
}

/// Month grid: slate blue = open slots, maroon = non-working / closed.
const Color _kCalGreenFill = HrNoraColors.openDayFill;
const Color _kCalGreenBorder = HrNoraColors.openDayGradientLight;
const Color _kCalRedFill = HrNoraColors.closedDayFill;
const Color _kCalRedBorder = HrNoraColors.closedDayBorder;

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
    this.useStaffShellTheme = false,
  });

  /// When [showDoctorPicker] is true, user must choose a doctor first.
  final String? doctorId;
  final bool canManage;
  final bool showDoctorPicker;
  final bool isRootShell;

  /// Light secretary/doctor shell (navy app bar, off-white body). [isRootShell] implies this.
  final bool useStaffShellTheme;

  @override
  State<MasterCalendarScreen> createState() => _MasterCalendarScreenState();
}

class _MasterCalendarScreenState extends State<MasterCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _pickedDoctorId;

  bool get _staffChrome => widget.isRootShell || widget.useStaffShellTheme;

  /// Secretary root tab: English numerals, past-day styling, gold “today”.
  bool get _secretaryCalendarUx =>
      widget.isRootShell && widget.showDoctorPicker;

  @override
  void initState() {
    super.initState();
    _pickedDoctorId = widget.doctorId;
    _selectedDay = widget.isRootShell && widget.showDoctorPicker
        ? null
        : DateTime.now();
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
      final st = (data[AppointmentFields.status] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
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
  }) {
    final blockMaps = blockDocs.map((e) => e.data()).toList();
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final map = <DateTime, MasterDayVisual>{};

    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final key = DateTime(d.year, d.month, d.day);
      final dayBlocks = blocksForCalendarDay(key, blockMaps);
      final booked = _bookedKeysForDay(key, apptDocs);
      final step = appointmentSlotMinutesForDateWithAllBlocks(key, blockMaps);
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
    if (_secretaryCalendarUx) {
      return _secretaryPatientStyleCell(
        day: day,
        focusedMonth: focusedMonth,
        visual: visual,
        isToday: isToday,
        isSelected: isSelected,
      );
    }

    final isOutside = day.month != focusedMonth.month;

    late final LinearGradient crystalGrad;
    late final Color edgeColor;
    switch (visual) {
      case MasterDayVisual.hasAvailability:
        crystalGrad = CalendarCrystalSurfaces.greenCrystalBase;
        edgeColor = CalendarCrystalSurfaces.greenCrystalEdge;
      case MasterDayVisual.fullyBooked:
        crystalGrad = CalendarCrystalSurfaces.amberCrystalBase;
        edgeColor = CalendarCrystalSurfaces.amberCrystalEdge;
      case MasterDayVisual.nonWorking:
      default:
        crystalGrad = CalendarCrystalSurfaces.redCrystalBase;
        edgeColor = CalendarCrystalSurfaces.redCrystalEdge;
    }

    final textColor = isOutside
        ? const Color(0xFF829AB1).withValues(alpha: 0.5)
        : const Color(0xFFE8EEF4);

    const kMasterGoldRing = Color(0xFFD4AF37);
    final br = BorderRadius.circular(10);
    final Border cellBorder;
    if (isSelected) {
      cellBorder = Border.all(
        color: visual == MasterDayVisual.nonWorking
            ? kMasterGoldRing
            : const Color(0xFF6366F1),
        width: 2,
      );
    } else if (isToday) {
      cellBorder = Border.all(color: const Color(0xFF38BDF8), width: 2);
    } else {
      cellBorder = Border.all(
        color: edgeColor,
        width: visual == MasterDayVisual.hasAvailability ? 1.4 : 1.2,
      );
    }

    final inner = Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: br,
        border: cellBorder,
        gradient: crystalGrad,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CalendarCrystalSurfaces.glossOverlay(borderRadius: br),
            ),
          ),
          Text(
            '${day.day}',
            style: TextStyle(
              fontFamily: 'NRT',
              fontWeight:
                  isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 15,
              height: 1,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    return isOutside ? Opacity(opacity: 0.45, child: inner) : inner;
  }

  /// Secretary month grid: explicit open / closed / past / outside / selection.
  Widget _secretaryPatientStyleCell({
    required DateTime day,
    required DateTime focusedMonth,
    required MasterDayVisual? visual,
    required bool isToday,
    required bool isSelected,
  }) {
    final now = DateTime.now();
    final todayD = DateTime(now.year, now.month, now.day);
    final cellD = DateTime(day.year, day.month, day.day);
    final isPast = cellD.isBefore(todayD);
    final isOutside =
        day.month != focusedMonth.month || day.year != focusedMonth.year;

    final closedOrFull = visual != MasterDayVisual.hasAvailability;

    final radius = BorderRadius.circular(_kSecPatMonthCellRadius);
    final dayAscii = NumberFormat.decimalPattern('en_US').format(day.day);

    final showGreenCrystal = !isPast && !isOutside && !closedOrFull;
    final showRedCrystal = !isPast && !isOutside && closedOrFull;
    final navySelected =
        isSelected && !isPast && !isOutside && !closedOrFull;

    Color? flatFill;
    Color borderColor;
    double borderWidth;
    LinearGradient? cellGradient;

    if (isOutside) {
      flatFill = _kSecPatOutsideFill;
      borderColor = _kSecPatOutsideBorder.withValues(alpha: 0.9);
      borderWidth = 0.75;
    } else if (isPast) {
      flatFill = _kSecPatPastFill;
      borderColor = _kSecPatPastBorder;
      borderWidth = 0.75;
    } else if (navySelected) {
      flatFill = _kSecPatSelectedNavy;
      borderColor = _kSecPatGoldRing;
      borderWidth = 2.0;
    } else if (isSelected && showRedCrystal) {
      flatFill = null;
      cellGradient = CalendarCrystalSurfaces.redCrystalBase;
      borderColor = _kSecPatGoldRing;
      borderWidth = 2.0;
    } else if (showGreenCrystal) {
      flatFill = null;
      cellGradient = CalendarCrystalSurfaces.greenCrystalBase;
      borderColor = CalendarCrystalSurfaces.greenCrystalEdge;
      borderWidth = 1.25;
    } else {
      flatFill = null;
      cellGradient = CalendarCrystalSurfaces.redCrystalBase;
      borderColor = CalendarCrystalSurfaces.redCrystalEdge;
      borderWidth = 1.25;
    }

    if (isToday && !isSelected && !isOutside) {
      borderColor = _kSecPatGoldRing;
      borderWidth = 3.0;
    }

    final strikeThrough = isPast;
    final textColor = isSelected
        ? Colors.white
        : isPast
        ? _kSecPatPastSlate
        : isOutside
        ? const Color(0xFF90A4AE)
        : Colors.white;

    final crystalGloss = cellGradient != null;
    final navyGloss = navySelected;

    final textWidget = Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Text(
        dayAscii,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          height: 1,
          color: textColor,
          decoration: strikeThrough
              ? TextDecoration.lineThrough
              : TextDecoration.none,
          decorationColor: _kSecPatPastSlate,
          decorationThickness: 1.75,
        ),
      ),
    );

    final cellCore = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: flatFill,
        gradient: cellGradient,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        children: [
          if (crystalGloss)
            Positioned.fill(
              child: IgnorePointer(
                child: CalendarCrystalSurfaces.glossOverlay(
                  borderRadius: radius,
                ),
              ),
            ),
          if (navyGloss)
            Positioned.fill(
              child: IgnorePointer(
                child: CalendarCrystalSurfaces.glossOverlaySubtle(
                  borderRadius: radius,
                ),
              ),
            ),
          Center(child: textWidget),
        ],
      ),
    );

    return Padding(padding: const EdgeInsets.all(1.5), child: cellCore);
  }

  Widget _secretaryGlassCalendarShell({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                Colors.white.withValues(alpha: 0.76),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 0.75,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.09),
                blurRadius: 32,
                offset: const Offset(0, 14),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: const Color(0xFF90CAF9).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
            child: child,
          ),
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _secretaryAppointmentsForLocalDay(
    DateTime day,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> monthDocs,
  ) {
    final y = day.year;
    final m = day.month;
    final dD = day.day;
    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in monthDocs) {
      final data = doc.data();
      final st = (data[AppointmentFields.status] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      if (st == 'cancelled' || st == 'canceled') continue;
      final ts = data[AppointmentFields.date];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.year != y || dt.month != m || dt.day != dD) continue;
      out.add(doc);
    }
    return out;
  }

  Widget _buildMonthCalendarTable(
    BuildContext context, {
    required Map<DateTime, MasterDayVisual> visuals,
    required Map<String, dynamic>? weekly,
    Map<String, dynamic>? dateOverrides,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> appts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> blocks,
  }) {
    final secUx = _secretaryCalendarUx;
    final calendar = TableCalendar<void>(
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      rowHeight: secUx ? 40 : 52,
      daysOfWeekHeight: secUx ? 28 : 36,
      selectedDayPredicate: (d) =>
          _selectedDay != null && isSameDay(_selectedDay!, d),
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      startingDayOfWeek: StartingDayOfWeek.saturday,
      locale: secUx ? 'en_US' : Localizations.localeOf(context).toLanguageTag(),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: secUx ? _kSecPatDowBlue : const Color(0xFF94A3B8),
          fontFamily: kPatientPrimaryFont,
          fontSize: secUx ? 11 : 12,
          fontWeight: secUx ? FontWeight.w700 : FontWeight.w800,
        ),
        weekendStyle: TextStyle(
          color: secUx ? _kSecPatDowBlue : const Color(0xFF94A3B8),
          fontFamily: kPatientPrimaryFont,
          fontSize: secUx ? 11 : 12,
          fontWeight: secUx ? FontWeight.w700 : FontWeight.w800,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        headerPadding: EdgeInsets.zero,
        titleTextFormatter: secUx
            ? (date, _) {
                final nf = NumberFormat.decimalPattern('en_US');
                return '\u200E${nf.format(date.year)} / ${nf.format(date.month)}';
              }
            : null,
        titleTextStyle: TextStyle(
          color: secUx ? _kSecPatHeaderNavy : const Color(0xFFE8EEF4),
          fontSize: secUx ? 15 : 17,
          fontWeight: secUx ? FontWeight.w700 : FontWeight.w800,
          fontFamily: kPatientPrimaryFont,
          letterSpacing: secUx ? 0.2 : 0,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left_rounded,
          color: secUx ? _kSecPatChevronBlue : const Color(0xFF42A5F5),
          size: secUx ? 20 : 24,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right_rounded,
          color: secUx ? _kSecPatChevronBlue : const Color(0xFF42A5F5),
          size: secUx ? 20 : 24,
        ),
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
        disabledDecoration: BoxDecoration(shape: BoxShape.rectangle),
        defaultTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
        weekendTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
        outsideTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
        todayTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
        selectedTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
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
        if (!_secretaryCalendarUx) {
          _openDaySheet(
            context: context,
            day: sel,
            weekly: weekly,
            dateOverrides: dateOverrides,
            monthAppointments: appts,
            monthBlocks: blocks,
            slotDurationMinutes: appointmentSlotMinutesForDateWithAllBlocks(
              DateTime(sel.year, sel.month, sel.day),
              blocks.map((e) => e.data()).toList(),
            ),
          );
        }
      },
      calendarBuilders: CalendarBuilders(
        dowBuilder: secUx
            ? (context, day) {
                return SizedBox.expand(
                  child: Center(
                    child: Text(
                      _secretaryDowLabelForDate(day),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _kSecPatDowBlue,
                        fontFamily: kPatientPrimaryFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }
            : null,
        defaultBuilder: (context, day, fd) {
          final key = DateTime(day.year, day.month, day.day);
          final sel = _selectedDay != null && isSameDay(_selectedDay!, day);
          return _connectStyleMonthCell(
            day: day,
            focusedMonth: fd,
            visual: visuals[key],
            isToday: isSameDay(day, DateTime.now()),
            isSelected: sel,
          );
        },
        todayBuilder: (context, day, fd) {
          final key = DateTime(day.year, day.month, day.day);
          final sel = _selectedDay != null && isSameDay(_selectedDay!, day);
          return _connectStyleMonthCell(
            day: day,
            focusedMonth: fd,
            visual: visuals[key],
            isToday: true,
            isSelected: sel,
          );
        },
        selectedBuilder: (context, day, fd) {
          final key = DateTime(day.year, day.month, day.day);
          return _connectStyleMonthCell(
            day: day,
            focusedMonth: fd,
            visual: visuals[key],
            isToday: isSameDay(day, DateTime.now()),
            isSelected: true,
          );
        },
        outsideBuilder: (context, day, fd) {
          final key = DateTime(day.year, day.month, day.day);
          final sel = _selectedDay != null && isSameDay(_selectedDay!, day);
          return _connectStyleMonthCell(
            day: day,
            focusedMonth: fd,
            visual: visuals[key],
            isToday: isSameDay(day, DateTime.now()),
            isSelected: sel,
          );
        },
      ),
    );
    if (secUx) {
      return _secretaryGlassCalendarShell(child: calendar);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF12152A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 14),
        child: calendar,
      ),
    );
  }

  /// Secretary-only: large action card with selected day, numeric date, list, gold CTA.
  Widget _buildSecretaryActionDashboard(
    BuildContext context, {
    required DateTime? selectedDay,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    monthAppointments,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> monthBlocks,
    required Map<String, dynamic>? weekly,
    Map<String, dynamic>? dateOverrides,
  }) {
    final s = S.of(context);
    final nf = NumberFormat.decimalPattern('en_US');

    var list = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    if (selectedDay != null) {
      list = _secretaryAppointmentsForLocalDay(selectedDay, monthAppointments);
      list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(list);
      sortStaffAppointmentsInPlace(list);
    }

    final slotMinutes = selectedDay == null
        ? 30
        : appointmentSlotMinutesForDateWithAllBlocks(
            DateTime(selectedDay.year, selectedDay.month, selectedDay.day),
            monthBlocks.map((e) => e.data()).toList(),
          );

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.97),
                  _kSecPatOpenFill.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
              border: Border.all(
                color: _kSecPatGoldRing.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: kStaffPrimaryNavy.withValues(alpha: 0.09),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: _kSecPatGoldRing.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selectedDay != null)
                    Text(
                      s.translate('secretary_calendar_selected_heading'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _kSecPatHeaderNavy,
                      ),
                    )
                  else
                    Text(
                      s.translate('secretary_calendar_select_day_hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.4,
                        color: kStaffMutedText,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Center(
                    child: Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        selectedDay == null ? '—' : nf.format(selectedDay.day),
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 58,
                          height: 1,
                          color: selectedDay == null
                              ? kStaffMutedText.withValues(alpha: 0.35)
                              : _kSecPatHeaderNavy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      selectedDay == null
                          ? '— / — / —'
                          : _secretaryEnglishNumeralDateYmd(selectedDay),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 0.3,
                        color: _kSecPatNumericBlue,
                      ),
                    ),
                  ),
                  if (selectedDay != null) ...[
                    const SizedBox(height: 16),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          s.translate('secretary_calendar_no_appointments_day'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: kStaffMutedText,
                            height: 1.35,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: list.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, thickness: 0.6),
                          itemBuilder: (context, i) {
                            final doc = list[i];
                            final data = doc.data();
                            final name =
                                (data[AppointmentFields.patientName] ?? '—')
                                    .toString();
                            final time = (data[AppointmentFields.time] ?? '—')
                                .toString();
                            final q =
                                (data[AppointmentFields.queueNumber] ?? '')
                                    .toString()
                                    .trim();
                            final sub = q.isEmpty ? time : '$time · #$q';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.person_rounded,
                                color: _kSecPatOpenFill,
                                size: 22,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: kStaffBodyText,
                                ),
                              ),
                              subtitle: Directionality(
                                textDirection: ui.TextDirection.ltr,
                                child: Text(
                                  sub,
                                  style: TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: kStaffMutedText,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  StaffGoldGradientButton(
                    label: s.translate(
                      'secretary_calendar_manage_appointments',
                    ),
                    onPressed: selectedDay == null
                        ? null
                        : () => _openDaySheet(
                            context: context,
                            day: selectedDay,
                            weekly: weekly,
                            dateOverrides: dateOverrides,
                            monthAppointments: monthAppointments,
                            monthBlocks: monthBlocks,
                            slotDurationMinutes: slotMinutes,
                          ),
                    fontSize: 15,
                    borderRadius: 16,
                    minHeight: 52,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDaySheet({
    required BuildContext context,
    required DateTime day,
    required Map<String, dynamic>? weekly,
    Map<String, dynamic>? dateOverrides,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    monthAppointments,
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
        backgroundColor: _staffChrome
            ? Colors.transparent
            : const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: kStaffPrimaryNavy,
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
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    letterSpacing: 0.6,
                    color: _staffChrome
                        ? kStaffPrimaryNavy
                        : const Color(0xFFD9E2EC),
                    shadows: _staffChrome
                        ? null
                        : [
                            Shadow(
                              color: const Color(
                                0xFF42A5F5,
                              ).withValues(alpha: 0.35),
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
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    color: _staffChrome
                        ? kStaffMutedText
                        : const Color(0xFF829AB1).withValues(alpha: 0.95),
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
                          style: _staffChrome
                              ? staffLabelTextStyle()
                              : const TextStyle(
                                  color: Color(0xFF829AB1),
                                  fontFamily: 'NRT',
                                ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value:
                            _pickedDoctorId != null &&
                                docs.any((d) => d.id == _pickedDoctorId)
                            ? _pickedDoctorId
                            : null,
                        dropdownColor: _staffChrome
                            ? kStaffCardSurface
                            : const Color(0xFF1D1E33),
                        decoration: InputDecoration(
                          labelText: s.translate('master_calendar_pick_doctor'),
                          labelStyle: _staffChrome
                              ? staffLabelTextStyle()
                              : const TextStyle(
                                  color: Color(0xFF829AB1),
                                  fontFamily: 'NRT',
                                ),
                          filled: true,
                          fillColor: _staffChrome
                              ? kStaffCardSurface
                              : const Color(0xFF1D1E33),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _staffChrome
                                  ? kStaffSilverBorder
                                  : Colors.white12,
                              width: _staffChrome ? kStaffCardOutlineWidth : 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _staffChrome
                                  ? kStaffSilverBorder
                                  : Colors.white12,
                              width: _staffChrome ? kStaffCardOutlineWidth : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _staffChrome
                                  ? kStaffPrimaryNavy
                                  : const Color(0xFF42A5F5),
                              width: 1.2,
                            ),
                          ),
                        ),
                        items: docs
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  localizedDoctorFullName(
                                    d.data(),
                                    AppLocaleScope.of(
                                      context,
                                    ).effectiveLanguage,
                                  ),
                                  style: _staffChrome
                                      ? staffHeaderTextStyle(fontSize: 15)
                                      : const TextStyle(
                                          fontFamily: 'NRT',
                                          color: Color(0xFFD9E2EC),
                                        ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _pickedDoctorId = v;
                          if (_secretaryCalendarUx) {
                            _selectedDay = null;
                          }
                        }),
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
                          style: _staffChrome
                              ? staffLabelTextStyle()
                              : const TextStyle(
                                  color: Color(0xFF829AB1),
                                  fontFamily: 'NRT',
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
                          final weekly = weeklyRaw is Map<String, dynamic>
                              ? weeklyRaw
                              : null;
                          final normalizedOv =
                              normalizeScheduleDateOverridesMap(
                                snapData?['schedule_date_overrides'],
                              );
                          final Map<String, dynamic>? dateOverrides =
                              normalizedOv.isEmpty ? null : normalizedOv;
                          final monthStart = _monthStart(_focusedDay);
                          final monthEnd = _monthEndExclusive(_focusedDay);

                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            key: ValueKey(
                              '$doctorId-${monthStart.toIso8601String()}',
                            ),
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
                                        fontFamily: 'NRT',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                key: ValueKey(
                                  'blk-$doctorId-${monthStart.toIso8601String()}',
                                ),
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
                                  );

                                  return SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Column(
                                        children: [
                                          if (!_secretaryCalendarUx) ...[
                                            _LegendRow(
                                              loc: S.of(context),
                                              secretaryUx: false,
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                          _buildMonthCalendarTable(
                                            context,
                                            visuals: visuals,
                                            weekly: weekly,
                                            dateOverrides: dateOverrides,
                                            appts: appts,
                                            blocks: blocks,
                                          ),
                                          if (_secretaryCalendarUx)
                                            _buildSecretaryActionDashboard(
                                              context,
                                              selectedDay: _selectedDay,
                                              monthAppointments: appts,
                                              monthBlocks: blocks,
                                              weekly: weekly,
                                              dateOverrides: dateOverrides,
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
                                              icon: const Icon(
                                                Icons.block_rounded,
                                                color: Color(0xFFFF8A80),
                                              ),
                                              label: Text(
                                                s.translate(
                                                  'master_calendar_block_day',
                                                ),
                                                style: const TextStyle(
                                                  fontFamily: 'NRT',
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
              leading: const Icon(
                Icons.event_busy_rounded,
                color: Color(0xFFFF8A80),
              ),
              title: Text(
                s.translate('master_calendar_block_day_off'),
                style: const TextStyle(
                  fontFamily: 'NRT',
                  color: Color(0xFFD9E2EC),
                ),
              ),
              onTap: () => Navigator.pop(ctx, CalendarBlockFields.kindOff),
            ),
            ListTile(
              leading: const Icon(
                Icons.emergency_rounded,
                color: Color(0xFFFF7043),
              ),
              title: Text(
                s.translate('master_calendar_block_day_emergency'),
                style: const TextStyle(
                  fontFamily: 'NRT',
                  color: Color(0xFFD9E2EC),
                ),
              ),
              onTap: () =>
                  Navigator.pop(ctx, CalendarBlockFields.kindEmergency),
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
              style: const TextStyle(fontFamily: 'NRT'),
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
              style: const TextStyle(fontFamily: 'NRT'),
            ),
          ),
        );
      }
    }
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.loc, this.secretaryUx = false});

  final AppLocalizations loc;
  final bool secretaryUx;

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
              style: TextStyle(
                color: secretaryUx
                    ? const Color(0xFF546E7A)
                    : const Color(0xFF829AB1),
                fontSize: 11,
                fontFamily: kPatientPrimaryFont,
                fontWeight: secretaryUx ? FontWeight.w700 : FontWeight.w600,
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
          dot(
            secretaryUx ? _kSecPatOpenFill : _kCalGreenFill,
            secretaryUx ? _kSecPatOpenBorder : _kCalGreenBorder,
          ),
          loc.translate('master_calendar_legend_green'),
        ),
        item(
          dot(_kCalAmberFill, _kCalAmberBorder),
          loc.translate('master_calendar_legend_amber'),
        ),
        item(
          dot(
            secretaryUx ? _kSecPatClosedFill : _kCalRedFill,
            secretaryUx ? _kSecPatClosedBorder : _kCalRedBorder,
          ),
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
            fontFamily: 'NRT',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        if (win == null)
          Text(
            s.translate('master_calendar_day_off'),
            style: const TextStyle(color: Color(0xFF829AB1), fontFamily: 'NRT'),
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
                          style: const TextStyle(fontFamily: 'NRT'),
                        ),
                      )
                    : null,
              );
            }

            if (booked) {
              final aptDoc = appt;
              final name = (aptDoc.data()[AppointmentFields.patientName] ?? '—')
                  .toString();
              return _SlotTile(
                timeLabel: label,
                subtitle:
                    '${s.translate('master_calendar_booked')}: $name (${aptDoc.data()[AppointmentFields.status] ?? 'pending'})',
                statusStripColor: _kCalRedBorder,
                trailing: canManage
                    ? PopupMenuButton<String>(
                        tooltip: '',
                        color: Colors.transparent,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        // Anchor is on the right; shift left so the panel stays visible.
                        offset: const Offset(-96, 0),
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Color(0xFF829AB1),
                        ),
                        onSelected: (v) async {
                          if (v == 'cancel') {
                            final ok = await showAppointmentActionConfirmDialog(
                              context,
                              isCompleteAction: false,
                            );
                            if (ok != true || !context.mounted) return;
                            await aptDoc.reference.update({
                              AppointmentFields.status: 'available',
                              AppointmentFields.patientName: null,
                              AppointmentFields.patientId: null,
                              AppointmentFields.updatedAt:
                                  FieldValue.serverTimestamp(),
                            });
                          } else if (v == 'done') {
                            final ok = await showAppointmentActionConfirmDialog(
                              context,
                              isCompleteAction: true,
                            );
                            if (ok != true || !context.mounted) return;
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
                          PopupMenuItem<String>(
                            value: 'done',
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 14,
                                  sigmaY: 14,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        s.translate(
                                          'master_calendar_mark_complete',
                                        ),
                                        style: const TextStyle(
                                          fontFamily: 'NRT',
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A237E),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'cancel',
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(15),
                              ),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 14,
                                  sigmaY: 14,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        s.translate(
                                          'master_calendar_cancel_appt',
                                        ),
                                        style: const TextStyle(
                                          fontFamily: 'NRT',
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFB91C1C),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
              // LTR keeps the ⋮ menu on the trailing (right) side in RTL locales.
              textDirection: ui.TextDirection.ltr,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Color(0xFF42A5F5),
                      fontWeight: FontWeight.w800,
                      fontFamily: 'NRT',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF829AB1),
                      fontFamily: 'NRT',
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
              leading: const Icon(
                Icons.person_add_rounded,
                color: Color(0xFF42A5F5),
              ),
              title: Text(
                s.translate('master_calendar_add_walkin'),
                style: const TextStyle(
                  fontFamily: 'NRT',
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
                          fontFamily: 'NRT',
                          color: Color(0xFFD9E2EC),
                        ),
                      ),
                      content: TextField(
                        controller: nameController,
                        style: const TextStyle(
                          color: Color(0xFFD9E2EC),
                          fontFamily: 'NRT',
                        ),
                        decoration: InputDecoration(
                          labelText: s.translate(
                            'doctor_appt_patient_name_label',
                          ),
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
                        style: const TextStyle(fontFamily: 'NRT'),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        s.translate('master_calendar_saved'),
                        style: const TextStyle(fontFamily: 'NRT'),
                      ),
                    ),
                  );
                }
                onChanged();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.event_busy_rounded,
                color: Color(0xFFFF8A80),
              ),
              title: Text(
                s.translate('master_calendar_block_slot_off'),
                style: const TextStyle(
                  fontFamily: 'NRT',
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
                        CalendarBlockFields.blockKind:
                            CalendarBlockFields.kindOff,
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdBy': uid,
                      });
                  if (outerCtx.mounted) {
                    ScaffoldMessenger.of(outerCtx).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.translate('master_calendar_block_saved'),
                          style: const TextStyle(fontFamily: 'NRT'),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (outerCtx.mounted) {
                    ScaffoldMessenger.of(
                      outerCtx,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
                onChanged();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.emergency_rounded,
                color: Color(0xFFFF7043),
              ),
              title: Text(
                s.translate('master_calendar_block_slot_emergency'),
                style: const TextStyle(
                  fontFamily: 'NRT',
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
                        CalendarBlockFields.blockKind:
                            CalendarBlockFields.kindEmergency,
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdBy': uid,
                      });
                  if (outerCtx.mounted) {
                    ScaffoldMessenger.of(outerCtx).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.translate('master_calendar_block_saved'),
                          style: const TextStyle(fontFamily: 'NRT'),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (outerCtx.mounted) {
                    ScaffoldMessenger.of(
                      outerCtx,
                    ).showSnackBar(SnackBar(content: Text('$e')));
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
          style: const TextStyle(fontFamily: 'NRT'),
        ),
      ),
    );
    return;
  }

  final patientSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  final patientName =
      (patientSnap.data()?['fullName'] ?? '').toString().trim().isEmpty
      ? s.translate('patient_default')
      : (patientSnap.data()?['fullName'] ?? '').toString();

  final doctorSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(doctorId)
      .get();
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
          style: const TextStyle(fontFamily: 'NRT'),
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
        style: const TextStyle(fontFamily: 'NRT', color: Color(0xFFD9E2EC)),
      ),
      content: Text(
        s.translate('booking_success_body'),
        style: const TextStyle(fontFamily: 'NRT', color: Color(0xFF829AB1)),
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
