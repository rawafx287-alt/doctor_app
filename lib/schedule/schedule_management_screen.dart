import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../firestore/appointment_queries.dart';
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
/// No [available_days] doc — neutral grey cell.
const LinearGradient _kScheduleCalendarNoDocGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF64748B),
    Color(0xFF475569),
    Color(0xFF334155),
  ],
  stops: [0.0, 0.5, 1.0],
);
/// [available_days] exists but clinic explicitly closed — dark red “out of service”.
const LinearGradient _kScheduleCalendarClosedClinicGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF7F1D1D),
    Color(0xFF991B1B),
    Color(0xFF450A0A),
  ],
  stops: [0.0, 0.45, 1.0],
);
const double _kDayBoxR = 10.0;
/// Space between time-settings card and pinned calendar.
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

String _scheduleEasternArabicDigits(String s) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final unit in s.runes) {
    final ch = String.fromCharCode(unit);
    final i = western.indexOf(ch);
    b.write(i >= 0 ? eastern[i] : ch);
  }
  return b.toString();
}

/// Day / month only (e.g. ٩ / ٤) for the reveal button label.
(String, String) _scheduleSlotsRevealDayMonth(DateTime d) {
  final day = _scheduleEasternArabicDigits('${d.day}');
  final month = _scheduleEasternArabicDigits('${d.month}');
  return (day, month);
}

/// Floating card + gradient rim; [Localizations.override] enforces Western numerals on the wheel.
Widget _schedSheetFloatingTimePickerCard({
  required BuildContext context,
  required String label,
  required TimeOfDay value,
  required ValueChanged<TimeOfDay> onChanged,
  required bool enabled,
}) {
  const pickerH = 120.0;
  final picker = AbsorbPointer(
    absorbing: !enabled,
    child: Opacity(
      opacity: enabled ? 1.0 : 0.42,
      child: Localizations.override(
        context: context,
        locale: const Locale('en', 'US'),
        child: CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.dark,
            applyThemeToAll: true,
          ),
          child: SizedBox(
            height: pickerH,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime:
                  DateTime(2020, 1, 1, value.hour, value.minute),
              onDateTimeChanged: (DateTime dt) {
                onChanged(TimeOfDay(hour: dt.hour, minute: dt.minute));
              },
            ),
          ),
        ),
      ),
    ),
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          height: 1.2,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
      const SizedBox(height: 6),
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(1.3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF22D3EE).withValues(alpha: 0.95),
                const Color(0xFF6366F1).withValues(alpha: 0.92),
                kStaffLuxGold.withValues(alpha: 0.75),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.5),
            child: ColoredBox(
              color: const Color(0xFF0B1220).withValues(alpha: 0.96),
              child: picker,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Quick duration presets (Western numerals).
Widget _schedDurationQuickChips({
  required bool enabled,
  required int currentMinutes,
  required ValueChanged<int> onSelect,
}) {
  const presets = [15, 30, 45, 60];
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: 7,
    runSpacing: 7,
    children: [
      for (final m in presets)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onSelect(m) : null,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: currentMinutes == m
                    ? const Color(0xFF0891B2).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                  color: currentMinutes == m
                      ? const Color(0xFF22D3EE).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.28),
                  width: currentMinutes == m ? 1.4 : 1,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Text(
                    '$m min',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: Colors.white.withValues(
                        alpha: enabled ? 0.95 : 0.38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Time settings sheet — transparent fill, white outline (luxury minimal).
Widget _schedSettingsGradientCancelButton({
  required String label,
  required VoidCallback onPressed,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.transparent,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.52),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.94),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Time settings sheet save — deep blue → cyan.
Widget _schedPremiumBluePurpleSaveButton({
  required String label,
  required bool isLoading,
  required VoidCallback? onPressed,
}) {
  const c1 = Color(0xFF0A1628);
  const c2 = Color(0xFF0E7490);
  const c3 = Color(0xFF22D3EE);
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [c1, c2, c3],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 0.85,
          ),
          boxShadow: [
            BoxShadow(
              color: c3.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

/// Fixed glass header: list title, calendar date, total booked count (modal only).
class _ScheduleSlotsModalFixedHeader extends StatelessWidget {
  const _ScheduleSlotsModalFixedHeader({
    required this.loc,
    required this.dayDigits,
    required this.monthDigits,
    required this.bookedCount,
  });

  final AppLocalizations loc;
  final String dayDigits;
  final String monthDigits;
  final int bookedCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: kStaffLuxGold.withValues(alpha: 0.26),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc.translate('schedule_today_focus_tab_list'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.2,
                      letterSpacing: 0.2,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      '$dayDigits / $monthDigits',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1.1,
                        letterSpacing: 0.5,
                        color: Colors.white.withValues(alpha: 0.96),
                        shadows: [
                          Shadow(
                            color: kStaffLuxGold.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.groups_2_rounded,
                        size: 22,
                        color: kStaffLuxGold.withValues(alpha: 0.88),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          loc.translate(
                            'schedule_slots_total_patients_bar',
                            params: {'count': '$bookedCount'},
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.25,
                            color: Colors.white.withValues(alpha: 0.9),
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
  }
}

/// Time-slot list for the selected calendar day; opens in a themed modal sheet.
void showScheduleSlotsModalBottomSheet({
  required BuildContext context,
  required ScheduleDayPanelController panel,
  required DateTime dayLocal,
  required AppLocalizations loc,
}) {
  final d0 = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  panel.prepareSlotsModalScroll();
  final mediaH = MediaQuery.sizeOf(context).height;
  final sheetH = mediaH * 0.76;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    barrierColor: Colors.transparent,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SizedBox(
        height: mediaH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.48),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: sheetH,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22.0),
                  ),
                  child: Material(
                    color: const Color(0xFF0F172A),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: kStaffLuxGold.withValues(alpha: 0.38),
                          width: 1.0,
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10.0),
                            Center(
                              child: Container(
                                width: 40.0,
                                height: 4.0,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ScheduleDayPanelScope(
                                notifier: panel,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                  ),
                                  child: panel.buildSelectedDaySlotsListBody(
                                    ctx,
                                    loc,
                                    dayLocal: d0,
                                    forModalSheet: true,
                                  ),
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
            ),
          ],
        ),
      );
    },
  );
}

class _ScheduleModernConfirmDialog extends StatelessWidget {
  const _ScheduleModernConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.confirmColor,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const r = 24.0;
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.87),
                    borderRadius: BorderRadius.circular(r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: confirmColor.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              size: 30,
                              color: confirmColor.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  minimumSize: const Size(0, 42),
                                  foregroundColor:
                                      Colors.white.withValues(alpha: 0.85),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    width: 1,
                                  ),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.04),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  cancelText,
                                  style: const TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: FilledButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  minimumSize: const Size(0, 42),
                                  backgroundColor:
                                      confirmColor.withValues(alpha: 0.92),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  confirmText,
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
          ),
        ),
      ),
    );
  }
}

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

