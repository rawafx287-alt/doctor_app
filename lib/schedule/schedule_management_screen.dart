import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../firestore/appointment_queries.dart';
import '../patient/create_patient_appointment.dart';
import '../firestore/root_notifications_firestore.dart';
import '../firestore/available_days_queries.dart';
import '../firestore/firestore_index_error_log.dart';
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.applyHostDateOrDocChange(
          doctorUserId: widget.doctorUserId,
          dateLocal: widget.dateLocal,
          existingDocId: widget.existingDocId,
          dayRow: widget.dayRow,
        );
      });
    } else if (oldWidget.dayRow != widget.dayRow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.applyDayRowRefresh(widget.dayRow);
      });
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
    // After saving, streams may briefly emit stale snapshots.
    // Avoid reverting the UI until Firestore reflects the values we just saved.
    if (_pendingSavedStartHhMm != null ||
        _pendingSavedEndHhMm != null ||
        _pendingSavedDurationMin != null) {
      if (!_snapshotMatchesPending(dayRow)) {
        return;
      }
      _clearPendingSavedIfMatched(dayRow);
    }
    _dayRow = dayRow;
    _applyRowSnapshot();
    notifyListeners();
  }

  late bool _isOpen;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _durationMin;
  TextEditingController? _durationController;
  var _saving = false;
  String? _pendingSavedStartHhMm;
  String? _pendingSavedEndHhMm;
  int? _pendingSavedDurationMin;

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
    final rawDur = normalizeAppointmentDurationMinutes(
      row?[AvailableDayFields.appointmentDuration],
    );
    _durationMin = rawDur <= 0 ? 15 : rawDur;
    _durationController ??= TextEditingController();
    _durationController!.text = '$_durationMin';
  }

  void _markPendingSavedValues({
    required String startHhMm,
    required String endHhMm,
    required int durationMin,
  }) {
    _pendingSavedStartHhMm = normalizeAvailableDayStartTimeHhMm(startHhMm);
    _pendingSavedEndHhMm = normalizeAvailableDayClosingTimeHhMm(endHhMm);
    _pendingSavedDurationMin = durationMin.clamp(1, 24 * 60);
  }

  bool _snapshotMatchesPending(Map<String, dynamic>? row) {
    final ps = _pendingSavedStartHhMm;
    final pe = _pendingSavedEndHhMm;
    final pd = _pendingSavedDurationMin;
    if (ps == null && pe == null && pd == null) return true;
    if (row == null) return false;
    final sh = normalizeAvailableDayStartTimeHhMm(row[AvailableDayFields.startTime]);
    final eh =
        normalizeAvailableDayClosingTimeHhMm(row[AvailableDayFields.closingTime]);
    final dur =
        normalizeAppointmentDurationMinutes(row[AvailableDayFields.appointmentDuration]);
    return sh == ps && eh == pe && dur == pd;
  }

  void _clearPendingSavedIfMatched(Map<String, dynamic>? row) {
    if (_snapshotMatchesPending(row)) {
      _pendingSavedStartHhMm = null;
      _pendingSavedEndHhMm = null;
      _pendingSavedDurationMin = null;
    }
  }

  Future<TimeOfDay?> _pickTimePremiumBottomSheet(
    BuildContext context, {
    required TimeOfDay initial,
    required String title,
  }) async {
    if (_isPast) return null;
    final loc = S.of(context);
    var h = initial.hour.clamp(0, 23);
    const minuteStep = 5;
    var minuteIndex =
        (initial.minute / minuteStep).round().clamp(0, 59 ~/ minuteStep);

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        final accent = kStaffLuxGold;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.5),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 190,
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(
                                  initialItem: h,
                                ),
                                itemExtent: 36,
                                onSelectedItemChanged: (v) => h = v,
                                selectionOverlay: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: accent.withValues(alpha: 0.18),
                                        width: 1,
                                      ),
                                      bottom: BorderSide(
                                        color: accent.withValues(alpha: 0.18),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                children: List.generate(24, (i) {
                                  return Center(
                                    child: Text(
                                      i.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(
                                  initialItem: minuteIndex,
                                ),
                                itemExtent: 36,
                                onSelectedItemChanged: (v) => minuteIndex = v,
                                selectionOverlay: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: accent.withValues(alpha: 0.18),
                                        width: 1,
                                      ),
                                      bottom: BorderSide(
                                        color: accent.withValues(alpha: 0.18),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                children: List.generate(60 ~/ minuteStep, (i) {
                                  final mm =
                                      (i * minuteStep).toString().padLeft(2, '0');
                                  return Center(
                                    child: Text(
                                      mm,
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white.withValues(alpha: 0.9),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                loc.translate('action_cancel'),
                                style: const TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final mm = (minuteIndex * minuteStep).clamp(0, 59);
                                Navigator.pop(
                                  ctx,
                                  TimeOfDay(hour: h, minute: mm),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF1565C0).withValues(alpha: 0.92),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                loc.translate('ok'),
                                style: const TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _durationController?.dispose();
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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isPast =>
      _dateOnly(_dateLocal).isBefore(_dateOnly(DateTime.now()));

  Stream<DateTime> scheduleClockStream() async* {
    yield DateTime.now();
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      yield DateTime.now();
    }
  }

  Future<void> _pickStart(BuildContext context) async {
    if (_isPast) return;
    final p = await _pickTimePremiumBottomSheet(
      context,
      initial: _start,
      title: S.of(context).translate('schedule_control_start_time_label'),
    );
    if (p != null) {
      _start = p;
      notifyListeners();
    }
  }

  Future<void> _pickEnd(BuildContext context) async {
    if (_isPast) return;
    final p = await _pickTimePremiumBottomSheet(
      context,
      initial: _end,
      title: S.of(context).translate('schedule_control_end_time_label'),
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

      final raw = (_durationController?.text ?? '').trim();
      final durEffective = int.tryParse(raw);
      if (_isOpen && (durEffective == null || durEffective <= 0)) {
        if (context.mounted) {
          _saving = false;
          notifyListeners();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                s.translate('schedule_custom_duration_required'),
                style: const TextStyle(fontFamily: kPatientPrimaryFont),
              ),
            ),
          );
        }
        return;
      }
      final dur = (durEffective ?? 15).clamp(1, 24 * 60);
      _markPendingSavedValues(
        startHhMm: _fmt(_start),
        endHhMm: _fmt(_end),
        durationMin: dur,
      );

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
            appointmentDurationMinutes: dur,
          );
        } else {
          await setAvailableDayOpenState(availableDayDocId: id, isOpen: true);
          await updateAvailableDayTimeSettings(
            availableDayDocId: id,
            startTimeHhMm: _fmt(_start),
            closingTimeHhMm: _fmt(_end),
            appointmentDurationMinutes: dur,
          );
        }

        // Regenerate freed `available` placeholders so all apps match the new grid immediately.
        await regenerateAvailableSlotsForDoctorLocalDay(
          doctorUserId: _doctorUserId,
          dayLocal: _dateLocal,
          startTimeHhMm: _fmt(_start),
          closingTimeHhMm: _fmt(_end),
          durationMinutes: dur,
        );

        // Refresh local state immediately (don’t wait for stream rebuild).
        try {
          final fresh = await FirebaseFirestore.instance
              .collection(AvailableDayFields.collection)
              .doc(id)
              .get(const GetOptions(source: Source.server));
          _dayRow = fresh.data();
          _applyRowSnapshot();
        } catch (_) {}
        notifyListeners();
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
  _slotDocsByHhMmForToggle(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final m = <String, (String?, String, String, Map<String, dynamic>)>{};
    for (final d in docs) {
      final data = d.data();
      final k = normalizeAppointmentTimeToHhMm(data[AppointmentFields.time]);
      if (k.isEmpty) continue;
      final st = (data[AppointmentFields.status] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      final blocks = appointmentDocBlocksSlotForNewPatientBooking(data);
      final prev = m[k];
      if (prev != null) {
        final prevBlocks = appointmentDocBlocksSlotForNewPatientBooking(prev.$4);
        final prevSt = prev.$3.toLowerCase();

        // Always prefer the blocking/real booking for display/sync.
        if (prevBlocks && !blocks) continue;
        if (!prevBlocks && blocks) {
          // replace with booking
        } else {
          // Both are non-blocking: prefer the existing available placeholder as the toggle target.
          if (prevSt == 'available' && st != 'available') continue;
          if (prevSt != 'available' && st == 'available') {
            // replace with available placeholder
          }
        }
      }
      final n = (data[AppointmentFields.patientName] ?? '').toString().trim();
      final nameOrNull = n.isEmpty ? null : n;
      m[k] = (nameOrNull, d.id, st, data);
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
      await archiveRejectedAppointmentAndFreeSlot(
        appointmentRef: ref,
        priorData: priorData,
        cancellationReason: kAppointmentCancellationReasonSecretary,
      );
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
    final slotPast = !slotStart.isAfter(DateTime.now());
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _ScheduleAvailableSlotSheet(
          loc: loc,
          doctorUserId: _doctorUserId,
          dateLocal: _dateLocal,
          slotStart: slotStart,
          slotNotBookable: _isPast || slotPast,
          formatScheduleDayEn: _formatScheduleDayEn,
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
    required bool isPassed,
    required bool isSlotAvailable,
    required ValueChanged<bool> onToggleAvailable,
    required String? patientName,
    required VoidCallback onTap,
  }) {
    final timeEn = DateFormat.jm('en_US').format(slotStart);
    final rawName = (patientName ?? '').trim();
    final hasName = rawName.isNotEmpty;
    final displayName = hasName ? rawName : 'ناونەنراو';

    final booked = isBooked || hasName;

    // Original clean style: dark card + yellow divider line.
    const baseBg = Color(0xFF1E293B);
    const closedSurface = Color(0xFF0F172A);
    const dividerGold = Color(0xFFFFD54F);

    final canToggleClose = !booked && !isPassed;
    final rowOpacity = isPassed ? 0.5 : ((!booked && !isSlotAvailable) ? 0.62 : 1.0);

    return Opacity(
      opacity: rowOpacity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        color: !booked && !isSlotAvailable ? closedSurface : baseBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (booked)
                  const SizedBox(
                    width: 3,
                    child: ColoredBox(color: dividerGold),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 8,
                      top: 4,
                      bottom: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: 4,
                          child: Directionality(
                            textDirection: ui.TextDirection.ltr,
                            child: Text(
                              timeEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                height: 1.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 7,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (booked) ...[
                                const Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  booked
                                      ? displayName
                                      : (isPassed
                                            ? loc.translate('schedule_slot_passed_ku')
                                            : (isSlotAvailable
                                                  ? loc.translate('schedule_slot_available_ku')
                                                  : loc.translate('schedule_slot_closed_ku'))),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight:
                                        booked ? FontWeight.w900 : FontWeight.w800,
                                    fontSize: 14,
                                    height: 1.0,
                                    color: booked
                                        ? dividerGold
                                        : Colors.white.withValues(alpha: 0.72),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (canToggleClose)
                          IconButton(
                            tooltip: isSlotAvailable
                                ? loc.translate('schedule_slot_close_confirm_title')
                                : loc.translate('schedule_slot_closed_ku'),
                            onPressed: () => onToggleAvailable(!isSlotAvailable),
                            icon: Icon(
                              isSlotAvailable ? Icons.lock_open_rounded : Icons.lock_rounded,
                              size: 18,
                              color: isSlotAvailable
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : const Color(0xFFFCA5A5),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    final now = DateTime.now();
    final todayOnly = _dateOnly(now);
    final slotDay = _dateOnly(slot);
    final isToday = slotDay.year == todayOnly.year &&
        slotDay.month == todayOnly.month &&
        slotDay.day == todayOnly.day;
    final isPassed = isToday && !slot.isAfter(now);

    final k = formatTimeHhMm(slot);
    final booking = byKey[k];
    final patientName = booking?.$1;
    // Booked UI only when a real patient is attached (closed/available placeholders are not “booked”).
    final hasPatient = (patientName ?? '').toString().trim().isNotEmpty;
    final isBooked = hasPatient;
    final slotAvailable = booking == null ||
        (booking.$4[AppointmentFields.isAvailable] != false);
    final showCancel = booking != null &&
        !_isPast &&
        !appointmentStatusIsTerminalForStaffSort(booking.$3);
    return _slotRowTile(
      context: context,
      loc: loc,
      slotStart: slot,
      isBooked: isBooked,
      isPassed: isPassed,
      isSlotAvailable: slotAvailable,
      onToggleAvailable: (v) async {
        if (_isPast) return;
        if (isBooked) return;
        if (isPassed) return;
        if (!v) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (dctx) {
              return AlertDialog(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: kStaffLuxGold.withValues(alpha: 0.35),
                  ),
                ),
                title: Text(
                  loc.translate('schedule_slot_close_confirm_title'),
                  style: const TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8EEF4),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dctx, false),
                    child: Text(
                      loc.translate('action_cancel'),
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB0BEC5),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dctx, true),
                    child: Text(
                      loc.translate('ok'),
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE57373),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
          if (ok != true) return;
        }

        final timeKey = formatTimeHhMm(slot);
        final existing = booking;
        try {
          if (existing != null) {
            await FirebaseFirestore.instance
                .collection(AppointmentFields.collection)
                .doc(existing.$2)
                .set(
              {AppointmentFields.isAvailable: v},
              SetOptions(merge: true),
            );
          } else {
            await FirebaseFirestore.instance
                .collection(AppointmentFields.collection)
                .add({
              AppointmentFields.doctorId: _doctorUserId,
              AppointmentFields.date: Timestamp.fromDate(_dateOnly(_dateLocal)),
              AppointmentFields.time: timeKey,
              AppointmentFields.status: 'available',
              AppointmentFields.isBooked: false,
              AppointmentFields.isAvailable: v,
              AppointmentFields.createdAt: FieldValue.serverTimestamp(),
              AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {}
      },
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
          if (isPassed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  loc.translate('schedule_slot_passed_ku'),
                  style: const TextStyle(fontFamily: kPatientPrimaryFont),
                ),
              ),
            );
            return;
          }
          if (!slotAvailable) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  loc.translate('schedule_slot_closed_ku'),
                  style: const TextStyle(fontFamily: kPatientPrimaryFont),
                ),
              ),
            );
            return;
          }
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
        final byKey = _slotDocsByHhMmForToggle(docs);

        return StreamBuilder<DateTime>(
          stream: scheduleClockStream(),
          initialData: DateTime.now(),
          builder: (context, _) {
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
      },
    );
  }

  Widget _durationMinutesField(AppLocalizations loc, bool enabled) {
    const deepNavy = Color(0xFF0F172A);
    const border = Color(0xFF1565C0);
    final controller = (_durationController ??= TextEditingController(text: '15'));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.translate('schedule_duration_minutes_field_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                filled: true,
                fillColor: deepNavy.withValues(alpha: enabled ? 0.52 : 0.26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: border.withValues(alpha: enabled ? 0.55 : 0.25),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: border.withValues(alpha: 0.42),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: border,
                    width: 1.5,
                  ),
                ),
                suffixText: loc.translate('schedule_minutes_suffix'),
                suffixStyle: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              onChanged: (v) {
                final n = int.tryParse(v.trim());
                if (n != null) _durationMin = n.clamp(1, 24 * 60);
                notifyListeners();
              },
            ),
          ],
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
              SingleChildScrollView(
                child: Column(
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
                  _durationMinutesField(loc, enabled),
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

String _normalizedScheduleBookingRole(Map<String, dynamic>? data) {
  final raw = (data?['role'] ?? '').toString().trim().toLowerCase();
  if (raw.isEmpty || raw == 'user' || raw == 'patient') return 'patient';
  return raw;
}

class _ScheduleAvailableSlotSheet extends StatefulWidget {
  const _ScheduleAvailableSlotSheet({
    required this.loc,
    required this.doctorUserId,
    required this.dateLocal,
    required this.slotStart,
    required this.slotNotBookable,
    required this.formatScheduleDayEn,
  });

  final AppLocalizations loc;
  final String doctorUserId;
  final DateTime dateLocal;
  final DateTime slotStart;
  final bool slotNotBookable;
  final String Function(DateTime d) formatScheduleDayEn;

  @override
  State<_ScheduleAvailableSlotSheet> createState() =>
      _ScheduleAvailableSlotSheetState();
}

class _ScheduleAvailableSlotSheetState extends State<_ScheduleAvailableSlotSheet> {
  bool _loadingRole = true;
  bool _booking = false;
  /// `patient` | staff role key | `anonymous` when not signed in.
  String _roleNorm = 'patient';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      if (mounted) {
        setState(() {
          _loadingRole = false;
          _roleNorm = 'anonymous';
        });
      }
      return;
    }
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      final r = _normalizedScheduleBookingRole(snap.data());
      if (mounted) {
        setState(() {
          _loadingRole = false;
          _roleNorm = r;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingRole = false;
          _roleNorm = 'patient';
        });
      }
    }
  }

  bool get _isPatient => _roleNorm == 'patient';

  Future<void> _confirmBook(BuildContext sheetContext) async {
    setState(() => _booking = true);
    final m = widget.slotStart.hour * 60 + widget.slotStart.minute;
    final err = await bookPatientAppointmentAtScheduleSlot(
      doctorId: widget.doctorUserId,
      dateLocal: widget.dateLocal,
      slotStartMinutes: m,
    );
    if (!mounted) return;
    setState(() => _booking = false);
    if (!sheetContext.mounted) return;
    if (err == null) {
      Navigator.pop(sheetContext);
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text(
            widget.loc.translate('master_calendar_saved'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      SnackBar(
        content: Text(
          widget.loc.translate(err),
          style: const TextStyle(fontFamily: kPatientPrimaryFont),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
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
                  DateFormat.jm('en_US').format(widget.slotStart),
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
                widget.formatScheduleDayEn(widget.dateLocal),
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
              const SizedBox(height: 16),
              if (_loadingRole)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: kStaffLuxGold,
                      ),
                    ),
                  ),
                )
              else if (_roleNorm == 'anonymous')
                Text(
                  loc.translate('login_required'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                )
              else if (!_isPatient)
                Text(
                  loc.translate('schedule_booking_staff_only'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                )
              else if (widget.slotNotBookable)
                Text(
                  loc.translate('schedule_booking_past_slot'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                )
              else
                FilledButton(
                  onPressed: _booking ? null : () => _confirmBook(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kSchedOpenFill.withValues(alpha: 0.92),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _booking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F172A),
                          ),
                        )
                      : Text(
                          loc.translate('confirm_booking'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
