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

/// Time-slot list for the selected calendar day; opens in a themed modal sheet.
void showScheduleSlotsModalBottomSheet({
  required BuildContext context,
  required ScheduleDayPanelController panel,
  required DateTime dayLocal,
  required AppLocalizations loc,
}) {
  final d0 = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final mediaH = MediaQuery.sizeOf(context).height;
  final sheetH = mediaH * 0.76;
  final (dayDig, monthDig) = _scheduleSlotsRevealDayMonth(d0);
  final title = loc.translate(
    'schedule_slots_sheet_title',
    params: {'day': dayDig, 'month': monthDig},
  );

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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16.0,
                                14.0,
                                16.0,
                                8.0,
                              ),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.0,
                                  height: 1.25,
                                  color: Colors.white.withValues(alpha: 0.95),
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
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF0E7490).withValues(alpha: 0.92),
          const Color(0xFF1E3A8A).withValues(alpha: 0.94),
        ],
      ),
      border: Border.all(
        color: const Color(0xFF2DD4BF).withValues(alpha: 0.55),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Text(
          timeEn,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            letterSpacing: 0.2,
            color: Colors.white.withValues(alpha: 0.98),
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
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF6366F1),
          Color(0xFF0EA5E9),
          Color(0xFFEC4899),
        ],
        stops: [0.0, 0.45, 1.0],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.38),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: inner,
  );
}