/// Western digits for phone / numeric display (English numerals in UI).
String _scheduleWesternDigits(String input) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final sb = StringBuffer();
  for (final r in input.runes) {
    final ch = String.fromCharCode(r);
    final ai = arabicIndic.indexOf(ch);
    if (ai >= 0) {
      sb.write('$ai');
      continue;
    }
    final pi = persian.indexOf(ch);
    if (pi >= 0) {
      sb.write('$pi');
      continue;
    }
    sb.write(ch);
  }
  return sb.toString();
}

Widget _schedulePatientDialogTimeBadge(String timeEn) {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF141A22).withValues(alpha: 0.92),
      border: Border.all(
        color: kStaffLuxGold.withValues(alpha: 0.28),
        width: 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Text(
          timeEn,
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.25,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    ),
  );
}

Widget _schedulePatientDialogAvatar(String patientName) {
  final t = patientName.trim();
  final Widget inner = t.isEmpty
      ? Icon(
          Icons.person_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.92),
        )
      : Text(
          String.fromCharCode(t.runes.first),
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w900,
            fontSize: 32,
            height: 1,
            color: Colors.white.withValues(alpha: 0.98),
          ),
        );

  return Container(
    width: 88,
    height: 88,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF252B35),
      border: Border.all(
        color: kStaffLuxGold.withValues(alpha: 0.42),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: inner,
  );
}

/// Muted gold for patient dialog icons + field labels (no per-field neon).
Color _schedulePatientDialogMutedGold({double a = 0.62}) =>
    kStaffLuxGold.withValues(alpha: a);

