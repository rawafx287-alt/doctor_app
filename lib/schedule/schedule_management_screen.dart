import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../firestore/available_days_queries.dart';
import '../firestore/firestore_index_error_log.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../doctor/doctor_premium_shell.dart'
    show
        DoctorPremiumBackground,
        doctorPremiumAppBar,
        kDoctorPremiumGradientBottom,
        kDoctorPremiumGradientDecoration;
import '../theme/calendar_crystal_surfaces.dart';
import '../theme/hr_nora_colors.dart';
import '../theme/staff_premium_theme.dart';
import '../theme/staff_time_picker_theme.dart';

/// Secretary/doctor schedule UI — aligned with patient month grid (rounded cells, glass shell).
/// Deep teal “open” (matches [HrNoraColors.openDayFill]).
const Color _kSchedOpenFill = HrNoraColors.openDayFill;
const Color _kSchedClosedFill = HrNoraColors.closedDayFill;
const Color _kSchedGoldRing = Color(0xFFD4AF37);
const double _kDayBoxR = 10.0;
const double _kSelectedGoldBorder = 2.0;
const double _kPrimaryGlassBlur = 22.0;
const double _kGridCrossAxisSpacing = 5.0;
const double _kGridMainAxisSpacing = 2.0;
/// Space from last date row to inner bottom of gold-bordered card (~red line).
const double _kCalendarCardBottomPadding = 10.0;
/// Reserve space above bottom nav + FAB when embedded in doctor/secretary shell.
const double _kEmbeddedBottomNavReserve = 96.0;
const double _kBodyHorizontalPad = 12.0;
const double _kPrimaryCardPadding = 10.0;
/// Fixed month title row (avoids tall IconButton tap targets stretching the card).
const double _kScheduleMonthHeaderH = 34.0;
/// Breathing room between weekday capsules and first date row.
const double _kScheduleDowToGridGap = 8.0;
const int _kScheduleGridRowCount = 6;
/// Glass weekday capsules (rounded rects, not circles).
const double _kDowCapsuleBlurSigma = 22.0;
const double _kDowCapsuleBorderThin = 0.3;
const double _kDowCapsuleHeight = 32.0;
const double _kDowRowHeight = 40.0;

bool _scheduleIsSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Saturday-first month grid: leading/trailing nulls, padded to 42 cells (6×7).
List<DateTime?> _monthGridCells(DateTime monthAnchor) {
  final y = monthAnchor.year;
  final m = monthAnchor.month;
  final first = DateTime(y, m, 1);
  final lead = (first.weekday + 1) % 7;
  final dim = DateTime(y, m + 1, 0).day;
  final out = <DateTime?>[];
  for (var i = 0; i < lead; i++) {
    out.add(null);
  }
  for (var d = 1; d <= dim; d++) {
    out.add(DateTime(y, m, d));
  }
  while (out.length % 7 != 0) {
    out.add(null);
  }
  while (out.length < 42) {
    out.add(null);
  }
  return out;
}

/// Saturday-first row; index matches `(weekday + 1) % 7` for Dart `weekday` (Mon=1..Sun=7).
const List<String> _kDowKurdishFullSatFirst = [
  'شەممە',
  'یەکشەممە',
  'دووشەممە',
  'سێشەممە',
  'چوارشەممە',
  'پێنجشەممە',
  'هەینی',
];

/// Selected-date line: `day / month / year` with English numerals.
String _enNum(DateTime d) {
  final nf = NumberFormat.decimalPattern('en_US');
  return '${nf.format(d.day)} / ${nf.format(d.month)} / ${nf.format(d.year)}';
}

String _enMonthTitle(DateTime d) {
  final nf = NumberFormat.decimalPattern('en_US');
  return '\u200E${nf.format(d.year)} / ${nf.format(d.month)}';
}

