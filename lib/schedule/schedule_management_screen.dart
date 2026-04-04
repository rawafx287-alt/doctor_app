import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../firestore/appointment_queries.dart';
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
import '../theme/staff_premium_theme.dart';

/// Secretary/doctor schedule UI — aligned with patient month grid (rounded cells, glass shell).
/// Vibrant medical greens (Material-style A700 → darker anchor).
const Color _kSchedVibrantGreen = Color(0xFF00C853);
const Color _kSchedOpenFill = _kSchedVibrantGreen;
const Color _kSchedClosedFill = Color(0xFFB71C1C);
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
const double _kCalendarBottomGap = 4.0;
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

DateTime? _scheduleParseAppointmentDay(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) {
    final d = value.toDate();
    return DateTime(d.year, d.month, d.day);
  }
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  final ymd = RegExp(r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})');
  final m = ymd.firstMatch(s);
  if (m != null) {
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }
  try {
    final d = DateTime.parse(s);
    return DateTime(d.year, d.month, d.day);
  } catch (_) {
    return null;
  }
}

int _scheduleTimeSortMinutes(dynamic timeVal) {
  final s = (timeVal ?? '').toString().trim();
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
  if (m != null) {
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }
  return 1 << 20;
}

void _scheduleSortAppointmentDocs(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
) {
  list.sort((a, b) {
    final da = _scheduleParseAppointmentDay(a.data()[AppointmentFields.date]);
    final db = _scheduleParseAppointmentDay(b.data()[AppointmentFields.date]);
    if (da != null && db != null) {
      final c = da.compareTo(db);
      if (c != 0) return c;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    return _scheduleTimeSortMinutes(a.data()[AppointmentFields.time])
        .compareTo(_scheduleTimeSortMinutes(b.data()[AppointmentFields.time]));
  });
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

bool _scheduleApptIsCancelled(Map<String, dynamic> data) {
  final st = (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
  return st == 'cancelled';
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

  Future<void> _openDayEditorSheet(
    BuildContext context,
    DateTime day,
    Map<String, Map<String, dynamic>> openById,
  ) async {
    final s = S.of(context);
    final uid = widget.managedDoctorUserId?.trim() ?? '';
    if (uid.isEmpty) return;
    final d0 = _dateOnly(day);
    final today = _dateOnly(DateTime.now());
    if (d0.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('schedule_manage_past_disabled'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
      return;
    }

    final docId = availableDayDocumentId(doctorUserId: uid, dateLocal: d0);
    final row = openById[docId];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * 0.52;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SizedBox(
            height: h,
            child: Directionality(
              textDirection: AppLocaleScope.of(ctx).textDirection,
              child: _DayScheduleGlassSheet(
                doctorUserId: uid,
                dateLocal: d0,
                existingDocId: docId,
                initialRow: row,
                strings: S.of(ctx),
              ),
            ),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _openFutureDayDetailsSheet(
    BuildContext context,
    DateTime day,
    Map<String, Map<String, dynamic>> openById,
  ) async {
    final uid = widget.managedDoctorUserId?.trim() ?? '';
    if (uid.isEmpty) return;
    final d0 = _dateOnly(day);
    final docId = availableDayDocumentId(doctorUserId: uid, dateLocal: d0);
    final row = openById[docId];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * 0.62;
        return SizedBox(
          height: h,
          child: Directionality(
            textDirection: AppLocaleScope.of(ctx).textDirection,
            child: _FutureDayDetailsGlassSheet(
              doctorUserId: uid,
              dateLocal: d0,
              dayRow: row,
              strings: S.of(ctx),
            ),
          ),
        );
      },
    );
  }

  void _onScheduleDayTapped(
    DateTime day,
    Map<String, Map<String, dynamic>> openById,
  ) {
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
      return;
    }
    if (_scheduleIsSameDay(d0, today)) {
      _openDayEditorSheet(context, d0, openById);
      return;
    }
    _openFutureDayDetailsSheet(context, d0, openById);
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
        ? _kSchedVibrantGreen.withValues(alpha: 0.88)
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
          color: _kSchedVibrantGreen.withValues(alpha: 0.45),
          blurRadius: 14,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: _kSchedVibrantGreen.withValues(alpha: 0.28),
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

    Color fill;
    Color textColor;
    var strike = false;

    if (isPast) {
      fill = const Color(0xFFF1F3F5);
      textColor = const Color(0xFF64748B);
      strike = true;
    } else if (!closedLook) {
      fill = _kSchedOpenFill;
      textColor = Colors.white;
    } else {
      fill = _kSchedClosedFill;
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
            color: fill,
            borderRadius: radius,
            border: isSelected
                ? Border.all(color: _kSchedGoldRing, width: _kSelectedGoldBorder)
                : null,
          ),
          child: Center(
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
                  decoration:
                      strike ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: const Color(0xFF64748B),
                  decorationThickness: 1.5,
                ),
              ),
            ),
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
        onTap: () => _onScheduleDayTapped(day, openById),
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

  /// Today control strip — linear glass summary (no oversized numeral / “clock” hero).
  Widget _buildGreenScheduleDatePanel({
    required BuildContext context,
    required DateTime today,
    required Map<String, Map<String, dynamic>> map,
    required AppLocalizations strings,
  }) {
    const radius = 20.0;
    final border = Border.all(
      color: kStaffLuxGold.withValues(alpha: 0.5),
      width: 0.5,
    );
    final uid = widget.managedDoctorUserId?.trim() ?? '';
    final docId = uid.isEmpty
        ? ''
        : availableDayDocumentId(doctorUserId: uid, dateLocal: today);
    final row = docId.isEmpty ? null : map[docId];
    final open = row != null && availableDayIsOpen(row);
    final sh = normalizeAvailableDayStartTimeHhMm(row?[AvailableDayFields.startTime]);
    final eh = normalizeAvailableDayClosingTimeHhMm(row?[AvailableDayFields.closingTime]);
    final rangeLine = open
        ? '${_scheduleHhMmToEnglish12h(sh)} – ${_scheduleHhMmToEnglish12h(eh)}'
        : null;
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;

    return Tooltip(
      message: strings.translate('schedule_panel_tap_hint'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDayEditorSheet(context, today, map),
              splashColor: Colors.white.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kStaffShellGradientTop.withValues(alpha: 0.88),
                      const Color(0xFF0A1528).withValues(alpha: 0.94),
                    ],
                  ),
                  border: border,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.translate('schedule_today_shifts_title'),
                              style: TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: kStaffLuxGold.withValues(alpha: 0.95),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Directionality(
                              textDirection: ui.TextDirection.ltr,
                              child: Text(
                                _enNum(today),
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: open
                                        ? _kSchedVibrantGreen
                                        : _kSchedClosedFill,
                                    boxShadow: open
                                        ? [
                                            BoxShadow(
                                              color: _kSchedVibrantGreen
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    open
                                        ? strings.translate(
                                            'booking_summary_status_open',
                                          )
                                        : strings.translate(
                                            'booking_summary_status_closed',
                                          ),
                                    style: TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.76),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (open)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Directionality(
                                  textDirection: ui.TextDirection.ltr,
                                  child: Text(
                                    rangeLine!,
                                    style: TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: kStaffLuxGold.withValues(alpha: 0.92),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isRtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: kStaffLuxGold.withValues(alpha: 0.75),
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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

        final today = _dateOnly(DateTime.now());

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

              final column = Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  SizedBox(height: _kCalendarBottomGap),
                  SizedBox(
                    width: fullW,
                    child: _buildGreenScheduleDatePanel(
                      context: context,
                      today: today,
                      map: map,
                      strings: s,
                    ),
                  ),
                ],
              );

              if (constraints.hasBoundedHeight) {
                return SizedBox(
                  width: fullW,
                  height: constraints.maxHeight,
                  child: column,
                );
              }
              return column;
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

Widget _scheduleFutureDetailStatRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: kStaffLuxGold, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.2,
                color: Color(0xFFE8EEF5),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Read-only overview for a **future** calendar day (deep blue glass).
class _FutureDayDetailsGlassSheet extends StatelessWidget {
  const _FutureDayDetailsGlassSheet({
    required this.doctorUserId,
    required this.dateLocal,
    required this.dayRow,
    required this.strings,
  });

  final String doctorUserId;
  final DateTime dateLocal;
  final Map<String, dynamic>? dayRow;
  final AppLocalizations strings;

  String _hoursSummary() {
    if (dayRow == null || !availableDayIsOpen(dayRow!)) {
      return strings.translate('schedule_detail_day_closed');
    }
    final start = normalizeAvailableDayStartTimeHhMm(
      dayRow![AvailableDayFields.startTime],
    );
    final end = normalizeAvailableDayClosingTimeHhMm(
      dayRow![AvailableDayFields.closingTime],
    );
    return '${_scheduleHhMmToEnglish12h(start)} – ${_scheduleHhMmToEnglish12h(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.decimalPattern('en_US');

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.5),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kStaffLuxGold.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  strings.translate('schedule_future_day_sheet_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFFE8EEF5),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Text(
                  _enNum(dateLocal),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kStaffLuxGold.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  stream: watchDoctorAppointmentsForLocalDay(
                    doctorUserId: doctorUserId,
                    dayLocal: dateLocal,
                  ),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      logFirestoreIndexHelpOnce(
                        snap.error,
                        tag: 'ScheduleManagementScreen.future_day_appts',
                        expectedCompositeIndexHint:
                            kAppointmentsDoctorDateStatusIndexHint,
                      );
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: [
                          Text(
                            strings.translate('schedule_load_error'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: kPatientPrimaryFont,
                            ),
                          ),
                        ],
                      );
                    }
                    final raw =
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                      snap.data ?? [],
                    );
                    _scheduleSortAppointmentDocs(raw);
                    final active = raw
                        .where((d) => !_scheduleApptIsCancelled(d.data()))
                        .toList();
                    final count = active.length;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        _scheduleFutureDetailStatRow(
                          icon: Icons.people_alt_rounded,
                          label: strings.translate(
                            'schedule_detail_total_patients',
                          ),
                          value: strings.translate(
                            'schedule_detail_patients_count',
                            params: {'n': nf.format(count)},
                          ),
                        ),
                        const SizedBox(height: 12),
                        _scheduleFutureDetailStatRow(
                          icon: Icons.schedule_rounded,
                          label: strings.translate(
                            'schedule_detail_working_hours',
                          ),
                          value: _hoursSummary(),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          strings.translate('schedule_detail_patient_list'),
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (active.isEmpty)
                          Text(
                            strings.translate(
                              'schedule_detail_no_appointments',
                            ),
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          )
                        else
                          ...active.map((doc) {
                            final data = doc.data();
                            final name =
                                (data[AppointmentFields.patientName] ?? '')
                                    .toString()
                                    .trim();
                            final t = staffDigitsToEnglishAscii(
                              (data[AppointmentFields.time] ?? '')
                                  .toString()
                                  .trim(),
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name.isEmpty ? '—' : name,
                                      style: const TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: Color(0xFFF0F4FA),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    t.isEmpty ? '—' : t,
                                    style: TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: kStaffLuxGold.withValues(
                                        alpha: 0.95,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
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
}

class _DayScheduleGlassSheet extends StatefulWidget {
  const _DayScheduleGlassSheet({
    required this.doctorUserId,
    required this.dateLocal,
    required this.existingDocId,
    required this.initialRow,
    required this.strings,
  });

  final String doctorUserId;
  final DateTime dateLocal;
  final String existingDocId;
  final Map<String, dynamic>? initialRow;
  final AppLocalizations strings;

  @override
  State<_DayScheduleGlassSheet> createState() => _DayScheduleGlassSheetState();
}

class _DayScheduleGlassSheetState extends State<_DayScheduleGlassSheet> {
  static const double _kDashboardBlur = 36;
  static const List<int> _kDurationChoices = [15, 20, 30, 45];

  static int _coerceDurationToChoices(int minutes) {
    if (_kDurationChoices.contains(minutes)) return minutes;
    var best = _kDurationChoices[2];
    var bestD = 1 << 30;
    for (final c in _kDurationChoices) {
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
  late PageController _pageController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    final row = widget.initialRow;
    _isOpen = row != null && availableDayIsOpen(row);
    final sh = normalizeAvailableDayStartTimeHhMm(row?[AvailableDayFields.startTime]);
    final eh = normalizeAvailableDayClosingTimeHhMm(row?[AvailableDayFields.closingTime]);
    _start = _parseHhMm(sh) ?? const TimeOfDay(hour: 9, minute: 0);
    _end = _parseHhMm(eh) ?? const TimeOfDay(hour: 20, minute: 0);
    _durationMin = _coerceDurationToChoices(
      normalizeAppointmentDurationMinutes(
        row?[AvailableDayFields.appointmentDuration],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  Future<void> _pickStart() async {
    final p = await showTimePicker(
      context: context,
      initialTime: _start,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (c, ch) => Directionality(
        textDirection: AppLocaleScope.of(c).textDirection,
        child: ch ?? const SizedBox.shrink(),
      ),
    );
    if (p != null) setState(() => _start = p);
  }

  Future<void> _pickEnd() async {
    final p = await showTimePicker(
      context: context,
      initialTime: _end,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (c, ch) => Directionality(
        textDirection: AppLocaleScope.of(c).textDirection,
        child: ch ?? const SizedBox.shrink(),
      ),
    );
    if (p != null) setState(() => _end = p);
  }

  Future<void> _save() async {
    final s = widget.strings;
    setState(() => _saving = true);
    try {
      final id = widget.existingDocId;
      final hasDoc = widget.initialRow != null;

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
        Navigator.pop(context);
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

  String _slotStartEnglish(DateTime slotStart) =>
      DateFormat.jm('en_US').format(slotStart);

  Map<String, String> _patientByTimeKey(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final m = <String, String>{};
    for (final d in docs) {
      if (_scheduleApptIsCancelled(d.data())) continue;
      final k = normalizeAppointmentTimeToHhMm(
        d.data()[AppointmentFields.time],
      );
      if (k.isEmpty) continue;
      final n =
          (d.data()[AppointmentFields.patientName] ?? '').toString().trim();
      m.putIfAbsent(k, () => n.isEmpty ? '—' : n);
    }
    return m;
  }

  Widget _dashboardGlassCard({
    required Widget child,
    EdgeInsetsGeometry? pad,
    double radius = 14,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: pad ?? const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _goldIcon(IconData icon, {double size = 22}) {
    return Icon(icon, size: size, color: kStaffLuxGold);
  }

  Widget _segmentCell({required int index, required String label}) {
    final sel = _tabIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: sel
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: sel
                  ? _kSchedVibrantGreen.withValues(alpha: 0.9)
                  : kStaffLuxGold.withValues(alpha: 0.22),
              width: sel ? 1 : 0.45,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: _kSchedVibrantGreen.withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: _kSchedVibrantGreen.withValues(alpha: 0.25),
                      blurRadius: 22,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              height: 1.12,
              color: sel
                  ? Colors.white.withValues(alpha: 0.98)
                  : Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }

  Widget _segmented(AppLocalizations s) {
    return Row(
      children: [
        Expanded(
          child: _segmentCell(
            index: 0,
            label: s.translate('schedule_today_focus_tab_time'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _segmentCell(
            index: 1,
            label: s.translate('schedule_today_focus_tab_list'),
          ),
        ),
      ],
    );
  }

  Widget _clinicStatusBar(AppLocalizations s) {
    return _dashboardGlassCard(
      radius: 12,
      pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _goldIcon(Icons.local_hospital_rounded, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.translate('schedule_clinic_status_title'),
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.94),
              ),
            ),
          ),
          CupertinoSwitch(
            value: _isOpen,
            onChanged: (v) => setState(() => _isOpen = v),
            activeTrackColor: _kSchedVibrantGreen,
            inactiveTrackColor: _kSchedClosedFill.withValues(alpha: 0.55),
            thumbColor: CupertinoColors.white,
          ),
        ],
      ),
    );
  }

  Widget _linearTimeGlassCard({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required String timeEnglish12h,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: _dashboardGlassCard(
          radius: 12,
          pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _goldIcon(icon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Text(
                  timeEnglish12h,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: kStaffLuxGold.withValues(alpha: 0.98),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationChipRow(AppLocalizations s) {
    final nf = NumberFormat.decimalPattern('en_US');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _goldIcon(Icons.hourglass_bottom_rounded, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.translate('schedule_duration_per_appointment_label'),
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _kDurationChoices.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _durationChoiceChip(
                  minutes: _kDurationChoices[i],
                  label: '${nf.format(_kDurationChoices[i])} min',
                  selected: _durationMin == _kDurationChoices[i],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _durationChoiceChip({
    required int minutes,
    required String label,
    required bool selected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _durationMin = minutes),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? _kSchedVibrantGreen.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? _kSchedVibrantGreen.withValues(alpha: 0.92)
                  : kStaffLuxGold.withValues(alpha: 0.38),
              width: selected ? 1.05 : 0.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _kSchedVibrantGreen.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: selected
                    ? Colors.white.withValues(alpha: 0.98)
                    : Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Linear “Today’s control” — status bar, glass time rows, duration chips (no clock dial).
  Widget _settingsPage(AppLocalizations s) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      children: [
        _clinicStatusBar(s),
        if (_isOpen) ...[
          const SizedBox(height: 10),
          _linearTimeGlassCard(
            onTap: _pickStart,
            icon: Icons.login_rounded,
            label: s.translate('schedule_control_start_time_label'),
            timeEnglish12h: _scheduleHhMmToEnglish12h(_fmt(_start)),
          ),
          const SizedBox(height: 8),
          _linearTimeGlassCard(
            onTap: _pickEnd,
            icon: Icons.logout_rounded,
            label: s.translate('schedule_control_end_time_label'),
            timeEnglish12h: _scheduleHhMmToEnglish12h(_fmt(_end)),
          ),
          const SizedBox(height: 10),
          _dashboardGlassCard(
            radius: 12,
            pad: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: _durationChipRow(s),
          ),
        ],
        const SizedBox(height: 10),
        StaffGoldGradientButton(
          label: s.translate('schedule_save_button'),
          onPressed: _saving ? null : _save,
          isLoading: _saving,
          fontSize: 13,
          borderRadius: 12,
          minHeight: 42,
        ),
      ],
    );
  }

  Widget _slotTimelineRow({
    required AppLocalizations s,
    required DateTime slotStart,
    required bool booked,
    required String? patientName,
    required bool showConnectorBelow,
  }) {
    final timeStr = _slotStartEnglish(slotStart);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: booked
                        ? const Color(0xFF90A4AE)
                        : _kSchedVibrantGreen,
                    border: Border.all(
                      color: kStaffLuxGold.withValues(alpha: 0.45),
                      width: 0.4,
                    ),
                    boxShadow: booked
                        ? null
                        : [
                            BoxShadow(
                              color: _kSchedVibrantGreen.withValues(alpha: 0.55),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                ),
                if (showConnectorBelow)
                  Container(
                    width: 1.5,
                    height: 12,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      color: kStaffLuxGold.withValues(alpha: 0.22),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dashboardGlassCard(
              radius: 12,
              pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: booked
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _goldIcon(Icons.person_pin_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (patientName ?? '').isEmpty
                                    ? '—'
                                    : patientName!,
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.94),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Directionality(
                                textDirection: ui.TextDirection.ltr,
                                child: Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: kStaffLuxGold.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          s.translate('schedule_slot_booked'),
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            color: const Color(0xFFFFCDD2),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Directionality(
                          textDirection: ui.TextDirection.ltr,
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: kStaffLuxGold.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kSchedVibrantGreen,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    _kSchedVibrantGreen.withValues(alpha: 0.5),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.translate('schedule_slot_available_ku'),
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotsPage(AppLocalizations s) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: watchDoctorAppointmentsForLocalDay(
        doctorUserId: widget.doctorUserId,
        dayLocal: widget.dateLocal,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          logFirestoreIndexHelpOnce(
            snap.error,
            tag: 'ScheduleManagementScreen.today_dashboard_appts',
            expectedCompositeIndexHint: kAppointmentsDoctorDateStatusIndexHint,
          );
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(14, 2, 14, 12 + bottom),
            children: [
              Text(
                s.translate('schedule_load_error'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: kPatientPrimaryFont,
                ),
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: kStaffLuxGold,
              strokeWidth: 2,
            ),
          );
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snap.data ?? [],
        );
        final patientByKey = _patientByTimeKey(docs);

        if (!_isOpen) {
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(14, 2, 14, 12 + bottom),
            children: [
              Row(
                children: [
                  _goldIcon(Icons.event_busy_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.translate('schedule_timeline_no_hours'),
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        final slots = generatedSlotStartsForDay(
          dateOnly: widget.dateLocal,
          startTimeHhMm: _fmt(_start),
          closingTimeHhMm: _fmt(_end),
          durationMinutes: _durationMin,
        );

        final slotKeys = slots.map(formatTimeHhMm).toSet();
        final otherDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final d in docs) {
          if (_scheduleApptIsCancelled(d.data())) continue;
          final k = normalizeAppointmentTimeToHhMm(
            d.data()[AppointmentFields.time],
          );
          if (k.isEmpty || !slotKeys.contains(k)) {
            otherDocs.add(d);
          }
        }

        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(14, 2, 14, 12 + bottom),
          children: [
            Row(
              children: [
                _goldIcon(Icons.view_timeline_rounded, size: 17),
                const SizedBox(width: 6),
                Text(
                  s.translate('schedule_today_focus_tab_list'),
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (slots.isEmpty)
              Text(
                s.translate('schedule_timeline_no_slots'),
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              )
            else
              for (var i = 0; i < slots.length; i++)
                _slotTimelineRow(
                  s: s,
                  slotStart: slots[i],
                  booked: patientByKey.containsKey(formatTimeHhMm(slots[i])),
                  patientName: patientByKey[formatTimeHhMm(slots[i])],
                  showConnectorBelow: i < slots.length - 1,
                ),
            if (otherDocs.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                s.translate('schedule_timeline_other_bookings'),
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              ...otherDocs.map((d) {
                final data = d.data();
                final t = staffDigitsToEnglishAscii(
                  (data[AppointmentFields.time] ?? '').toString().trim(),
                );
                final n =
                    (data[AppointmentFields.patientName] ?? '').toString().trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _dashboardGlassCard(
                    pad: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _goldIcon(Icons.warning_amber_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Directionality(
                                textDirection: ui.TextDirection.ltr,
                                child: Text(
                                  t.isEmpty ? '—' : t,
                                  style: TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: kStaffLuxGold.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                              if (n.isNotEmpty)
                                Text(
                                  n,
                                  style: TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _kDashboardBlur,
          sigmaY: _kDashboardBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kStaffShellGradientTop.withValues(alpha: 0.94),
                kStaffShellGradientMid.withValues(alpha: 0.92),
                const Color(0xFF0A1528).withValues(alpha: 0.97),
              ],
            ),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.48),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: kStaffLuxGold.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Text(
                      s.translate('schedule_today_shifts_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        _enNum(widget.dateLocal),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: kStaffLuxGold.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _segmented(s),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  clipBehavior: Clip.hardEdge,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (i) => setState(() => _tabIndex = i),
                  children: [
                    _settingsPage(s),
                    _slotsPage(s),
                  ],
                ),
              ),
              SizedBox(height: bottom > 0 ? bottom : 6),
            ],
          ),
        ),
      ),
    );
  }
}
