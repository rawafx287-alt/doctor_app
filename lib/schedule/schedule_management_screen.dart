import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/root_notifications_firestore.dart';
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
/// Selected day highlight (secretary calendar); open/closed colors unchanged when not selected.
const Color _kSchedSelectedFill = Color(0xFF0D47A1);
/// Past dates — desaturated slate wash (read-only, no schedule edits).
const Color _kSchedPastDaySurface = Color(0xFF475569);
/// Past date numerals — light grey, readable, non-interactive look.
const Color _kSchedPastDayText = Color(0xFFCBD5E1);
/// Focus ring for the secretary’s selected calendar day (pulse + border).
const Color _kSelectedDayFocusGold = Color(0xFFFFD54F);
const double _kDayBoxR = 10.0;
/// Space between time-settings card and pinned calendar.
const double _kTimeToCalendarGap = 18.0;
const double _kPrimaryGlassBlur = 22.0;
const double _kGridCrossAxisSpacing = 5.0;
const double _kGridMainAxisSpacing = 2.0;
/// Space from last date row to inner bottom of gold-bordered card (~red line).
const double _kCalendarCardBottomPadding = 10.0;
/// Extra bottom inset when [ScheduleManagementScreen.embeddedBodyExtendsBehindBottomBar]
/// is true (parent [Scaffold.extendBody] so content draws under the bottom bar).
const double _kEmbeddedOverlapBottomReserve = 84.0;
const double _kBodyHorizontalPad = 12.0;
const double _kPrimaryCardPadding = 10.0;
/// Fixed month title row (avoids tall IconButton tap targets stretching the card).
const double _kScheduleMonthHeaderH = 42.0;
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

/// Sorani month name + English numerals year (e.g. نیسان 2026).
const List<String> _kMonthNamesKurdishCkb = [
  '',
  'کانوونی دووەم',
  'شوبات',
  'ئازار',
  'نیسان',
  'ئایار',
  'حوزەیران',
  'تەمموز',
  'ئاب',
  'ئەیلوول',
  'تشرینی یەکەم',
  'تشرینی دووەم',
  'کانوونی یەکەم',
];

String _kurdishMonthYearTitle(DateTime d) {
  final nf = NumberFormat.decimalPattern('en_US');
  final name = _kMonthNamesKurdishCkb[d.month];
  return '$name ${nf.format(d.year)}';
}