String _scheduleHhMmToEnglish12h(String hhMm) {
  final p = hhMm.trim().split(':');
  if (p.length != 2) return hhMm;
  final h = int.tryParse(p[0].trim());
  final m = int.tryParse(p[1].trim());
  if (h == null || m == null) return hhMm;
  final dt = DateTime(2000, 1, 1, h, m);
  return DateFormat.jm('en_US').format(dt);
}

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({
    super.key,
    required this.managedDoctorUserId,
    this.embedded = false,
  });

  final String? managedDoctorUserId;
  final bool embedded;

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _selectedDay = DateTime(n.year, n.month, n.day);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, Map<String, dynamic>> _mapFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final m = <String, Map<String, dynamic>>{};
    for (final e in docs) {
      m[e.id] = e.data();
    }
    return m;
  }

  void _onScheduleDayTapped(DateTime day) {
    final d0 = _dateOnly(day);
    final today = _dateOnly(DateTime.now());
    setState(() => _selectedDay = d0);

    if (d0.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('schedule_manage_past_disabled'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    }
  }

  Widget _scheduleGlassCard({
    required double borderRadius,
    required double blurSigma,
    required double fillAlpha,
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Colors.white.withValues(alpha: fillAlpha),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.85),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 36,
                offset: const Offset(0, 16),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: kStaffLuxGold.withValues(alpha: 0.1),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Saturday-first column index for a local [DateTime] (matches grid columns).
  int _scheduleWeekdayColumnIndex(DateTime d) => (d.weekday + 1) % 7;

  /// Soft glass capsule weekday label — dashboard-style; [isTodayColumn] adds green glow.
  Widget _dowGlassCapsule(
    String label, {
    required double maxWidth,
    required bool isTodayColumn,
  }) {
    final h = _kDowCapsuleHeight;
    final r = h * 0.5;
    final fill = Colors.white.withValues(alpha: 0.1);

    final borderColor = isTodayColumn
        ? _kSchedOpenFill.withValues(alpha: 0.88)
        : kStaffLuxGold.withValues(alpha: 0.55);
    final borderW = isTodayColumn ? 0.85 : _kDowCapsuleBorderThin;

    final shadows = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
      if (isTodayColumn) ...[
        BoxShadow(
          color: _kSchedOpenFill.withValues(alpha: 0.45),
          blurRadius: 14,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: _kSchedOpenFill.withValues(alpha: 0.28),
          blurRadius: 22,
          spreadRadius: -1,
        ),
      ],
    ];

    final textColor = isTodayColumn
        ? kStaffLuxGoldLight.withValues(alpha: 0.98)
        : Colors.white.withValues(alpha: 0.94);

    return Container(
      height: h,
      width: maxWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: _kDowCapsuleBlurSigma,
            sigmaY: _kDowCapsuleBlurSigma,
          ),
          child: Container(
            height: h,
            width: maxWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              color: fill,
              border: Border.all(color: borderColor, width: borderW),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: textColor,
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  height: 1.05,
                  letterSpacing: -0.15,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 2,
                      offset: const Offset(0, 0.5),
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

  /// Day cell — English numerals; NRT-Bd; size from parent grid.
  Widget _scheduleDayBox({
    required double side,
    required DateTime day,
    required Map<String, Map<String, dynamic>> openById,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final uid = widget.managedDoctorUserId?.trim() ?? '';
    final d0 = _dateOnly(day);
    final today = _dateOnly(DateTime.now());
    final isPast = d0.isBefore(today);
    final docId =
        uid.isEmpty ? '' : availableDayDocumentId(doctorUserId: uid, dateLocal: d0);
    final row = docId.isEmpty ? null : openById[docId];
    final open = row != null && availableDayIsOpen(row);
    final closedLook = row == null || !open;

    final nf = NumberFormat.decimalPattern('en_US');
    final dayAscii = nf.format(day.day);

    Color? flatFill;
    LinearGradient? crystalGrad;
    Color textColor;
    var strike = false;

    if (isPast) {
      flatFill = const Color(0xFFF1F3F5);
      crystalGrad = null;
      textColor = const Color(0xFF64748B);
      strike = true;
    } else if (!closedLook) {
      flatFill = null;
      crystalGrad = CalendarCrystalSurfaces.greenCrystalBase;
      textColor = Colors.white;
    } else {
      flatFill = null;
      crystalGrad = CalendarCrystalSurfaces.redCrystalBase;
      textColor = Colors.white;
    }

    final radius = BorderRadius.circular(_kDayBoxR);
    final box = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: flatFill,
            gradient: crystalGrad,
            borderRadius: radius,
            border: isSelected
                ? Border.all(color: _kSchedGoldRing, width: _kSelectedGoldBorder)
                : crystalGrad != null
                    ? Border.all(
                        color: closedLook
                            ? CalendarCrystalSurfaces.redCrystalEdge
                            : CalendarCrystalSurfaces.greenCrystalEdge,
                        width: 1.05,
                      )
                    : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (crystalGrad != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CalendarCrystalSurfaces.glossOverlay(
                      borderRadius: radius,
                    ),
                  ),
                ),
              Center(
                child: Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Text(
                    dayAscii,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w800,
                      fontSize: (side * 0.36).clamp(14.0, 19.0),
                      height: 1,
                      color: textColor,
                      decoration: strike
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: const Color(0xFF64748B),
                      decorationThickness: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return box;
  }

  double _scheduleCalendarInnerBodyHeight(double calInnerW) {
    final crossSp = _kGridCrossAxisSpacing;
    final mainSp = _kGridMainAxisSpacing;
    final colW = (calInnerW - 6 * crossSp) / 7;
    final side = colW.clamp(42.0, 54.0);
    final dowRowH = _kDowRowHeight;
    final gridH =
        _kScheduleGridRowCount * side +
        (_kScheduleGridRowCount - 1) * mainSp;
    return _kScheduleMonthHeaderH +
        dowRowH +
        _kScheduleDowToGridGap +
        gridH;
  }

  Widget _scheduleGridCell(
    DateTime? day, {
    required double side,
    required Map<String, Map<String, dynamic>> openById,
  }) {
    if (day == null) {
      return SizedBox(width: side, height: side);
    }
    final sel = _selectedDay != null && _scheduleIsSameDay(_selectedDay!, day);
    return Center(
      child: _scheduleDayBox(
        side: side,
        day: day,
        openById: openById,
        isSelected: sel,
        onTap: () => _onScheduleDayTapped(day),
      ),
    );
  }

  /// Fixed-height calendar body; grid is explicit rows (no GridView extent slack).
  Widget _buildIntrinsicCalendarColumn(
    Map<String, Map<String, dynamic>> openById,
    double calInnerW,
  ) {
    final cells = _monthGridCells(_focusedDay);
    final crossSp = _kGridCrossAxisSpacing;
    final mainSp = _kGridMainAxisSpacing;
    final colW = (calInnerW - 6 * crossSp) / 7;
    final side = colW.clamp(42.0, 54.0);
    final dowRowH = _kDowRowHeight;
    final gridH =
        _kScheduleGridRowCount * side +
        (_kScheduleGridRowCount - 1) * mainSp;
    final innerH = _scheduleCalendarInnerBodyHeight(calInnerW);
    final todayCol = _scheduleWeekdayColumnIndex(DateTime.now());

    Widget monthChevron({
      required VoidCallback onTap,
      required IconData icon,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 36,
            height: 32,
            child: Center(
              child: Icon(
                icon,
                color: const Color(0xFFB8860B),
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: innerH,
      width: calInnerW,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _kScheduleMonthHeaderH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                monthChevron(
                  onTap: () {
                    setState(() {
                      final d = _focusedDay;
                      _focusedDay = DateTime(d.year, d.month - 1, 1);
                    });
                  },
                  icon: Icons.chevron_left_rounded,
                ),
                Expanded(
                  child: Text(
                    _enMonthTitle(_focusedDay),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0D2137),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: kPatientPrimaryFont,
                      letterSpacing: 0.25,
                    ),
                  ),
                ),
                monthChevron(
                  onTap: () {
                    setState(() {
                      final d = _focusedDay;
                      _focusedDay = DateTime(d.year, d.month + 1, 1);
                    });
                  },
                  icon: Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
          SizedBox(
            height: dowRowH,
            width: calInnerW,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (int i = 0; i < 7; i++) ...[
                  if (i > 0) SizedBox(width: crossSp),
                  SizedBox(
                    width: colW,
                    child: Center(
                      child: _dowGlassCapsule(
                        _kDowKurdishFullSatFirst[i],
                        maxWidth: colW,
                        isTodayColumn: i == todayCol,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: _kScheduleDowToGridGap),
          SizedBox(
            height: gridH,
            width: calInnerW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int r = 0; r < _kScheduleGridRowCount; r++)
                  Padding(
                    padding: EdgeInsets.only(top: r == 0 ? 0 : mainSp),
                    child: SizedBox(
                      height: side,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int c = 0; c < 7; c++) ...[
                            if (c > 0) SizedBox(width: crossSp),
                            SizedBox(
                              width: colW,
                              height: side,
                              child: _scheduleGridCell(
                                cells[r * 7 + c],
                                side: side,
                                openById: openById,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final uid = widget.managedDoctorUserId?.trim() ?? '';

    if (uid.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            s.translate('login_required'),
            style: staffLabelTextStyle(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final monthStart =
        DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd =
        DateTime(_focusedDay.year, _focusedDay.month + 1, 1);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: watchAvailableDaysInRange(
        doctorUserId: uid,
        rangeStartInclusiveLocal: monthStart,
        rangeEndExclusiveLocal: monthEnd,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          logFirestoreIndexHelpOnce(
            snap.error,
            tag: 'ScheduleManagementScreen.available_days',
            expectedCompositeIndexHint: kAvailableDaysDoctorDateRangeIndexHint,
          );
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                s.translate('schedule_load_error'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontFamily: kPatientPrimaryFont,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final map = _mapFromDocs(snap.data?.docs ?? []);

        final bottomReserve = widget.embedded
            ? _kEmbeddedBottomNavReserve +
                MediaQuery.viewPaddingOf(context).bottom
            : 8.0;

        final fixedBody = Padding(
          padding: EdgeInsets.fromLTRB(
            _kBodyHorizontalPad,
            0,
            _kBodyHorizontalPad,
            bottomReserve,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fullW = constraints.maxWidth;
              final cardInnerW =
                  fullW - 2 * _kPrimaryCardPadding;
              final calInnerH =
                  _scheduleCalendarInnerBodyHeight(cardInnerW);
              final calendarCardTotalH = _kPrimaryCardPadding +
                  calInnerH +
                  _kCalendarCardBottomPadding;

              final sel = _selectedDay ?? _dateOnly(DateTime.now());
              final docId = availableDayDocumentId(
                doctorUserId: uid,
                dateLocal: sel,
              );
              final dayRow = map[docId];

              final scrollBody = SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: fullW,
                      height: calendarCardTotalH,
                      child: _scheduleGlassCard(
                        borderRadius: 28,
                        blurSigma: _kPrimaryGlassBlur,
                        fillAlpha: 0.2,
                        padding: const EdgeInsets.fromLTRB(
                          _kPrimaryCardPadding,
                          _kPrimaryCardPadding,
                          _kPrimaryCardPadding,
                          _kCalendarCardBottomPadding,
                        ),
                        child: _buildIntrinsicCalendarColumn(
                          map,
                          cardInnerW,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ScheduleTimeSettingsFooter(
                      key: ValueKey<String>(docId),
                      doctorUserId: uid,
                      dateLocal: sel,
                      existingDocId: docId,
                      dayRow: dayRow,
                    ),
                  ],
                ),
              );

              if (constraints.hasBoundedHeight) {
                return SizedBox(
                  width: fullW,
                  height: constraints.maxHeight,
                  child: scrollBody,
                );
              }
              return scrollBody;
            },
          ),
        );

        if (widget.embedded) {
          return Container(
            decoration: kDoctorPremiumGradientDecoration,
            child: fixedBody,
          );
        }

        return Scaffold(
          backgroundColor: kDoctorPremiumGradientBottom,
          extendBodyBehindAppBar: true,
          appBar: doctorPremiumAppBar(
            title: Text(s.translate('schedule_management_title')),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const DoctorPremiumBackground(),
              SafeArea(
                child: fixedBody,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact time settings for the calendar-selected day (navy glass footer).
class _ScheduleTimeSettingsFooter extends StatefulWidget {
  const _ScheduleTimeSettingsFooter({
    super.key,
    required this.doctorUserId,
    required this.dateLocal,
    required this.existingDocId,
    this.dayRow,
  });

  final String doctorUserId;
  final DateTime dateLocal;
  final String existingDocId;
  final Map<String, dynamic>? dayRow;

  @override
  State<_ScheduleTimeSettingsFooter> createState() =>
      _ScheduleTimeSettingsFooterState();
}

class _ScheduleTimeSettingsFooterState extends State<_ScheduleTimeSettingsFooter> {
  static const List<int> _kDurations = [15, 20, 30, 45];

  static int _coerceDuration(int minutes) {
    if (_kDurations.contains(minutes)) return minutes;
    var best = _kDurations[2];
    var bestD = 1 << 30;
    for (final c in _kDurations) {
      final d = (c - minutes).abs();
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }

  late bool _isOpen;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _durationMin;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _applyRowSnapshot();
  }

  @override
  void didUpdateWidget(covariant _ScheduleTimeSettingsFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateLocal != widget.dateLocal ||
        oldWidget.existingDocId != widget.existingDocId) {
      setState(_applyRowSnapshot);
    }
  }

  void _applyRowSnapshot() {
    final row = widget.dayRow;
    _isOpen = row != null && availableDayIsOpen(row);
    final sh = normalizeAvailableDayStartTimeHhMm(row?[AvailableDayFields.startTime]);
    final eh = normalizeAvailableDayClosingTimeHhMm(row?[AvailableDayFields.closingTime]);
    _start = _parseHhMm(sh) ?? const TimeOfDay(hour: 9, minute: 0);
    _end = _parseHhMm(eh) ?? const TimeOfDay(hour: 20, minute: 0);
    _durationMin = _coerceDuration(
      normalizeAppointmentDurationMinutes(
        row?[AvailableDayFields.appointmentDuration],
      ),
    );
  }

  TimeOfDay? _parseHhMm(String s) {
    final p = s.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0].trim());
    final m = int.tryParse(p[1].trim());
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isPast =>
      _dateOnly(widget.dateLocal).isBefore(_dateOnly(DateTime.now()));

  Future<void> _pickStart() async {
    if (_isPast) return;
    final p = await showTimePicker(
      context: context,
      initialTime: _start,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (c, ch) => Theme(
        data: staffTimePickerDialogTheme(Theme.of(c)),
        child: Directionality(
          textDirection: AppLocaleScope.of(c).textDirection,
          child: ch ?? const SizedBox.shrink(),
        ),
      ),
    );
    if (p != null) setState(() => _start = p);
  }

  Future<void> _pickEnd() async {
    if (_isPast) return;
    final p = await showTimePicker(
      context: context,
      initialTime: _end,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (c, ch) => Theme(
        data: staffTimePickerDialogTheme(Theme.of(c)),
        child: Directionality(
          textDirection: AppLocaleScope.of(c).textDirection,
          child: ch ?? const SizedBox.shrink(),
        ),
      ),
    );
    if (p != null) setState(() => _end = p);
  }

  Future<void> _save() async {
    if (_isPast) return;
    final s = S.of(context);
    setState(() => _saving = true);
    try {
      final id = widget.existingDocId;
      final hasDoc = widget.dayRow != null;

      if (!_isOpen) {
        if (hasDoc) {
          await setAvailableDayOpenState(availableDayDocId: id, isOpen: false);
        }
      } else {
        if (!hasDoc) {
          await openAvailableDay(
            doctorUserId: widget.doctorUserId,
            dateLocal: widget.dateLocal,
            startTimeHhMm: _fmt(_start),
            closingTimeHhMm: _fmt(_end),
            appointmentDurationMinutes: _durationMin,
          );
        } else {
          await setAvailableDayOpenState(availableDayDocId: id, isOpen: true);
          await updateAvailableDayTimeSettings(
            availableDayDocId: id,
            startTimeHhMm: _fmt(_start),
            closingTimeHhMm: _fmt(_end),
            appointmentDurationMinutes: _durationMin,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('schedule_save_ok'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('schedule_save_error_generic'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _timeRow({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required String timeEn12h,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              Icon(icon, size: 17, color: kStaffLuxGold.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Text(
                  timeEn12h,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: kStaffLuxGold.withValues(alpha: 0.94),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationChip(AppLocalizations loc, int minutes, bool enabled) {
    final sel = _durationMin == minutes;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () => setState(() => _durationMin = minutes)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel
                  ? kStaffLuxGold.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.22),
              width: sel ? 1 : 0.5,
            ),
            color: sel
                ? kStaffLuxGold.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
          ),
          child: Text(
            loc.translate(
              'schedule_day_slot_minutes_option',
              params: {'minutes': '$minutes'},
            ),
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              height: 1.1,
              color: Colors.white.withValues(alpha: sel ? 0.95 : 0.72),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final enabled = !_isPast;
    const radius = 18.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.48),
              width: 0.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kStaffShellGradientTop.withValues(alpha: 0.94),
                kStaffShellGradientMid.withValues(alpha: 0.92),
                const Color(0xFF0D2137).withValues(alpha: 0.96),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        loc.translate('schedule_sheet_tab_settings'),
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          height: 1.2,
                          color: kStaffLuxGold.withValues(alpha: 0.96),
                        ),
                      ),
                    ),
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        _enNum(widget.dateLocal),
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.local_hospital_rounded,
                      size: 16,
                      color: kStaffLuxGold.withValues(alpha: 0.88),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loc.translate('schedule_clinic_status_title'),
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    CupertinoSwitch(
                      value: _isOpen,
                      onChanged: enabled
                          ? (v) => setState(() => _isOpen = v)
                          : null,
                      activeTrackColor: _kSchedOpenFill,
                      inactiveTrackColor:
                          _kSchedClosedFill.withValues(alpha: 0.55),
                      thumbColor: CupertinoColors.white,
                    ),
                  ],
                ),
                const Divider(
                  height: 14,
                  thickness: 0.5,
                  color: Color(0x40D4AF37),
                ),
                _timeRow(
                  onTap: _pickStart,
                  icon: Icons.schedule_rounded,
                  label: loc.translate('schedule_control_start_time_label'),
                  timeEn12h: _scheduleHhMmToEnglish12h(_fmt(_start)),
                  enabled: enabled,
                ),
                const SizedBox(height: 2),
                _timeRow(
                  onTap: _pickEnd,
                  icon: Icons.event_available_rounded,
                  label: loc.translate('schedule_control_end_time_label'),
                  timeEn12h: _scheduleHhMmToEnglish12h(_fmt(_end)),
                  enabled: enabled,
                ),
                const SizedBox(height: 6),
                Text(
                  loc.translate('schedule_duration_per_appointment_label'),
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final m in _kDurations)
                      _durationChip(loc, m, enabled),
                  ],
                ),
                const SizedBox(height: 10),
                StaffGoldGradientButton(
                  label: loc.translate('schedule_save_button'),
                  onPressed: enabled && !_saving ? _save : null,
                  isLoading: _saving,
                  fontSize: 12,
                  borderRadius: 12,
                  minHeight: 38,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