Widget _schedulePatientInfoGlassCard({
  required IconData icon,
  required Color neon,
  required String label,
  required String value,
  required bool valueLtr,
  required TextStyle valueStyle,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withValues(alpha: 0.07),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
      ),
      boxShadow: [
        BoxShadow(
          color: neon.withValues(alpha: 0.14),
          blurRadius: 22,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  neon.withValues(alpha: 0.45),
                  neon.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: neon.withValues(alpha: 0.55),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: neon.withValues(alpha: 0.25),
                  blurRadius: 12,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: neon.withValues(alpha: 0.98)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    height: 1.2,
                    letterSpacing: 0.2,
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                ),
                const SizedBox(height: 8),
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
  String? _pendingSavedStartHhMm;
  String? _pendingSavedEndHhMm;
  int? _pendingSavedDurationMin;

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
    _modalSlotsScrollController?.dispose();
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

  /// Clinic toggle → closed: confirm, cancel bookings, notify patients, close day in Firestore.
  Future<void> confirmAndCloseClinicFromSheet(BuildContext context) async {
    if (_isPast || _saving) return;
    final s = S.of(context);
    if (_dayRow == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('schedule_close_day_toggle_needs_save'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
      return;
    }
    if (!availableDayIsOpen(_dayRow!)) {
      _isOpen = false;
      notifyListeners();
      return;
    }
    final proceed = await _showScheduleCloseDayWarningDialog(context, s);
    if (proceed != true || !context.mounted) return;

    _saving = true;
    notifyListeners();
    try {
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
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Clinic toggle → open: clear all appointments for the day, mark day open, regenerate slots, toast.
  Future<void> openClinicAndResetDayFromSheet(BuildContext context) async {
    if (_isPast || _saving) return;
    final s = S.of(context);
    if (_dayRow == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('schedule_close_day_toggle_needs_save'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
      return;
    }
    if (availableDayIsOpen(_dayRow!)) {
      _isOpen = true;
      notifyListeners();
      return;
    }

    _saving = true;
    notifyListeners();
    try {
      // 1) Clear all old appointment docs (so list becomes clean immediately).
      await resetAllAppointmentsForDoctorLocalDayToAvailable(
        doctorUserId: _doctorUserId,
        dayLocal: _dateLocal,
      );

      // 2) Mark day open and keep current settings.
      final durEffective = int.tryParse((_durationController?.text ?? '').trim());
      final dur = (durEffective ?? _durationMin).clamp(1, 24 * 60);
      await setAvailableDayOpenState(
        availableDayDocId: _existingDocId,
        isOpen: true,
      );
      await updateAvailableDayTimeSettings(
        availableDayDocId: _existingDocId,
        startTimeHhMm: _fmt(_start),
        closingTimeHhMm: _fmt(_end),
        appointmentDurationMinutes: dur,
      );

      // 3) Regenerate `available` placeholders from current settings.
      await regenerateAvailableSlotsForDoctorLocalDay(
        doctorUserId: _doctorUserId,
        dayLocal: _dateLocal,
        startTimeHhMm: _fmt(_start),
        closingTimeHhMm: _fmt(_end),
        durationMinutes: dur,
      );

      await _refreshDayRowFromServer();
      _applyRowSnapshot();
      _isOpen = true;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('schedule_day_reopened_toast'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
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
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _save(BuildContext context) async {
    if (_isPast) return;
    final s = S.of(context);
    _saving = true;
    notifyListeners();
    var suppressDefaultSaveSnack = false;
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
            if (!context.mounted) return;
            _saving = false;
            notifyListeners();
            final proceed =
                await _showScheduleCloseDayWarningDialog(context, s);
            if (!context.mounted) return;
            if (proceed != true) return;
            _saving = true;
            notifyListeners();
            try {
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
              return;
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

        await regenerateAvailableSlotsForDoctorLocalDay(
          doctorUserId: _doctorUserId,
          dayLocal: _dateLocal,
          startTimeHhMm: _fmt(_start),
          closingTimeHhMm: _fmt(_end),
          durationMinutes: dur,
        );

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
      if (context.mounted && !suppressDefaultSaveSnack) {
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

  /// Glass time-settings modal (opened from the summary card).
  void openTimeSettingsSheet(BuildContext context) {
    final loc = S.of(context);
    final rootMedia = MediaQuery.of(context);
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
                  onTap: () => Navigator.of(sheetCtx).pop(),
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
                                          : () =>
                                              Navigator.of(sheetCtx).pop(),
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
                                  final enabled = !_isPast;
                                  final compact =
                                      MediaQuery.sizeOf(sheetCtx).width < 440;
                                  final durUi = _durationMin.clamp(5, 60);
                                  _durationMin = durUi;
                                  _durationController ??=
                                      TextEditingController(text: '$durUi');
                                  _durationController!.text = '$durUi';
                                  final sliderVal = durUi.toDouble();

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
                                                          if (v) {
                                                            openClinicAndResetDayFromSheet(sheetCtx);
                                                            return;
                                                          }
                                                          confirmAndCloseClinicFromSheet(
                                                              sheetCtx);
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
                                                    '$_durationMin min',
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
                                                    label:
                                                        '$_durationMin',
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
                                                  currentMinutes: _durationMin,
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
                                            isLoading: _saving,
                                            onPressed: (!enabled || _saving)
                                                ? null
                                                : () async {
                                                    await _save(sheetCtx);
                                                    if (sheetCtx.mounted) {
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
                                if (_saving)
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(26),
                                      ),
                                      child: AbsorbPointer(
                                        child: ColoredBox(
                                          color: Colors.black
                                              .withValues(alpha: 0.44),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 42,
                                              height: 42,
                                              child: CircularProgressIndicator(
                                                color: kStaffLuxGold,
                                                strokeWidth: 3,
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

  Widget _selectedDaySlotRow(
    BuildContext context,
    AppLocalizations loc, {
    required DateTime slotStart,
    required DateTime now,
    required Map<String, (String?, String, String, Map<String, dynamic>)> byKey,
  }) {
    const Color baseBg = Color(0xFF1E293B);
    const Color dividerGold = Color(0xFFFFD54F);
    const Color stripeAvailable = Color(0xFF34D399);
    const Color stripeBooked = Color(0xFFF59E0B);
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

    final nameStyleBooked = GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      height: 1.05,
      color: dividerGold.withValues(alpha: isPassed ? 0.7 : 0.98),
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

    final card = Opacity(
      opacity: rowOpacity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
        color: baseBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
        elevation: 4.0,
        child: SizedBox(
          height: 56.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: stripeColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 10.0,
                    end: 12.0,
                    top: 4.0,
                    bottom: 4.0,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72.0,
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
                              height: 1.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      if (isBooked == true) ...[
                        Icon(
                          Icons.person_rounded,
                          size: 15.0,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                        const SizedBox(width: 5.0),
                      ],
                      Expanded(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (isBooked == true)
                              ? nameStyleBooked
                              : TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.0,
                                  height: 1.0,
                                  color:
                                      Colors.white.withValues(alpha: 0.72),
                                ),
                        ),
                      ),
                      if (isBooked && qn != null && qn > 0)
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                kStaffLuxGold.withValues(alpha: 0.95),
                                const Color(0xFF22D3EE).withValues(alpha: 0.9),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kStaffLuxGold.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
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
                                fontSize: 12,
                                height: 1,
                                color: Color(0xFF0D2137),
                              ),
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 20.0,
                          color: Colors.white.withValues(
                            alpha: isBooked ? 0.72 : 0.38,
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

        return StreamBuilder<DateTime>(
          stream: _scheduleSlotListClockStream(),
          initialData: DateTime.now(),
          builder: (context, clockSnap) {
            final DateTime now = clockSnap.data ?? DateTime.now();
            if (forModalSheet &&
                modalController != null &&
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
                  targetIndex = i; // if all before now, land on last
                }
                // Each row is ~56px + vertical margin; use a slightly larger estimate.
                const rowExtent = 64.0;
                final targetOffset = (targetIndex * rowExtent)
                    .clamp(0.0, c.position.maxScrollExtent);
                c.jumpTo(targetOffset);
              });
            }
            return ListView.builder(
              key: const PageStorageKey<String>(
                'schedule_day_slot_list_v1',
              ),
              controller: modalController,
              shrinkWrap: !forModalSheet,
              physics: forModalSheet
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              padding: forModalSheet
                  ? const EdgeInsets.only(bottom: 20.0)
                  : EdgeInsets.zero,
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
    final ok = await showDialog<bool>(
      context: dialogContext,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          widget.loc.translate('schedule_are_you_sure'),
          style: const TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          widget.loc.translate('schedule_slot_cancel_confirm_title'),
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              widget.loc.translate('schedule_slot_cancel_no'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              widget.loc.translate('schedule_slot_cancel_yes'),
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w800,
                color: Colors.redAccent.shade200,
              ),
            ),
          ),
        ],
      ),
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
    const neonName = Color(0xFF22D3EE);
    const neonPhone = Color(0xFF34D399);
    const neonNote = Color(0xFFC084FC);
    const dialogR = 26.0;
    const borderPad = 1.35;

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(dialogR),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF22D3EE).withValues(alpha: 0.85),
                  kStaffLuxGold.withValues(alpha: 0.75),
                  const Color(0xFFA855F7).withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(borderPad),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(dialogR - borderPad),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF030712).withValues(alpha: 0.78),
                      borderRadius:
                          BorderRadius.circular(dialogR - borderPad),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  4,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    loc.translate(
                                        'schedule_patient_details_title'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      height: 1.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                top: 0,
                                end: 0,
                                child: _schedulePatientDialogTimeBadge(
                                    widget.timeEn),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Center(child: _schedulePatientDialogAvatar(name)),
                          const SizedBox(height: 22),
                          _schedulePatientInfoGlassCard(
                            icon: Icons.badge_outlined,
                            neon: neonName,
                            label: loc.translate(
                                'schedule_appointment_detail_name_label'),
                            value: name.isEmpty ? '—' : name,
                            valueLtr: true,
                            valueStyle: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              height: 1.25,
                              color: Colors.white.withValues(alpha: 0.94),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _schedulePatientInfoGlassCard(
                            icon: Icons.phone_iphone_rounded,
                            neon: neonPhone,
                            label: loc.translate(
                                'schedule_appointment_detail_phone_label'),
                            value: phoneDisplay,
                            valueLtr: true,
                            valueStyle: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.2,
                              letterSpacing: 0.3,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _schedulePatientInfoGlassCard(
                            icon: Icons.sticky_note_2_outlined,
                            neon: neonNote,
                            label: loc.translate(
                                'schedule_appointment_detail_notes_label'),
                            value: noteDisplay,
                            valueLtr: false,
                            valueStyle: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _cancelling
                                      ? null
                                      : () => _onCancelPressed(context),
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                      const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    shape: WidgetStateProperty.all(
                                      RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    side: WidgetStateBorderSide.resolveWith(
                                      (states) {
                                        if (states
                                            .contains(WidgetState.disabled)) {
                                          return BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                            width: 1,
                                          );
                                        }
                                        final hot = states.contains(
                                                WidgetState.pressed) ||
                                            states.contains(
                                                WidgetState.hovered);
                                        return BorderSide(
                                          color: hot
                                              ? const Color(0xFFE53935)
                                              : const Color(0xFFFF5252)
                                                  .withValues(alpha: 0.88),
                                          width: hot ? 1.45 : 1.15,
                                        );
                                      },
                                    ),
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states
                                            .contains(WidgetState.disabled)) {
                                          return Colors.white
                                              .withValues(alpha: 0.38);
                                        }
                                        final hot = states.contains(
                                                WidgetState.pressed) ||
                                            states.contains(
                                                WidgetState.hovered);
                                        return hot
                                            ? Colors.white
                                            : const Color(0xFFFFCDD2);
                                      },
                                    ),
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states
                                            .contains(WidgetState.disabled)) {
                                          return Colors.transparent;
                                        }
                                        final hot = states.contains(
                                                WidgetState.pressed) ||
                                            states.contains(
                                                WidgetState.hovered);
                                        return hot
                                            ? const Color(0xFFD32F2F)
                                                .withValues(alpha: 0.96)
                                            : Colors.transparent;
                                      },
                                    ),
                                    overlayColor:
                                        WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states
                                            .contains(WidgetState.pressed)) {
                                          return Colors.red
                                              .withValues(alpha: 0.22);
                                        }
                                        return Colors.red
                                            .withValues(alpha: 0.06);
                                      },
                                    ),
                                  ),
                                  child: Text(
                                    loc.translate(
                                        'schedule_slot_cancel_appointment_short'),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
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
                                    child: _schedPremiumBluePurpleSaveButton(
                                      label: loc.translate('close'),
                                      isLoading: false,
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_cancelling)
                            const Padding(
                              padding: EdgeInsets.only(top: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: kStaffLuxGold,
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