Widget _schedulePatientInfoGlassCard({
  required IconData icon,
  required String label,
  required String value,
  required bool valueLtr,
  required TextStyle valueStyle,
}) {
  final iconTint = _schedulePatientDialogMutedGold(a: 0.78);
  final labelColor = _schedulePatientDialogMutedGold(a: 0.55);

  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white.withValues(alpha: 0.045),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A222C).withValues(alpha: 0.95),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: iconTint),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.25,
                    letterSpacing: 0.25,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection:
                      valueLtr ? ui.TextDirection.ltr : ui.TextDirection.rtl,
                  child: Text(
                    value,
                    style: valueStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool?> _showScheduleCloseDayWarningDialog(
  BuildContext context,
  AppLocalizations loc,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
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
          loc.translate('schedule_close_day_confirm_warning'),
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

  // Removed the pulse animation to keep day selection logic stable/simple.

  @override
  void initState() {
    super.initState();
    _selectedDay = null;
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
    // Avoid "setState() called during build" when taps occur while rebuilding.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedDay = d0;
      });
    });
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
    final pillW = (maxWidth * 0.58).clamp(18.0, 34.0).toDouble();

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
    final hasDayDoc = row != null;
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
    } else if (hasDayDoc && !open) {
      flatFill = null;
      crystalGrad = _kScheduleCalendarClosedClinicGradient;
      textColor = Colors.white.withValues(alpha: 0.96);
    } else {
      flatFill = null;
      crystalGrad = _kScheduleCalendarNoDocGradient;
      textColor = Colors.white.withValues(alpha: 0.9);
    }

    final radius = BorderRadius.circular(_kDayBoxR);

    final stackChildren = <Widget>[
      if (!isPast)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 0.85,
                ),
              ),
            ),
          ),
        ),
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
              fontSize: (side * 0.36).clamp(14.0, 19.0).toDouble(),
              height: 1,
              color: textColor,
              decoration: strike
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              decorationColor: const Color(0xFF94A3B8),
              decorationThickness: 1.5,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
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
                          ? (hasDayDoc
                              ? const Color(0xFF9B1C1C)
                              : const Color(0xFF475569))
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

    final cell = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: onTap == null ? Colors.transparent : null,
        highlightColor: onTap == null ? Colors.transparent : null,
        child: dayInk(),
      ),
    );

    // Soft outer glow for active (open) clinic days.
    if (!isPast && !closedLook && !isSelected) {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kDayBoxR + 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: -1,
              ),
              BoxShadow(
                color: const Color(0xFF86EFAC).withValues(alpha: 0.32),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: cell,
        ),
      );
    }
    return cell;
  }

  double _scheduleCalendarInnerBodyHeight(double calInnerW) {
    final crossSp = _kGridCrossAxisSpacing;
    final mainSp = _kGridMainAxisSpacing;
    final colW = (calInnerW - 6 * crossSp) / 7;
    final side = colW.clamp(42.0, 54.0).toDouble();
    final dowRowH = _kDowRowHeight;
    final gridH =
        _kScheduleGridRowCount * side +
        (_kScheduleGridRowCount - 1) * mainSp;
    return _kScheduleMonthHeaderH +
        dowRowH +
        _kScheduleDowToGridGap +
        gridH;
  }

  /// Total height of [_scheduleGlassCard] that wraps the month grid (padding + grid).
  double _scheduleGlassCalendarTotalHeight(double cardInnerW) {
    return _kPrimaryCardPadding +
        _scheduleCalendarInnerBodyHeight(cardInnerW) +
        _kCalendarCardBottomPadding;
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
    final side = colW.clamp(42.0, 54.0).toDouble();
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

        Widget scheduleMainColumn() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _kBodyHorizontalPad,
                    4,
                    _kBodyHorizontalPad,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ScheduleSettingsSummaryCard(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final fullW = constraints.maxWidth;
                            if (fullW <= 0) {
                              return const SizedBox.shrink();
                            }
                            final cardInnerW =
                                fullW - 2 * _kPrimaryCardPadding;
                            final stackH =
                                _scheduleGlassCalendarTotalHeight(cardInnerW);
                            return Align(
                              alignment: Alignment.topCenter,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: fullW,
                                  height: stackH,
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
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _kBodyHorizontalPad,
                    12,
                    _kBodyHorizontalPad,
                    bottomReserve,
                  ),
                  child: Center(
                    child: _ScheduleBottomSlotsSection(
                      userSelectedDay: _selectedDay,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return _ScheduleDayPanelHost(
          key: ValueKey<String>(docId),
          doctorUserId: uid,
          dateLocal: sel,
          existingDocId: docId,
          dayRow: dayRow,
          child: Builder(
            builder: (innerCtx) {
              if (widget.embedded) {
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Container(
                    decoration: kDoctorPremiumGradientDecoration,
                    child: scheduleMainColumn(),
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
                    SafeArea(child: scheduleMainColumn()),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Shared day panel state: time settings (summary card → glass sheet) + slot list modal.
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
  ScrollController? _modalSlotsScrollController;
  bool _didAutoScrollModalSlots = false;

  /// Call when opening the appointment list modal so auto-scroll runs each time.
  void prepareSlotsModalScroll() {
    _didAutoScrollModalSlots = false;
  }

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
    _didAutoScrollModalSlots = false;
    _applyRowSnapshot();
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
  /// Hides the save-button spinner after [Duration(seconds: 2)] while work continues.
  Timer? _saveUiSlowHintTimer;
  bool _saveHideButtonSpinner = false;
  String? _pendingSavedStartHhMm;
  String? _pendingSavedEndHhMm;
  int? _pendingSavedDurationMin;

  /// Baseline when [openTimeSettingsSheet] opens — restored if the sheet is
  /// dismissed without a successful save (Cancel, X, barrier tap, back).
  bool _timeSettingsSheetSnapshotCaptured = false;
  late bool _snapIsOpen;
  late TimeOfDay _snapStart;
  late TimeOfDay _snapEnd;
  late int _snapDurationMin;
  String _snapDurationText = '';

  void _captureTimeSettingsSheetSnapshot() {
    _snapIsOpen = _isOpen;
    _snapStart = _start;
    _snapEnd = _end;
    _snapDurationMin = _durationMin;
    _snapDurationText =
        (_durationController?.text ?? '').trim().isEmpty
            ? '$_durationMin'
            : _durationController!.text.trim();
    _timeSettingsSheetSnapshotCaptured = true;
  }

  void _restoreTimeSettingsSheetSnapshot() {
    if (!_timeSettingsSheetSnapshotCaptured) return;
    _isOpen = _snapIsOpen;
    _start = _snapStart;
    _end = _snapEnd;
    _durationMin = _snapDurationMin;
    _durationController?.text = _snapDurationText;
    notifyListeners();
  }

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

  @override
  void dispose() {
    _saveUiSlowHintTimer?.cancel();
    _modalSlotsScrollController?.dispose();
    _durationController?.dispose();
    super.dispose();
  }

  void _armSaveUiSlowHintTimer(BuildContext context, AppLocalizations s) {
    _saveUiSlowHintTimer?.cancel();
    _saveHideButtonSpinner = false;
    _saveUiSlowHintTimer = Timer(const Duration(seconds: 2), () {
      if (!_saving) return;
      _saveHideButtonSpinner = true;
      notifyListeners();
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            s.translate('schedule_save_timeout'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    });
  }

  void _disarmSaveUiSlowHintTimer() {
    _saveUiSlowHintTimer?.cancel();
    _saveUiSlowHintTimer = null;
    _saveHideButtonSpinner = false;
  }

  /// Slot grid sync is slow (many appointment docs); never block sheet dismissal.
  void _deferPostSaveSlotGridSync({
    required String startHhMm,
    required String closingHhMm,
    required int durationMinutes,
    required String availableDayDocId,
  }) {
    unawaited(() async {
      try {
        await regenerateAvailableSlotsForDoctorLocalDay(
          doctorUserId: _doctorUserId,
          dayLocal: _dateLocal,
          startTimeHhMm: startHhMm,
          closingTimeHhMm: closingHhMm,
          durationMinutes: durationMinutes,
        );
      } catch (_) {
        return;
      }
      try {
        final fresh = await FirebaseFirestore.instance
            .collection(AvailableDayFields.collection)
            .doc(availableDayDocId)
            .get(const GetOptions(source: Source.server));
        _dayRow = fresh.data();
        _applyRowSnapshot();
      } catch (_) {}
      notifyListeners();
    }());
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

  /// Summary strip + sheet (read-only for UI).
  TimeOfDay get scheduleSummaryStart => _start;
  TimeOfDay get scheduleSummaryEnd => _end;
  int get scheduleSummaryDurationMin => _durationMin;
  bool get scheduleSummaryClinicOpen => _isOpen;
  bool get scheduleDayIsPast => _isPast;

  Future<void> _refreshDayRowFromServer() async {
    try {
      final fresh = await FirebaseFirestore.instance
          .collection(AvailableDayFields.collection)
          .doc(_existingDocId)
          .get(const GetOptions(source: Source.server));
      _dayRow = fresh.data();
    } catch (_) {}
  }

  /// Bulk-cancel active appointments, close [available_days], refresh local row, success snack.
  /// Used from [_save] after the doctor confirms in the warning dialog.
  Future<void> _executeCloseClinicDayAfterConfirm(
    BuildContext context,
    AppLocalizations s,
  ) async {
    final activeCount = await countActiveAppointmentsForDoctorLocalDay(
      doctorUserId: _doctorUserId,
      dayLocal: _dateLocal,
    );
    if (activeCount > 0) {
      await bulkCancelActiveAppointmentsForDoctorLocalDay(
        doctorUserId: _doctorUserId,
        dayLocal: _dateLocal,
        cancellationReason: kAppointmentCancellationReasonClinicClosed,
      );
    }
    await setAvailableDayOpenState(
      availableDayDocId: _existingDocId,
      isOpen: false,
    );
    await _refreshDayRowFromServer();
    _applyRowSnapshot();
    _isOpen = false;
    notifyListeners();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('schedule_close_day_success_snack'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    }
  }

  /// Persists schedule + clinic open state. Returns whether the save completed
  /// successfully (caller may close the sheet only when `true`).
  ///
  /// Slot regeneration runs in the background so the UI is not blocked; the save
  /// button spinner is capped at ~2s with [schedule_save_timeout] if work runs long.
  Future<bool> _save(BuildContext context) async {
    if (_isPast) return false;
    final s = S.of(context);

    final id = _existingDocId;
    final hasDoc = _dayRow != null;
    final wasOpen = hasDoc && availableDayIsOpen(_dayRow!);

    final raw = (_durationController?.text ?? '').trim();
    final durEffective = int.tryParse(raw);
    if (_isOpen && (durEffective == null || durEffective <= 0)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('schedule_custom_duration_required'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
      return false;
    }
    final dur = (durEffective ?? 15).clamp(1, 24 * 60);
    _markPendingSavedValues(
      startHhMm: _fmt(_start),
      endHhMm: _fmt(_end),
      durationMin: dur,
    );

    if (!_isOpen && hasDoc && wasOpen) {
      if (!context.mounted) return false;
      final proceed =
          await _showScheduleCloseDayWarningDialog(context, s);
      if (!context.mounted) return false;
      if (proceed != true) return false;
    }

    _armSaveUiSlowHintTimer(context, s);
    _saving = true;
    notifyListeners();
    await Future<void>.value();

    var suppressDefaultSaveSnack = false;
    try {
      if (!_isOpen) {
        if (hasDoc) {
          if (wasOpen) {
            try {
              if (!context.mounted) return false;
              await _executeCloseClinicDayAfterConfirm(context, s);
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
              return false;
            }
            suppressDefaultSaveSnack = true;
          } else {
            await setAvailableDayOpenState(availableDayDocId: id, isOpen: false);
            await _refreshDayRowFromServer();
            _applyRowSnapshot();
            notifyListeners();
          }
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
          if (!wasOpen) {
            await resetClinicClosedCancelledAppointmentSlotsForDay(
              doctorUserId: _doctorUserId,
              dayLocal: _dateLocal,
            );
          }
          await setAvailableDayOpenState(availableDayDocId: id, isOpen: true);
          await updateAvailableDayTimeSettings(
            availableDayDocId: id,
            startTimeHhMm: _fmt(_start),
            closingTimeHhMm: _fmt(_end),
            appointmentDurationMinutes: dur,
          );
        }
        notifyListeners();
        _deferPostSaveSlotGridSync(
          startHhMm: _fmt(_start),
          closingHhMm: _fmt(_end),
          durationMinutes: dur,
          availableDayDocId: id,
        );
      }
      if (context.mounted && !suppressDefaultSaveSnack) {
        showScheduleSaveSuccessSnackBar(
          context,
          s.translate('schedule_save_ok'),
        );
      }
      return true;
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
      return false;
    } finally {
      _disarmSaveUiSlowHintTimer();
      if (context.mounted) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  /// Glass time-settings modal (opened from the summary card).
  void openTimeSettingsSheet(BuildContext context) {
    _captureTimeSettingsSheetSnapshot();
    final loc = S.of(context);
    final rootMedia = MediaQuery.of(context);
    var dismissedWithSuccessfulSave = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (sheetCtx) {
        final sheetH = rootMedia.size.height * 0.88;
        return SizedBox(
          height: rootMedia.size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_saving) return;
                    Navigator.of(sheetCtx).pop();
                  },
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.56),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  child: SizedBox(
                    height: sheetH,
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0E1628).withValues(alpha: 0.97),
                              const Color(0xFF080F1A).withValues(alpha: 0.99),
                            ],
                          ),
                          border: Border.all(
                            color: kStaffLuxGold.withValues(alpha: 0.32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 36,
                              offset: const Offset(0, -12),
                            ),
                          ],
                        ),
                        child: ListenableBuilder(
                          listenable: this,
                          builder: (context, _) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 6),
                                    Center(
                                      child: Container(
                                        width: 40,
                                        height: 3.5,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF94A3B8)
                                              .withValues(alpha: 0.5),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 0),
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 44,
                                    ),
                                    child: Text(
                                      loc.translate(
                                          'schedule_sheet_tab_settings'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        height: 1.25,
                                        color: Colors.white
                                            .withValues(alpha: 0.96),
                                      ),
                                    ),
                                  ),
                                  PositionedDirectional(
                                    end: -10,
                                    top: -6,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white
                                            .withValues(alpha: 0.88),
                                      ),
                                      onPressed: _saving
                                          ? null
                                          : () {
                                              Navigator.of(sheetCtx).pop();
                                            },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Center(
                                child:
                                    _scheduleSelectedDateBadge(_dateLocal)),
                            const SizedBox(height: 4),
                            Expanded(
                              child: ListenableBuilder(
                                listenable: this,
                                builder: (context, _) {
                                  final enabled = !_isPast && !_saving;
                                  final compact =
                                      MediaQuery.sizeOf(sheetCtx).width < 440;
                                  _durationController ??=
                                      TextEditingController(
                                    text: '${_durationMin.clamp(5, 60)}',
                                  );
                                  final durForSlider =
                                      _durationMin.clamp(5, 60);
                                  final sliderVal = durForSlider.toDouble();

                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      8,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            color: Colors.white
                                                .withValues(alpha: 0.07),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.16),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.22),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.local_hospital_rounded,
                                                  size: compact ? 18 : 20,
                                                  color: kStaffLuxGold
                                                      .withValues(alpha: 0.88),
                                                ),
                                                const SizedBox(width: 10),
                                                Flexible(
                                                  child: Text(
                                                    loc.translate(
                                                        'schedule_clinic_status_title'),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          kPatientPrimaryFont,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                      height: 1.2,
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.92),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                CupertinoSwitch(
                                                  value: _isOpen,
                                                  onChanged: enabled
                                                      ? (v) {
                                                          _isOpen = v;
                                                          notifyListeners();
                                                        }
                                                      : null,
                                                  activeTrackColor:
                                                      _kSchedOpenFill,
                                                  inactiveTrackColor:
                                                      _kSchedClosedFill
                                                          .withValues(
                                                              alpha: 0.55),
                                                  thumbColor:
                                                      CupertinoColors.white,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (compact)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _schedSheetFloatingTimePickerCard(
                                                context: sheetCtx,
                                                label: loc.translate(
                                                    'schedule_control_start_time_label'),
                                                value: _start,
                                                enabled: enabled,
                                                onChanged: (t) {
                                                  _start = t;
                                                  notifyListeners();
                                                },
                                              ),
                                              const SizedBox(height: 6),
                                              _schedSheetFloatingTimePickerCard(
                                                context: sheetCtx,
                                                label: loc.translate(
                                                    'schedule_control_end_time_label'),
                                                value: _end,
                                                enabled: enabled,
                                                onChanged: (t) {
                                                  _end = t;
                                                  notifyListeners();
                                                },
                                              ),
                                            ],
                                          )
                                        else
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child:
                                                    _schedSheetFloatingTimePickerCard(
                                                  context: sheetCtx,
                                                  label: loc.translate(
                                                      'schedule_control_start_time_label'),
                                                  value: _start,
                                                  enabled: enabled,
                                                  onChanged: (t) {
                                                    _start = t;
                                                    notifyListeners();
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child:
                                                    _schedSheetFloatingTimePickerCard(
                                                  context: sheetCtx,
                                                  label: loc.translate(
                                                      'schedule_control_end_time_label'),
                                                  value: _end,
                                                  enabled: enabled,
                                                  onChanged: (t) {
                                                    _end = t;
                                                    notifyListeners();
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 8),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            color: Colors.white
                                                .withValues(alpha: 0.06),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.14),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.2),
                                                blurRadius: 14,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              14,
                                              12,
                                              14,
                                              14,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  loc.translate(
                                                      'schedule_duration_minutes_field_title'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        kPatientPrimaryFont,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12.5,
                                                    height: 1.2,
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.88),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Directionality(
                                                  textDirection:
                                                      ui.TextDirection.ltr,
                                                  child: Text(
                                                    '$durForSlider min',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          kPatientPrimaryFont,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 22,
                                                      height: 1.1,
                                                      color: const Color(
                                                              0xFF22D3EE)
                                                          .withValues(
                                                              alpha: 0.95),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                SliderTheme(
                                                  data: SliderTheme.of(context)
                                                      .copyWith(
                                                    trackHeight: 8,
                                                    thumbShape:
                                                        const RoundSliderThumbShape(
                                                      enabledThumbRadius: 14,
                                                    ),
                                                    overlayShape:
                                                        const RoundSliderOverlayShape(
                                                      overlayRadius: 26,
                                                    ),
                                                    activeTrackColor:
                                                        const Color(0xFF06B6D4),
                                                    inactiveTrackColor: Colors
                                                        .white
                                                        .withValues(
                                                            alpha: 0.14),
                                                    thumbColor: Colors.white,
                                                    overlayColor:
                                                        const Color(0xFF22D3EE)
                                                            .withValues(
                                                                alpha: 0.22),
                                                  ),
                                                  child: Slider(
                                                    value: sliderVal,
                                                    min: 5,
                                                    max: 60,
                                                    divisions: 11,
                                                    label: '$durForSlider',
                                                    onChanged: enabled
                                                        ? (v) {
                                                            final stepped =
                                                                (v / 5)
                                                                        .round() *
                                                                    5;
                                                            _durationMin = stepped
                                                                .clamp(5, 60);
                                                            _durationController
                                                                ?.text =
                                                                '$_durationMin';
                                                            notifyListeners();
                                                          }
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  loc.translate(
                                                      'schedule_duration_quick_select'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        kPatientPrimaryFont,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10.5,
                                                    letterSpacing: 0.4,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                _schedDurationQuickChips(
                                                  enabled: enabled,
                                                  currentMinutes: durForSlider,
                                                  onSelect: (m) {
                                                    _durationMin = m;
                                                    _durationController?.text =
                                                        '$m';
                                                    notifyListeners();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            SafeArea(
                              top: false,
                              minimum: EdgeInsets.zero,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 6, 16, 10),
                                child: ListenableBuilder(
                                  listenable: this,
                                  builder: (context, _) {
                                    final enabled = !_isPast;
                                    return Row(
                                      children: [
                                        Expanded(
                                          child:
                                              _schedSettingsGradientCancelButton(
                                            label:
                                                loc.translate('action_cancel'),
                                            onPressed: () {
                                              if (_saving) return;
                                              Navigator.of(sheetCtx).pop();
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child:
                                              _schedPremiumBluePurpleSaveButton(
                                            label: loc.translate(
                                                'schedule_save_button'),
                                            isLoading:
                                                _saving && !_saveHideButtonSpinner,
                                            onPressed: (!enabled || _saving)
                                                ? null
                                                : () async {
                                                    final ok =
                                                        await _save(sheetCtx);
                                                    if (sheetCtx.mounted &&
                                                        ok) {
                                                      dismissedWithSuccessfulSave =
                                                          true;
                                                      Navigator.of(sheetCtx)
                                                          .pop();
                                                    }
                                                  },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (_timeSettingsSheetSnapshotCaptured) {
        if (!dismissedWithSuccessfulSave) {
          _restoreTimeSettingsSheetSnapshot();
        }
        _timeSettingsSheetSnapshotCaptured = false;
      }
    });
  }

  Stream<DateTime> _scheduleSlotListClockStream() async* {
    yield DateTime.now();
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      yield DateTime.now();
    }
  }

  Map<String, (String?, String, String, Map<String, dynamic>)>
      _slotDocsByHhMmForList(
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
        if (prevBlocks && !blocks) continue;
        if (!prevBlocks && blocks) {
          // replace with booking
        } else {
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

  /// Active booked slots (name or blocking doc), excluding cancelled.
  int _scheduleBookedPatientsCount(
    List<DateTime> slots,
    Map<String, (String?, String, String, Map<String, dynamic>)> byKey,
  ) {
    var n = 0;
    for (final slotStart in slots) {
      final hhmm = formatTimeHhMm(slotStart);
      final booking = byKey[hhmm];
      if (booking == null) continue;
      final data = booking.$4;
      final statusRaw = booking.$3.toString().trim().toLowerCase();
      if (statusRaw == 'cancelled' || statusRaw == 'canceled') continue;
      final rawName = (booking.$1 ?? '').toString().trim();
      final blocks = appointmentDocBlocksSlotForNewPatientBooking(data);
      final hasName = rawName.isNotEmpty;
      final isBooked = hasName || blocks;
      if (isBooked) n++;
    }
    return n;
  }

  Widget _selectedDaySlotRow(
    BuildContext context,
    AppLocalizations loc, {
    required DateTime slotStart,
    required DateTime now,
    required Map<String, (String?, String, String, Map<String, dynamic>)> byKey,
  }) {
    const Color baseBgAvailable = Color(0xFF1A2330);
    const Color baseBgBooked = Color(0xFF1A2D4A);
    const Color dividerGold = Color(0xFFFFD54F);
    const Color stripeAvailable = Color(0xFF475569);
    const Color stripeBooked = Color(0xFFE6C35C);
    const Color stripeClosed = Color(0xFFEF4444);

    final DateTime slotDay = _dateOnly(slotStart);
    final DateTime todayOnly = _dateOnly(now);
    final bool isToday = slotDay.year == todayOnly.year &&
        slotDay.month == todayOnly.month &&
        slotDay.day == todayOnly.day;
    final bool isPassed = (isToday == true) && !slotStart.isAfter(now);
    final double rowOpacity = (isPassed == true) ? 0.5 : 1.0;

    final String hhmm = formatTimeHhMm(slotStart);
    final booking = byKey[hhmm];
    final data = booking?.$4;
    final docId = booking?.$2;
    final statusRaw = (booking?.$3 ?? '').toString().trim().toLowerCase();
    final rawName = (booking?.$1 ?? '').toString().trim();
    final bool isCancelled =
        statusRaw == 'cancelled' || statusRaw == 'canceled';
    final bool hasName = rawName.isNotEmpty;
    final bool blocks = data == null
        ? false
        : appointmentDocBlocksSlotForNewPatientBooking(data);
    final bool isBooked = (hasName == true) || (blocks == true);
    final bool isAvailDoc =
        data == null ? true : (data[AppointmentFields.isAvailable] != false);
    final bool isManualClosed =
        (isBooked == false) && (isAvailDoc == false);
    final nf = NumberFormat.decimalPattern('en_US');
    final qnRaw = data == null ? null : data[AppointmentFields.queueNumber];
    final qn = parseStoredAppointmentQueueNumber(qnRaw);

    final String timeEn = DateFormat.jm('en_US').format(slotStart);
    final String statusText;
    if (isCancelled) {
      statusText = loc.translate('schedule_slot_cancelled_ku');
    } else if (isBooked == true) {
      statusText = rawName.isNotEmpty ? rawName : 'گیراوە';
    } else if (isManualClosed == true) {
      statusText = loc.translate('schedule_slot_closed_ku');
    } else if (isPassed == true) {
      statusText = loc.translate('schedule_slot_passed_ku');
    } else {
      statusText = loc.translate('schedule_slot_available_ku');
    }

    late final Color stripeColor;
    if (isCancelled) {
      stripeColor = const Color(0xFFB91C1C);
    } else if (isBooked) {
      stripeColor = stripeBooked;
    } else if (isManualClosed) {
      stripeColor = stripeClosed;
    } else if (isPassed) {
      stripeColor = Colors.blueGrey.shade600;
    } else {
      stripeColor = stripeAvailable;
    }

    final nameStyleBooked = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w800,
      fontSize: 14,
      height: 1.15,
      color: dividerGold.withValues(alpha: isPassed ? 0.72 : 0.96),
    );

    final statusStyleAvailable = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w700,
      fontSize: 14,
      height: 1.15,
      color: Colors.white.withValues(alpha: 0.78),
    );

    final canOpenPatientDetail = isBooked &&
        hasName &&
        docId != null &&
        data != null &&
        statusRaw != 'completed' &&
        statusRaw != 'complete' &&
        statusRaw != 'done' &&
        statusRaw != 'cancelled' &&
        statusRaw != 'canceled';

    final bool bookedHighlight =
        isBooked && !isCancelled && !isManualClosed;
    final double stripeW = bookedHighlight ? 6.0 : 3.0;
    final Color cardFill = bookedHighlight
        ? baseBgBooked.withValues(alpha: isPassed ? 0.55 : 0.88)
        : baseBgAvailable.withValues(alpha: isPassed ? 0.42 : 0.92);
    final List<Color>? cardGradientColors = bookedHighlight
        ? [
            const Color(0xFF2A1F0A).withValues(alpha: 0.42),
            baseBgBooked.withValues(alpha: 0.82),
          ]
        : null;

    final card = Opacity(
      opacity: rowOpacity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
        color: Colors.transparent,
        elevation: bookedHighlight ? 6.0 : 2.0,
        shadowColor: bookedHighlight
            ? kStaffLuxGold.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
        child: SizedBox(
          height: 58,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: cardGradientColors != null
                          ? LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: cardGradientColors,
                            )
                          : null,
                      color: cardGradientColors == null ? cardFill : null,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: stripeW,
                      decoration: BoxDecoration(
                        color: stripeColor,
                        boxShadow: bookedHighlight
                            ? [
                                BoxShadow(
                                  color: stripeBooked.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 12.0,
                          end: 12.0,
                          top: 10.0,
                          bottom: 10.0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 78.0,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Directionality(
                                  textDirection: ui.TextDirection.ltr,
                                  child: Text(
                                    timeEn,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.0,
                                      height: 1.15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            if (isBooked == true) ...[
                              Icon(
                                Icons.person_rounded,
                                size: 16.0,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6.0),
                            ],
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  statusText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: (isBooked == true)
                                      ? nameStyleBooked
                                      : statusStyleAvailable,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: Center(
                                child: isBooked && qn != null && qn > 0
                                    ? Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              kStaffLuxGold
                                                  .withValues(alpha: 0.98),
                                              const Color(0xFFFFE082)
                                                  .withValues(alpha: 0.95),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.35),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: kStaffLuxGold.withValues(
                                                alpha: 0.55,
                                              ),
                                              blurRadius: 14,
                                              spreadRadius: 0,
                                            ),
                                            BoxShadow(
                                              color: Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                              blurRadius: 6,
                                              spreadRadius: -1,
                                            ),
                                            BoxShadow(
                                              color: const Color(0xFF0EA5E9)
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Directionality(
                                          textDirection: ui.TextDirection.ltr,
                                          child: Text(
                                            nf.format(qn),
                                            style: const TextStyle(
                                              fontFamily: kPatientPrimaryFont,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12.5,
                                              height: 1,
                                              color: Color(0xFF0D2137),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        isBooked
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        size: isBooked ? 22.0 : 18.0,
                                        color: isBooked
                                            ? kStaffLuxGold.withValues(
                                                alpha: 0.88,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.22,
                                              ),
                                      ),
                              ),
                            ),
                          ],
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
    );

    if (!canOpenPatientDetail) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          showScheduleSlotPatientGlassDialog(
            context: context,
            loc: loc,
            appointmentDocId: docId,
            priorData: Map<String, dynamic>.from(data),
            timeEn: timeEn,
          );
        },
        child: card,
      ),
    );
  }

  /// Slot list for the bottom card (shrink-wrapped) or modal sheet (scrollable).
  Widget buildSelectedDaySlotsListBody(
    BuildContext context,
    AppLocalizations loc, {
    required DateTime dayLocal,
    bool forModalSheet = false,
  }) {
    final d0 = _dateOnly(dayLocal);

    if (!_isOpen) {
      final w = Padding(
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
      if (forModalSheet) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: w,
          ),
        );
      }
      return w;
    }

    final slots = generatedSlotStartsForDay(
      dateOnly: d0,
      startTimeHhMm: _fmt(_start),
      closingTimeHhMm: _fmt(_end),
      durationMinutes: _durationMin,
    );

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: watchDoctorAppointmentsForLocalDay(
        doctorUserId: _doctorUserId,
        dayLocal: d0,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          logFirestoreIndexHelpOnce(
            snap.error,
            tag: 'ScheduleManagementScreen.footer_slots',
            expectedCompositeIndexHint: kAppointmentsDoctorDateStatusIndexHint,
          );
          final err = Text(
            loc.translate('schedule_load_error'),
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: kPatientPrimaryFont,
              fontSize: 11,
            ),
          );
          if (forModalSheet) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: err,
              ),
            );
          }
          return err;
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          const loading = Padding(
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
          if (forModalSheet) return loading;
          return loading;
        }

        if (slots.isEmpty) {
          final empty = Text(
            loc.translate('schedule_timeline_no_slots'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.3,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          );
          if (forModalSheet) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: empty,
              ),
            );
          }
          return empty;
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snap.data ?? [],
        );
        final byKey = _slotDocsByHhMmForList(docs);

        final ScrollController? modalController;
        if (forModalSheet) {
          _modalSlotsScrollController ??= ScrollController();
          modalController = _modalSlotsScrollController;
        } else {
          modalController = null;
        }

        final (dayDig, monthDig) =
            _scheduleSlotsRevealDayMonth(_dateOnly(dayLocal));
        final bookedTotal = _scheduleBookedPatientsCount(slots, byKey);

        return forModalSheet
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ScheduleSlotsModalFixedHeader(
                    loc: loc,
                    dayDigits: dayDig,
                    monthDigits: monthDig,
                    bookedCount: bookedTotal,
                  ),
                  Expanded(
                    child: StreamBuilder<DateTime>(
                      stream: _scheduleSlotListClockStream(),
                      initialData: DateTime.now(),
                      builder: (context, clockSnap) {
                        final DateTime now = clockSnap.data ?? DateTime.now();
                        if (modalController != null &&
                            _didAutoScrollModalSlots == false) {
                          _didAutoScrollModalSlots = true;
                          final c = modalController;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!c.hasClients) return;
                            var targetIndex = 0;
                            for (var i = 0; i < slots.length; i++) {
                              if (!slots[i].isBefore(now)) {
                                targetIndex = i;
                                break;
                              }
                              targetIndex = i;
                            }
                            const listRowExtent = 66.0;
                            final targetOffset = (targetIndex * listRowExtent)
                                .clamp(0.0, c.position.maxScrollExtent);
                            c.jumpTo(targetOffset);
                          });
                        }
                        return ListView.builder(
                          key: const PageStorageKey<String>(
                            'schedule_day_slot_list_v3',
                          ),
                          controller: modalController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: slots.length,
                          itemBuilder: (context, index) {
                            return _selectedDaySlotRow(
                              context,
                              loc,
                              slotStart: slots[index],
                              now: now,
                              byKey: byKey,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              )
            : StreamBuilder<DateTime>(
                stream: _scheduleSlotListClockStream(),
                initialData: DateTime.now(),
                builder: (context, clockSnap) {
                  final DateTime now = clockSnap.data ?? DateTime.now();
                  return ListView.builder(
                    key: const PageStorageKey<String>(
                      'schedule_day_slot_list_embedded',
                    ),
                    controller: modalController,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      return _selectedDaySlotRow(
                        context,
                        loc,
                        slotStart: slots[index],
                        now: now,
                        byKey: byKey,
                      );
                    },
                  );
                },
              );
      },
    );
  }
}

/// Glass patient details + secretary cancel (archive + free slot).
Future<void> showScheduleSlotPatientGlassDialog({
  required BuildContext context,
  required AppLocalizations loc,
  required String appointmentDocId,
  required Map<String, dynamic> priorData,
  required String timeEn,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel:
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _SchedulePatientGlassDialogBody(
        loc: loc,
        appointmentDocId: appointmentDocId,
        priorData: priorData,
        timeEn: timeEn,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SchedulePatientGlassDialogBody extends StatefulWidget {
  const _SchedulePatientGlassDialogBody({
    required this.loc,
    required this.appointmentDocId,
    required this.priorData,
    required this.timeEn,
  });

  final AppLocalizations loc;
  final String appointmentDocId;
  final Map<String, dynamic> priorData;
  final String timeEn;

  @override
  State<_SchedulePatientGlassDialogBody> createState() =>
      _SchedulePatientGlassDialogBodyState();
}

class _SchedulePatientGlassDialogBodyState
    extends State<_SchedulePatientGlassDialogBody> {
  var _cancelling = false;

  Future<void> _onCancelPressed(BuildContext dialogContext) async {
    final ok = await showGeneralDialog<bool>(
      context: dialogContext,
      barrierDismissible: true,
      barrierLabel:
          MaterialLocalizations.of(dialogContext).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return _ScheduleModernConfirmDialog(
          title: widget.loc.translate('schedule_are_you_sure'),
          message: widget.loc.translate('schedule_slot_cancel_confirm_title'),
          confirmText: widget.loc.translate('schedule_slot_cancel_yes'),
          cancelText: widget.loc.translate('schedule_slot_cancel_no'),
          confirmColor: const Color(0xFFB91C1C),
          icon: Icons.warning_amber_rounded,
        );
      },
      transitionBuilder: (ctx, a, s, child) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (ok != true || !dialogContext.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _cancelling = true);
      try {
        await archiveRejectedAppointmentAndFreeSlot(
          appointmentRef: FirebaseFirestore.instance
              .collection(AppointmentFields.collection)
              .doc(widget.appointmentDocId),
          priorData: widget.priorData,
          cancellationReason: kAppointmentCancellationReasonSecretary,
        );
        if (!dialogContext.mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(
                  widget.loc.translate('schedule_slot_cancel_ok_snack'),
                  style: const TextStyle(fontFamily: kPatientPrimaryFont),
                ),
              ),
            );
          }
        });
      } catch (_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _cancelling = false);
          if (dialogContext.mounted) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(
                  widget.loc.translate('schedule_slot_cancel_error_snack'),
                  style: const TextStyle(fontFamily: kPatientPrimaryFont),
                ),
              ),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final d = widget.priorData;
    final name =
        (d[AppointmentFields.patientName] ?? '').toString().trim();
    final phone =
        (d[AppointmentFields.bookingPhone] ?? '').toString().trim();
    final note =
        (d[AppointmentFields.bookingMedicalNotes] ?? '').toString().trim();
    final noteDisplay = note.isEmpty
        ? loc.translate('schedule_appointment_detail_no_notes')
        : note;
    final phoneDisplay =
        phone.isEmpty ? '—' : _scheduleWesternDigits(phone);
    const dialogR = 22.0;
    const cardBorder = BorderSide(
      color: Color(0x1AFFFFFF),
      width: 1,
    );

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(dialogR),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B10).withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(dialogR),
                      border: Border.fromBorderSide(cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  8,
                                  6,
                                  8,
                                  8,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    loc.translate(
                                      'schedule_patient_details_title',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17.5,
                                      height: 1.35,
                                      letterSpacing: 0.2,
                                      color:
                                          Colors.white.withValues(alpha: 0.96),
                                    ),
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                top: 0,
                                end: 0,
                                child: _schedulePatientDialogTimeBadge(
                                  widget.timeEn,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Center(child: _schedulePatientDialogAvatar(name)),
                          const SizedBox(height: 24),
                          _schedulePatientInfoGlassCard(
                            icon: Icons.badge_outlined,
                            label: loc.translate(
                              'schedule_appointment_detail_name_label',
                            ),
                            value: name.isEmpty ? '—' : name,
                            valueLtr: true,
                            valueStyle: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _schedulePatientInfoGlassCard(
                            icon: Icons.phone_iphone_rounded,
                            label: loc.translate(
                              'schedule_appointment_detail_phone_label',
                            ),
                            value: phoneDisplay,
                            valueLtr: true,
                            valueStyle: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              height: 1.35,
                              letterSpacing: 0.2,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _schedulePatientInfoGlassCard(
                            icon: Icons.sticky_note_2_outlined,
                            label: loc.translate(
                              'schedule_appointment_detail_notes_label',
                            ),
                            value: noteDisplay,
                            valueLtr: false,
                            valueStyle: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.45,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _cancelling
                                      ? null
                                      : () => _onCancelPressed(context),
                                  style: FilledButton.styleFrom(
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    minimumSize: const Size(0, 42),
                                    maximumSize: const Size(double.infinity, 42),
                                    backgroundColor: const Color(0xFF6B2C2C),
                                    disabledBackgroundColor: Colors.white
                                        .withValues(alpha: 0.06),
                                    foregroundColor:
                                        const Color(0xFFF4E8E8),
                                    disabledForegroundColor: Colors.white
                                        .withValues(alpha: 0.35),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: const Color(0xFF4A1F1F)
                                            .withValues(alpha: 0.95),
                                        width: 1,
                                      ),
                                    ),
                                  ).copyWith(
                                    overlayColor:
                                        WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states.contains(
                                          WidgetState.pressed,
                                        )) {
                                          return Colors.black
                                              .withValues(alpha: 0.12);
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  child: Text(
                                    loc.translate(
                                      'schedule_slot_cancel_appointment_short',
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: IgnorePointer(
                                  ignoring: _cancelling,
                                  child: Opacity(
                                    opacity: _cancelling ? 0.45 : 1,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        minimumSize: const Size(0, 42),
                                        maximumSize:
                                            const Size(double.infinity, 42),
                                        foregroundColor: Colors.white
                                            .withValues(alpha: 0.9),
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.04),
                                        side: BorderSide(
                                          color: kStaffLuxGold.withValues(
                                            alpha: 0.32,
                                          ),
                                          width: 1,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: Text(
                                        loc.translate('close'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_cancelling)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: kStaffLuxGold.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
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
          ),
        ),
      ),
    );
  }
}

/// Compact read-only strip: today’s clinic window + slot length (from [ScheduleDayPanelController]).
class _ScheduleSettingsSummaryCard extends StatelessWidget {
  const _ScheduleSettingsSummaryCard();

  String _hhMm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final panel = ScheduleDayPanelScope.of(context);
    return ListenableBuilder(
      listenable: panel,
      builder: (context, _) {
        final past = panel.scheduleDayIsPast;
        final open = panel.scheduleSummaryClinicOpen;
        final startEn =
            _scheduleHhMmToEnglish12h(_hhMm(panel.scheduleSummaryStart));
        final endEn =
            _scheduleHhMmToEnglish12h(_hhMm(panel.scheduleSummaryEnd));
        final nf = NumberFormat.decimalPattern('en_US');
        final durEn = nf.format(panel.scheduleSummaryDurationMin);

        final body = open
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      loc.translate(
                        'schedule_settings_card_shift',
                        params: {'start': startEn, 'end': endEn},
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        height: 1.25,
                        color: Colors.white.withValues(alpha: past ? 0.55 : 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.translate(
                      'schedule_settings_card_duration',
                      params: {'minutes': durEn},
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: past ? 0.48 : 0.72),
                    ),
                  ),
                ],
              )
            : Text(
                loc.translate('schedule_settings_card_closed'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: past ? 0.5 : 0.82),
                ),
              );

        const cardRadius = 16.0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => panel.openTimeSettingsSheet(context),
            borderRadius: BorderRadius.circular(cardRadius),
            splashColor: Colors.white.withValues(alpha: 0.14),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cardRadius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cardRadius),
                    border: Border.all(
                      color: kStaffLuxGold.withValues(alpha: past ? 0.22 : 0.4),
                      width: 0.8,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kStaffShellGradientTop
                            .withValues(alpha: past ? 0.5 : 0.88),
                        kStaffShellGradientMid
                            .withValues(alpha: past ? 0.48 : 0.85),
                        const Color(0xFF0D2137)
                            .withValues(alpha: past ? 0.55 : 0.92),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            open
                                ? Icons.schedule_rounded
                                : Icons.event_busy_rounded,
                            size: 22,
                            color: kStaffLuxGold
                                .withValues(alpha: past ? 0.45 : 0.85),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                loc.translate('schedule_settings_card_caption'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                  height: 1.2,
                                  color: Colors.white
                                      .withValues(alpha: past ? 0.42 : 0.58),
                                ),
                              ),
                              const SizedBox(height: 6),
                              body,
                            ],
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
      },
    );
  }
}

class _ScheduleBottomDayHeroButton extends StatefulWidget {
  const _ScheduleBottomDayHeroButton({
    required this.dayLocal,
    required this.panel,
    required this.hint,
  });

  final DateTime dayLocal;
  final ScheduleDayPanelController panel;
  final String hint;

  static const double squareSide = 184.0;
  static const double _radius = 28.0;

  @override
  State<_ScheduleBottomDayHeroButton> createState() =>
      _ScheduleBottomDayHeroButtonState();
}

class _ScheduleBottomDayHeroButtonState extends State<_ScheduleBottomDayHeroButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseCurve;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _pulseCurve = CurvedAnimation(
      parent: _pulse,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    final dayNum = '${widget.dayLocal.day}';

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulseCurve.value;
        final glow = 0.28 + 0.62 * t;
        final lift = 10.0 + 10.0 * t;
        final spread = 0.5 + 2.2 * t;

        return Transform.translate(
          offset: Offset(0, -1.0 * t),
          child: Container(
            width: _ScheduleBottomDayHeroButton.squareSide + 10,
            height: _ScheduleBottomDayHeroButton.squareSide + 10,
            alignment: Alignment.center,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(_ScheduleBottomDayHeroButton._radius + 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.42 * glow),
                    blurRadius: lift + 8,
                    spreadRadius: spread,
                  ),
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.32 * glow),
                    blurRadius: lift * 0.65,
                    spreadRadius: spread * 0.4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius:
                    BorderRadius.circular(_ScheduleBottomDayHeroButton._radius),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showScheduleSlotsModalBottomSheet(
                      context: context,
                      panel: widget.panel,
                      dayLocal: widget.dayLocal,
                      loc: loc,
                    );
                  },
                  borderRadius: BorderRadius.circular(
                      _ScheduleBottomDayHeroButton._radius),
                  splashColor: Colors.white.withValues(alpha: 0.18),
                  highlightColor: Colors.white.withValues(alpha: 0.06),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                          _ScheduleBottomDayHeroButton._radius),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E40AF),
                          Color(0xFF3730A3),
                          Color(0xFF5B21B6),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      border: Border.all(
                        color: Color.lerp(
                          const Color(0xFFE8E8E8),
                          kStaffLuxGold,
                          0.65,
                        )!,
                        width: 1.15,
                      ),
                    ),
                    child: SizedBox(
                      width: _ScheduleBottomDayHeroButton.squareSide,
                      height: _ScheduleBottomDayHeroButton.squareSide,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 11,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _ScheduleBottomDayHeroButton.squareSide -
                                  22,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                        ),
                                      ),
                                      child: Text(
                                        widget.hint,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 9.8,
                                          height: 1.22,
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Directionality(
                                        textDirection: ui.TextDirection.ltr,
                                        child: Text(
                                          dayNum,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: kPatientPrimaryFont,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 52,
                                            height: 1.0,
                                            letterSpacing: -0.5,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                              Shadow(
                                                color: kStaffLuxGold
                                                    .withValues(alpha: 0.45),
                                                blurRadius: 12,
                                              ),
                                            ],
                                            color: Colors.white.withValues(
                                                alpha: 0.98),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Transform.scale(
                                        scale: 0.9 +
                                            0.1 *
                                                (0.5 +
                                                    0.5 *
                                                        math.sin(_pulse.value *
                                                            2 *
                                                            math.pi)),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.touch_app_rounded,
                                          size: 22,
                                          color: kStaffLuxGold
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom area: hint until a day is chosen, then centered square → modal slot list.
class _ScheduleBottomSlotsSection extends StatelessWidget {
  const _ScheduleBottomSlotsSection({this.userSelectedDay});

  final DateTime? userSelectedDay;

  @override
  Widget build(BuildContext context) {
    final loc = S.of(context);
    if (userSelectedDay == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0),
        child: Text(
          loc.translate('schedule_slots_pick_day_hint'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w600,
            fontSize: 13.0,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      );
    }
    final c = ScheduleDayPanelScope.of(context);
    final d0 = DateTime(
      userSelectedDay!.year,
      userSelectedDay!.month,
      userSelectedDay!.day,
    );
    final hint = loc.translate('schedule_slots_square_hint');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
        child: _ScheduleBottomDayHeroButton(
          dayLocal: d0,
          panel: c,
          hint: hint,
        ),
      ),
    );
  }
}