/// Selected day badge under time-settings title (monospaced EN numerals).
Widget _scheduleSelectedDateBadge(DateTime d) {
  final nf = NumberFormat.decimalPattern('en_US');
  final nums =
      '${nf.format(d.day)} / ${nf.format(d.month)} / ${nf.format(d.year)}';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF90CAF9).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFF64B5F6).withValues(alpha: 0.38),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.calendar_month_rounded,
          size: 16,
          color: const Color(0xFFBBDEFB).withValues(alpha: 0.95),
        ),
        const SizedBox(width: 8),
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Text(
            nums,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: Colors.white.withValues(alpha: 0.94),
              letterSpacing: 0.35,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Floating success snackbar after schedule save (dark panel, green rim, checkmark).
void showScheduleSaveSuccessSnackBar(BuildContext context, String message) {
  const bg = Color(0xFF1B2838);
  const border = Color(0xFF43A047);
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      elevation: 12,
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      content: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.right,
                textDirection: ui.TextDirection.rtl,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF81C784),
              size: 24,
            ),
          ],
        ),
      ),
    ),
  );
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
    /// Set true when the parent shell uses [Scaffold.extendBody] and a bottom bar
    /// overlaps the body (e.g. secretary home). Doctor home does not — leave false.
    this.embeddedBodyExtendsBehindBottomBar = false,
  });

  final String? managedDoctorUserId;
  final bool embedded;
  final bool embeddedBodyExtendsBehindBottomBar;

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen>
    with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late final AnimationController _selectedDayPulseController;
  late final Animation<double> _selectedDayPulse;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _selectedDay = DateTime(n.year, n.month, n.day);
    _selectedDayPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _selectedDayPulse = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _selectedDayPulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _selectedDayPulseController.dispose();
    super.dispose();
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
    if (d0.isBefore(today)) {
      return;
    }
    setState(() => _selectedDay = d0);
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

  /// Weekday label: [isTodayWeekday] adds neon pill under name + brighter text.
  Widget _dowGlassCapsule(
    String label, {
    required double maxWidth,
    required bool isTodayWeekday,
  }) {
    final h = _kDowCapsuleHeight;
    final r = h * 0.5;
    final fill = Colors.white.withValues(alpha: 0.1);

    final borderColor = isTodayWeekday
        ? _kSchedOpenFill.withValues(alpha: 0.75)
        : kStaffLuxGold.withValues(alpha: 0.45);
    final borderW = isTodayWeekday ? 0.75 : _kDowCapsuleBorderThin;

    final shadows = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
      if (isTodayWeekday) ...[
        BoxShadow(
          color: _kSchedOpenFill.withValues(alpha: 0.4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ],
    ];

    final textColor =
        isTodayWeekday ? Colors.white : Colors.white.withValues(alpha: 0.52);

    const neon = Color(0xFF00E676);
    final pillW = (maxWidth * 0.58).clamp(18.0, 34.0);

    final capsule = Container(
      width: maxWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
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
                      color: Colors.black.withValues(
                        alpha: isTodayWeekday ? 0.35 : 0.2,
                      ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        capsule,
        if (isTodayWeekday) ...[
          const SizedBox(height: 3),
          Container(
            height: 5,
            width: pillW,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: neon,
              boxShadow: [
                BoxShadow(
                  color: neon.withValues(alpha: 0.9),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFF69F0AE).withValues(alpha: 0.65),
                  blurRadius: 14,
                  spreadRadius: -1,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Day cell — English numerals; NRT-Bd; size from parent grid.
  Widget _scheduleDayBox({
    required double side,
    required DateTime day,
    required Map<String, Map<String, dynamic>> openById,
    required bool isSelected,
    VoidCallback? onTap,
    Animation<double>? selectionPulse,
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
      flatFill = _kSchedPastDaySurface.withValues(alpha: 0.38);
      crystalGrad = null;
      textColor = _kSchedPastDayText.withValues(alpha: 0.92);
      strike = false;
    } else if (isSelected) {
      flatFill = _kSchedSelectedFill;
      crystalGrad = null;
      textColor = Colors.white;
      strike = false;
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

    final stackChildren = <Widget>[
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
              decorationColor: const Color(0xFF94A3B8),
              decorationThickness: 1.5,
            ),
          ),
        ),
      ),
    ];

    Widget dayInk() {
      final pulse = selectionPulse;
      if (isSelected && pulse != null) {
        return AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final t = pulse.value;
            return Ink(
              width: side,
              height: side,
              decoration: BoxDecoration(
                color: flatFill,
                gradient: crystalGrad,
                borderRadius: radius,
                border: Border.all(
                  color: _kSelectedDayFocusGold,
                  width: 2.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.42 * t),
                    blurRadius: 14 + 10 * t,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: _kSelectedDayFocusGold.withValues(alpha: 0.4 * t),
                    blurRadius: 12 + 8 * t,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: stackChildren,
              ),
            );
          },
        );
      }
      return Ink(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: flatFill,
          gradient: crystalGrad,
          borderRadius: radius,
          border: isPast
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                )
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
          clipBehavior: Clip.none,
          children: stackChildren,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: onTap == null ? Colors.transparent : null,
        highlightColor: onTap == null ? Colors.transparent : null,
        child: dayInk(),
      ),
    );
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
    final d0 = _dateOnly(day);
    final today = _dateOnly(DateTime.now());
    final isPast = d0.isBefore(today);
    final sel = !isPast &&
        _selectedDay != null &&
        _scheduleIsSameDay(_selectedDay!, day);
    return Center(
      child: _scheduleDayBox(
        side: side,
        day: day,
        openById: openById,
        isSelected: sel,
        selectionPulse: sel ? _selectedDayPulse : null,
        onTap: isPast ? null : () => _onScheduleDayTapped(day),
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
    final todayWeekdayCol = _scheduleWeekdayColumnIndex(DateTime.now());

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
                const SizedBox(width: 10),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    _kurdishMonthYearTitle(_focusedDay),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0D2137),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: kPatientPrimaryFont,
                      letterSpacing: 0.2,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                        isTodayWeekday: i == todayWeekdayCol,
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

        final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
        final bottomReserve = !widget.embedded
            ? 8.0
            : widget.embeddedBodyExtendsBehindBottomBar
                ? _kEmbeddedOverlapBottomReserve + viewBottom
                : 12.0 + viewBottom;

        final sel = _selectedDay ?? _dateOnly(DateTime.now());
        final docId = availableDayDocumentId(
          doctorUserId: uid,
          dateLocal: sel,
        );
        final dayRow = map[docId];

        final scrollBody = _ScheduleDayPanelHost(
          key: ValueKey<String>(docId),
          doctorUserId: uid,
          dateLocal: sel,
          existingDocId: docId,
          dayRow: dayRow,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  _kBodyHorizontalPad,
                  10,
                  _kBodyHorizontalPad,
                  0,
                ),
                sliver: const SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: _ScheduleTimeCardPanel(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  _kBodyHorizontalPad,
                  0,
                  _kBodyHorizontalPad,
                  0,
                ),
                sliver: const SliverToBoxAdapter(
                  child: SizedBox(height: _kTimeToCalendarGap),
                ),
              ),
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final fullW =
                      constraints.crossAxisExtent - 2 * _kBodyHorizontalPad;
                  final cardInnerW = fullW - 2 * _kPrimaryCardPadding;
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      _kBodyHorizontalPad,
                      0,
                      _kBodyHorizontalPad,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: RepaintBoundary(
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
                    ),
                  );
                },
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  _kBodyHorizontalPad,
                  10,
                  _kBodyHorizontalPad,
                  bottomReserve,
                ),
                sliver: const SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RepaintBoundary(
                        child: _ScheduleSlotsCardPanel(),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (widget.embedded) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: kDoctorPremiumGradientDecoration,
              child: scrollBody,
            ),
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
              SafeArea(child: scrollBody),
            ],
          ),
        );
      },
    );
  }
}

/// Shared day panel state for time settings + slot list (split across scroll slivers).
class ScheduleDayPanelScope extends InheritedNotifier<ScheduleDayPanelController> {
  const ScheduleDayPanelScope({
    super.key,
    required ScheduleDayPanelController super.notifier,
    required super.child,
  });

  static ScheduleDayPanelController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ScheduleDayPanelScope>();
    assert(scope != null, 'ScheduleDayPanelScope not found');
    return scope!.notifier!;
  }
}

class _ScheduleDayPanelHost extends StatefulWidget {
  const _ScheduleDayPanelHost({
    super.key,
    required this.doctorUserId,
    required this.dateLocal,
    required this.existingDocId,
    this.dayRow,
    required this.child,
  });

  final String doctorUserId;
  final DateTime dateLocal;
  final String existingDocId;
  final Map<String, dynamic>? dayRow;
  final Widget child;

  @override
  State<_ScheduleDayPanelHost> createState() => _ScheduleDayPanelHostState();
}

class _ScheduleDayPanelHostState extends State<_ScheduleDayPanelHost> {
  late ScheduleDayPanelController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScheduleDayPanelController(
      doctorUserId: widget.doctorUserId,
      dateLocal: widget.dateLocal,
      existingDocId: widget.existingDocId,
      dayRow: widget.dayRow,
    );
  }

  @override
  void didUpdateWidget(covariant _ScheduleDayPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateLocal != widget.dateLocal ||
        oldWidget.existingDocId != widget.existingDocId) {
      _controller.applyHostDateOrDocChange(
        doctorUserId: widget.doctorUserId,
        dateLocal: widget.dateLocal,
        existingDocId: widget.existingDocId,
        dayRow: widget.dayRow,
      );
    } else if (oldWidget.dayRow != widget.dayRow) {
      _controller.applyDayRowRefresh(widget.dayRow);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScheduleDayPanelScope(
      notifier: _controller,
      child: widget.child,
    );
  }
}

class _ScheduleTimeCardPanel extends StatelessWidget {
  const _ScheduleTimeCardPanel();

  @override
  Widget build(BuildContext context) {
    final c = ScheduleDayPanelScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return c.buildTimeCard(context, compact);
      },
    );
  }
}

class _ScheduleSlotsCardPanel extends StatelessWidget {
  const _ScheduleSlotsCardPanel();

  @override
  Widget build(BuildContext context) {
    final c = ScheduleDayPanelScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return c.buildSlotsCard(context, compact);
      },
    );
  }
}

class ScheduleDayPanelController extends ChangeNotifier {
  static const List<int> _kDurations = [15, 30, 45, 60];

  ScheduleDayPanelController({
    required String doctorUserId,
    required DateTime dateLocal,
    required String existingDocId,
    Map<String, dynamic>? dayRow,
  })  : _doctorUserId = doctorUserId,
        _dateLocal = dateLocal,
        _existingDocId = existingDocId,
        _dayRow = dayRow {
    _applyRowSnapshot();
  }

  String _doctorUserId;
  DateTime _dateLocal;
  String _existingDocId;
  Map<String, dynamic>? _dayRow;

  void applyHostDateOrDocChange({
    required String doctorUserId,
    required DateTime dateLocal,
    required String existingDocId,
    Map<String, dynamic>? dayRow,
  }) {
    _doctorUserId = doctorUserId;
    _dateLocal = dateLocal;
    _existingDocId = existingDocId;
    _dayRow = dayRow;
    _applyRowSnapshot();
    _timeExpanded = false;
    _slotsExpanded = false;
    notifyListeners();
  }

  void applyDayRowRefresh(Map<String, dynamic>? dayRow) {
    _dayRow = dayRow;
    _applyRowSnapshot();
    notifyListeners();
  }

  static int _coerceDuration(int minutes) {
    if (_kDurations.contains(minutes)) return minutes;
    var best = _kDurations[1];
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

  // Mutual exclusion between the two cards.
  bool _timeExpanded = false;
  bool _slotsExpanded = false;

  void _applyRowSnapshot() {
    final row = _dayRow;
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
      _dateOnly(_dateLocal).isBefore(_dateOnly(DateTime.now()));

  Future<void> _pickStart(BuildContext context) async {
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
    if (p != null) {
      _start = p;
      notifyListeners();
    }
  }

  Future<void> _pickEnd(BuildContext context) async {
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
    if (p != null) {
      _end = p;
      notifyListeners();
    }
  }

  Future<void> _save(BuildContext context) async {
    if (_isPast) return;
    final s = S.of(context);
    _saving = true;
    notifyListeners();
    try {
      final id = _existingDocId;
      final hasDoc = _dayRow != null;
      final wasOpen = hasDoc && availableDayIsOpen(_dayRow!);

      if (!_isOpen) {
        if (hasDoc) {
          if (wasOpen) {
            final activeCount = await countActiveAppointmentsForDoctorLocalDay(
              doctorUserId: _doctorUserId,
              dayLocal: _dateLocal,
            );
            if (activeCount > 0) {
              if (!context.mounted) return;
              _saving = false;
              notifyListeners();
              final proceed = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final loc = S.of(ctx);
                  final nf = NumberFormat.decimalPattern('en_US');
                  return AlertDialog(
                    backgroundColor: const Color(0xFF0D2137),
                    title: Text(
                      loc.translate('schedule_close_day_bulk_title'),
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE8EEF4),
                      ),
                    ),
                    content: Text(
                      loc.translate(
                        'schedule_close_day_bulk_body',
                        params: {'count': nf.format(activeCount)},
                      ),
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          loc.translate('appt_action_confirm_no'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          loc.translate('appt_action_confirm_yes'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE57373),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
              if (!context.mounted) return;
              if (proceed != true) return;
              _saving = true;
              notifyListeners();
              await bulkCancelActiveAppointmentsForDoctorLocalDay(
                doctorUserId: _doctorUserId,
                dayLocal: _dateLocal,
                cancellationReason: kAppointmentCancellationReasonClinicClosed,
              );
            }
          }
          await setAvailableDayOpenState(availableDayDocId: id, isOpen: false);
        }
      } else {
        if (!hasDoc) {
          await openAvailableDay(
            doctorUserId: _doctorUserId,
            dateLocal: _dateLocal,
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
      if (context.mounted) {
        showScheduleSaveSuccessSnackBar(
          context,
          s.translate('schedule_save_ok'),
        );
      }
    } catch (_) {
      if (context.mounted) {
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
      if (context.mounted) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  Widget _timeRow({
    required AppLocalizations loc,
    required VoidCallback onTap,
    required IconData icon,
    double iconSize = 17,
    required String label,
    required String timeEn12h,
    required bool enabled,
  }) {
    final goldSoft = kStaffLuxGold.withValues(alpha: enabled ? 0.92 : 0.35);

    Widget timeDisplay = Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: kStaffLuxGold.withValues(alpha: enabled ? 0.09 : 0.04),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: kStaffLuxGold.withValues(alpha: enabled ? 0.5 : 0.2),
            width: 0.8,
          ),
        ),
        child: Text(
          timeEn12h,
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
            height: 1.1,
            letterSpacing: 0.2,
            color: kStaffLuxGold.withValues(alpha: enabled ? 0.98 : 0.45),
          ),
        ),
      ),
    );

    return Tooltip(
      message: enabled ? loc.translate('schedule_time_row_tap_hint') : '',
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.14),
          highlightColor: Colors.white.withValues(alpha: 0.07),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: enabled
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.white.withValues(alpha: 0.02),
              border: Border.all(
                color: kStaffLuxGold.withValues(alpha: enabled ? 0.22 : 0.1),
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: kStaffLuxGold.withValues(alpha: enabled ? 0.9 : 0.35),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Colors.white.withValues(
                          alpha: enabled ? 0.9 : 0.45,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          timeDisplay,
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_rounded,
                            size: 17,
                            color: goldSoft,
                          ),
                        ],
                      ),
                      if (enabled) ...[
                        const SizedBox(height: 3),
                        Text(
                          loc.translate('schedule_time_row_tap_hint'),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w600,
                            fontSize: 8,
                            height: 1.1,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Active booking per slot: patient name, doc id, status, raw data (detail sheet).
  Map<String, (String? patientName, String docId, String status,
      Map<String, dynamic> data)>
      _activeSlotBookingsByHhMm(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final m = <String, (String?, String, String, Map<String, dynamic>)>{};
    for (final d in docs) {
      final data = d.data();
      final st = (data[AppointmentFields.status] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      // Treat cancelled/rejected/available as NOT booked (slot should be available).
      if (st == 'cancelled' || st == 'canceled' || st == 'available') continue;
      final k = normalizeAppointmentTimeToHhMm(data[AppointmentFields.time]);
      if (k.isEmpty) continue;
      final n = (data[AppointmentFields.patientName] ?? '').toString().trim();
      final nameOrNull = n.isEmpty ? null : n;
      m.putIfAbsent(k, () => (nameOrNull, d.id, st, data));
    }
    return m;
  }

  Future<bool> _confirmAndCancelSecretaryBooking(
    BuildContext context,
    AppLocalizations loc, {
    required String appointmentDocId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final yesStyle = TextButton.styleFrom(
          foregroundColor: const Color(0xFFE57373),
        );
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2137),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: kStaffLuxGold.withValues(alpha: 0.45),
            ),
          ),
          title: Text(
            loc.translate('schedule_slot_cancel_confirm_title'),
            style: const TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1.35,
              color: Color(0xFFE8EEF4),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                loc.translate('schedule_slot_cancel_no'),
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB0BEC5),
                ),
              ),
            ),
            TextButton(
              style: yesStyle,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                loc.translate('schedule_slot_cancel_yes'),
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return false;
    try {
      final ref = FirebaseFirestore.instance
          .collection(AppointmentFields.collection)
          .doc(appointmentDocId);
      final priorSnap = await ref.get();
      if (!priorSnap.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc.translate('schedule_slot_cancel_error_snack'),
                style: const TextStyle(fontFamily: kPatientPrimaryFont),
              ),
            ),
          );
        }
        return false;
      }
      final priorData = priorSnap.data()!;
      await ref.update({
        // Make the slot instantly available again.
        AppointmentFields.status: 'available',
        AppointmentFields.patientName: null,
        AppointmentFields.patientId: null,
        AppointmentFields.cancellationReason:
            kAppointmentCancellationReasonSecretary,
        AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
      });
      final copy = patientAppointmentRejectedNotificationCopy(priorData);
      final doctorUid =
          (priorData[AppointmentFields.doctorId] ?? '').toString().trim();
      final doctorSnap = await loadDoctorNotificationSnapshot(doctorUid);
      await createPatientRootNotification(
        appointmentData: priorData,
        appointmentDocId: appointmentDocId,
        title: copy.$1,
        message: copy.$2,
        doctor: doctorSnap,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.translate('schedule_slot_cancel_ok_snack'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.translate('schedule_slot_cancel_error_snack'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
      return false;
    }
  }

  String _formatScheduleDayEn(DateTime d) {
    final nf = NumberFormat.decimalPattern('en_US');
    return '${nf.format(d.day)} / ${nf.format(d.month)} / ${nf.format(d.year)}';
  }

  void _showAvailableSlotBottomSheet(
    BuildContext context,
    AppLocalizations loc,
    DateTime slotStart,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(ctx).bottom + 12,
            left: 16,
            right: 16,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: kStaffLuxGold.withValues(alpha: 0.42),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('schedule_slot_available_ku'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: _kSchedOpenFill.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      DateFormat.jm('en_US').format(slotStart),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        height: 1.1,
                        color: Color(0xFFE8EEF4),
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatScheduleDayEn(_dateLocal),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    loc.translate('schedule_slot_available_sheet_hint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Gold accent for high-signal patient fields in the secretary detail sheet.
  static const Color _kPatientSheetValueGold = Color(0xFFFFE082);

  Widget _patientInfoSheetDetailCard({
    required IconData icon,
    required String label,
    required Widget value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1E293B).withValues(alpha: 0.72),
        border: Border.all(
          color: kStaffLuxGold.withValues(alpha: 0.2),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: kStaffLuxGold.withValues(alpha: 0.11),
              border: Border.all(
                color: kStaffLuxGold.withValues(alpha: 0.28),
                width: 0.65,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: kStaffLuxGold.withValues(alpha: 0.94),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    height: 1.25,
                    letterSpacing: 0.2,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientInfoSheetNotesCard(AppLocalizations loc, String notes) {
    final empty = notes.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1E293B).withValues(alpha: 0.72),
        border: Border.all(
          color: kStaffLuxGold.withValues(alpha: 0.2),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: kStaffLuxGold.withValues(alpha: 0.11),
              border: Border.all(
                color: kStaffLuxGold.withValues(alpha: 0.28),
                width: 0.65,
              ),
            ),
            child: Icon(
              Icons.sticky_note_2_outlined,
              size: 22,
              color: kStaffLuxGold.withValues(alpha: 0.94),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.translate('booking_form_medical_notes'),
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    height: 1.25,
                    letterSpacing: 0.2,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  empty
                      ? loc.translate('schedule_appointment_detail_no_notes')
                      : notes,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.45,
                    color: empty
                        ? Colors.white.withValues(alpha: 0.42)
                        : Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookedAppointmentBottomSheet(
    BuildContext context,
    AppLocalizations loc, {
    required DateTime slotStart,
    required Map<String, dynamic> data,
    required String appointmentDocId,
    required bool canCancel,
  }) {
    final name =
        (data[AppointmentFields.patientName] ?? '').toString().trim();
    final notes =
        (data[AppointmentFields.bookingMedicalNotes] ?? '').toString().trim();
    final phone =
        (data[AppointmentFields.bookingPhone] ?? '').toString().trim();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewPaddingOf(ctx).bottom + 12,
            left: 16,
            right: 16,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: kStaffLuxGold.withValues(alpha: 0.45),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 26,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    loc.translate('schedule_patient_details_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      height: 1.2,
                      letterSpacing: 0.15,
                      color: Colors.white.withValues(alpha: 0.96),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _patientInfoSheetDetailCard(
                    icon: Icons.schedule_rounded,
                    label: loc.translate('schedule_appointment_detail_time'),
                    value: Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        DateFormat.jm('en_US').format(slotStart),
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1.15,
                          letterSpacing: 0.35,
                          color: Color(0xFFE8EEF4),
                        ),
                      ),
                    ),
                  ),
                  _patientInfoSheetDetailCard(
                    icon: Icons.calendar_month_rounded,
                    label: loc.translate('schedule_appointment_detail_date'),
                    value: Text(
                      _formatScheduleDayEn(_dateLocal),
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.2,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  _patientInfoSheetDetailCard(
                    icon: Icons.person_rounded,
                    label: loc.translate('doctor_appt_patient_name_label'),
                    value: Text(
                      name.isEmpty ? '—' : name,
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.25,
                        color: _kPatientSheetValueGold,
                      ),
                    ),
                  ),
                  if (phone.isNotEmpty)
                    _patientInfoSheetDetailCard(
                      icon: Icons.phone_android_rounded,
                      label: loc.translate('booking_form_phone'),
                      value: Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Text(
                          phone,
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            height: 1.2,
                            letterSpacing: 0.2,
                            color: _kPatientSheetValueGold,
                          ),
                        ),
                      ),
                    ),
                  _patientInfoSheetNotesCard(loc, notes),
                  if (canCancel) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: OutlinedButton.icon(
                        onPressed: _isPast
                            ? null
                            : () async {
                                // Safety: [_confirmAndCancelSecretaryBooking] shows
                                // an AlertDialog ("Are you sure?") before any cancel.
                                final nav = Navigator.of(ctx);
                                final ok =
                                    await _confirmAndCancelSecretaryBooking(
                                  context,
                                  loc,
                                  appointmentDocId: appointmentDocId,
                                );
                                if (ok && ctx.mounted) {
                                  nav.pop();
                                }
                              },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                          color: Color(0xFFE57373),
                        ),
                        label: Text(
                          loc.translate('master_calendar_cancel_appt'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE57373),
                          side: const BorderSide(
                            color: Color(0xFFB71C1C),
                            width: 1.1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _slotRowTile({
    required BuildContext context,
    required AppLocalizations loc,
    required DateTime slotStart,
    required bool isBooked,
    required String? patientName,
    required VoidCallback onTap,
  }) {
    final timeEn = DateFormat.jm('en_US').format(slotStart);
    final rawName = (patientName ?? '').trim();
    final hasName = rawName.isNotEmpty;
    final displayName = hasName ? rawName : 'ناونەنراو';

    // LOGIC CHECK:
    // If patientName is not null/empty, it MUST show the booked UI.
    final booked = isBooked || hasName;

    const bookedBg = Color(0xFF1E293B); // Deep Navy
    const availableBg = Color(0xFF064E3B); // Dark Green

    // FORCED UI RENDERING TEMPLATE (Card + ListTile)
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: booked ? bookedBg : availableBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (booked)
                const SizedBox(
                  width: 6,
                  child: ColoredBox(color: Colors.amber),
                ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.fromLTRB(
                    booked ? 12 : 16,
                    10,
                    12,
                    10,
                  ),
                  leading: Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      timeEn,
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  title: booked
                      ? Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  height: 1.15,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'کاتی بەردەست',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.15,
                            color: Colors.white70,
                          ),
                        ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: booked
                          ? const Color(0xFFDC2626) // red
                          : const Color(0xFF16A34A), // green
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      booked ? 'گیراوە' : 'بەردەستە',
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        height: 1.05,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appointmentSlotRow(
    BuildContext context,
    AppLocalizations loc,
    DateTime slot,
    Map<String, (String?, String, String, Map<String, dynamic>)> byKey,
  ) {
    final k = formatTimeHhMm(slot);
    final booking = byKey[k];
    final patientName = booking?.$1;
    // LOGIC CHECK:
    // If patientName exists, we must render the booked UI.
    final isBooked = booking != null || patientName != null;
    final showCancel = booking != null &&
        !_isPast &&
        !appointmentStatusIsTerminalForStaffSort(booking.$3);
    return _slotRowTile(
      context: context,
      loc: loc,
      slotStart: slot,
      isBooked: isBooked,
      patientName: patientName,
      onTap: () {
        final b = booking;
        if (b != null) {
          _showBookedAppointmentBottomSheet(
            context,
            loc,
            slotStart: slot,
            data: b.$4,
            appointmentDocId: b.$2,
            canCancel: showCancel,
          );
        } else {
          _showAvailableSlotBottomSheet(context, loc, slot);
        }
      },
    );
  }

  Widget _buildAppointmentSlotsPanel(AppLocalizations loc) {
    if (!_isOpen) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          loc.translate('schedule_timeline_no_hours'),
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            height: 1.25,
            color: Colors.white.withValues(alpha: 0.62),
          ),
        ),
      );
    }

    final slots = generatedSlotStartsForDay(
      dateOnly: _dateLocal,
      startTimeHhMm: _fmt(_start),
      closingTimeHhMm: _fmt(_end),
      durationMinutes: _durationMin,
    );

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: watchDoctorAppointmentsForLocalDay(
        doctorUserId: _doctorUserId,
        dayLocal: _dateLocal,
      ),
      builder: (context, snap) {
        // FIX: never return an empty area silently.
        // Always show loading, empty, or the slot list.
        if (snap.hasError) {
          logFirestoreIndexHelpOnce(
            snap.error,
            tag: 'ScheduleManagementScreen.footer_slots',
            expectedCompositeIndexHint: kAppointmentsDoctorDateStatusIndexHint,
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              loc.translate('schedule_load_error'),
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: kPatientPrimaryFont,
                fontSize: 11,
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kStaffLuxGold,
                ),
              ),
            ),
          );
        }

        if (slots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              loc.translate('schedule_timeline_no_slots'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.3,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          );
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snap.data ?? [],
        );
        final byKey = _activeSlotBookingsByHhMm(docs);

        // FORCED UI RENDERING: reliable list rendering (no missing returns).
        return ListView.builder(
          itemCount: slots.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final slot = slots[index];
            return _appointmentSlotRow(context, loc, slot, byKey);
          },
        );
      },
    );
  }

  Widget _durationChip(AppLocalizations loc, int minutes, bool enabled) {
    final sel = _durationMin == minutes;
    final label = loc.translate(
      'schedule_day_slot_minutes_option',
      params: {'minutes': '$minutes'},
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                _durationMin = minutes;
                notifyListeners();
              }
            : null,
        borderRadius: BorderRadius.circular(22),
        splashColor: Colors.white.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: sel
                  ? const Color(0xFF1565C0)
                  : Colors.white.withValues(alpha: enabled ? 0.22 : 0.12),
              width: sel ? 1.5 : 1,
            ),
            color: sel
                ? const Color(0xFF0D47A1).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: enabled ? 0.07 : 0.04),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              height: 1.15,
              color: sel
                  ? Colors.white
                  : Colors.white.withValues(alpha: enabled ? 0.78 : 0.42),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(vertical: 8),
    bool emphasized = false,
  }) {
    const r = 18.0;
    final gold = kStaffLuxGold;
    final borderAlpha = emphasized ? 0.62 : 0.48;
    return Padding(
      padding: margin,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r),
                border: Border.all(
                  color: gold.withValues(alpha: borderAlpha),
                  width: emphasized ? 0.8 : 0.5,
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
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTimeCard(BuildContext context, bool compact) {
    final loc = S.of(context);
    final enabled = !_isPast;
    final gold = kStaffLuxGold;
      final titleStyle = TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w900,
        fontSize: compact ? 12 : 13,
        height: 1.2,
        color: Colors.white.withValues(alpha: 0.96),
      );

      final card = _sectionCard(
        context,
        margin: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 8),
        emphasized: _timeExpanded,
        child: ExpansionTile(
            key: const PageStorageKey<String>(
              'schedule_footer_time_settings_tile',
            ),
            maintainState: true,
            initiallyExpanded: _timeExpanded,
            onExpansionChanged: (v) {
              _timeExpanded = v;
              if (v) {
                _slotsExpanded = false;
              }
              notifyListeners();
            },
            tilePadding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              10,
              compact ? 10 : 12,
              8,
            ),
            childrenPadding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              4,
              compact ? 10 : 12,
              compact ? 10 : 12,
            ),
            dense: true,
            iconColor: gold,
            collapsedIconColor: gold.withValues(alpha: 0.88),
            title: Text(
              loc.translate('schedule_sheet_tab_settings'),
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _scheduleSelectedDateBadge(_dateLocal),
              ),
            ),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                    children: [
                      Icon(
                        Icons.local_hospital_rounded,
                        size: compact ? 15 : 16,
                        color: gold.withValues(alpha: 0.88),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        fit: FlexFit.tight,
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
                            ? (v) {
                                _isOpen = v;
                                notifyListeners();
                              }
                            : null,
                        activeTrackColor: _kSchedOpenFill,
                        inactiveTrackColor:
                            _kSchedClosedFill.withValues(alpha: 0.55),
                        thumbColor: CupertinoColors.white,
                      ),
                    ],
                  ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0x40D4AF37),
                  ),
                  const SizedBox(height: 12),
                  _timeRow(
                    loc: loc,
                    onTap: () => _pickStart(context),
                    icon: Icons.schedule_rounded,
                    iconSize: compact ? 16 : 17,
                    label: loc.translate('schedule_control_start_time_label'),
                    timeEn12h: _scheduleHhMmToEnglish12h(_fmt(_start)),
                    enabled: enabled,
                  ),
                  const SizedBox(height: 8),
                  _timeRow(
                    loc: loc,
                    onTap: () => _pickEnd(context),
                    icon: Icons.event_available_rounded,
                    iconSize: compact ? 16 : 17,
                    label: loc.translate('schedule_control_end_time_label'),
                    timeEn12h: _scheduleHhMmToEnglish12h(_fmt(_end)),
                    enabled: enabled,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    loc.translate('schedule_duration_per_appointment_label'),
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in _kDurations) _durationChip(loc, m, enabled),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StaffGoldGradientButton(
                    label: loc.translate('schedule_save_button'),
                    onPressed:
                        enabled && !_saving ? () => _save(context) : null,
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
            ],
          ),
      );
      return AnimatedScale(
        scale: _timeExpanded ? 1.0 : 0.985,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _timeExpanded ? 1.0 : 0.94,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: card,
        ),
      );
  }

  Widget buildSlotsCard(BuildContext context, bool compact) {
    final loc = S.of(context);
    final gold = kStaffLuxGold;
    final titleStyle = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w900,
      fontSize: compact ? 12 : 13,
      height: 1.2,
      color: Colors.white.withValues(alpha: 0.96),
    );
    final card = _sectionCard(
      context,
      margin: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 8),
      emphasized: _slotsExpanded,
      child: ExpansionTile(
            key: const PageStorageKey<String>(
              'schedule_footer_slot_list_tile',
            ),
            maintainState: true,
            initiallyExpanded: _slotsExpanded,
            onExpansionChanged: (v) {
              _slotsExpanded = v;
              if (v) {
                _timeExpanded = false;
              }
              notifyListeners();
            },
            tilePadding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 4 : 6,
            ),
            childrenPadding: EdgeInsets.fromLTRB(
              compact ? 10 : 12,
              0,
              compact ? 10 : 12,
              compact ? 10 : 12,
            ),
            dense: true,
            iconColor: gold,
            collapsedIconColor: gold.withValues(alpha: 0.88),
            title: Text(
              loc.translate('schedule_today_focus_tab_list'),
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            children: [
              _buildAppointmentSlotsPanel(S.of(context)),
            ],
          ),
    );
    return AnimatedScale(
      scale: _slotsExpanded ? 1.0 : 0.985,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _slotsExpanded ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: card,
      ),
    );
  }
}
