import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../firestore/available_days_queries.dart';
import '../firestore/firestore_index_error_log.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';
import 'booking_summary_screen.dart';

const Color _kDoctorNameNavy = Color(0xFF0D2137);
const Color _kDaysOfWeekBlue = Color(0xFF0D47A1);
const Color _kHintGrey = Color(0xFF455A64);
const Color _kCellMuted = Color(0xFF90A4AE);
const Color _kToastTextGrey = Color(0xFF546E7A);

/// Open / available — deep emerald field, white numerals.
const Color _kOpenDayFill = Color(0xFF1B5E20);
const Color _kOpenDayBorder = Color(0xFF0D3D16);

/// Booked / closed — dark ruby, white numerals.
const Color _kClosedDayFill = Color(0xFFB71C1C);
const Color _kClosedDayBorder = Color(0xFF7F1515);

const Color _kSelectedNavy = Color(0xFF0D47A1);
const Color _kSelectedNavyBorder = Color(0xFF0A3D91);
/// Metallic gold — thick ring for today & selected accent.
const Color _kSelectedGoldRing = Color(0xFFD4AF37);
const Color _kInfoBoxBlue = Color(0xFF42A5F5);

const Color _kGoldDark = Color(0xFF8B6914);
const Color _kGoldMid = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFF6E7A6);
const Color _kGoldShine = Color(0xFFFFE082);

String _weekdayTranslationKey(DateTime d) {
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
      return 'weekday_sun';
    default:
      return 'weekday_sun';
  }
}

/// Past dates — medium slate, struck through (non-interactive).
const Color _kPastFill = Color(0xFFF1F3F5);
const Color _kPastBorder = Color(0xFFDDE1E6);
const Color _kPastSlate = Color(0xFF64748B);

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
  Timer? _autoDismissTimer;

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
    _autoDismissTimer = Timer(const Duration(milliseconds: 2800), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
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

/// Patient: [TableCalendar] — deep emerald open, ruby closed, slate past + struck; tap open day to book.
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

class _PatientAvailableDaysListState extends State<PatientAvailableDaysList>
    with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  OverlayEntry? _calendarToastEntry;
  /// Date-only; drives quick scale-down while pointer is down on a day cell.
  DateTime? _pressedDayOnly;

  late final AnimationController _bottomCardSpringController;
  late final Animation<double> _bottomCardSlideY;
  late final AnimationController _digitPulseController;
  late final Animation<double> _digitPulseScale;

  String get _doctorUid => widget.doctorId.trim();

  @override
  void initState() {
    super.initState();
    _bottomCardSpringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _bottomCardSlideY = Tween<double>(begin: 22, end: 0).animate(
      CurvedAnimation(
        parent: _bottomCardSpringController,
        curve: Curves.elasticOut,
      ),
    );
    _digitPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _digitPulseScale = Tween<double>(begin: 0.97, end: 1.045).animate(
      CurvedAnimation(
        parent: _digitPulseController,
        curve: Curves.easeInOut,
      ),
    );
    _bottomCardSpringController.value = 1.0;
  }

  /// Removes the calendar toast overlay at most once; clears [_calendarToastEntry].
  void _removeCalendarToastEntry() {
    final entry = _calendarToastEntry;
    if (entry == null) return;
    if (entry.mounted) {
      entry.remove();
    }
    _calendarToastEntry = null;
  }

  void _onCalendarToastDismissed(OverlayEntry dismissed) {
    if (!mounted) return;
    if (_calendarToastEntry != dismissed) return;
    if (dismissed.mounted) {
      dismissed.remove();
    }
    _calendarToastEntry = null;
  }

  @override
  void dispose() {
    _removeCalendarToastEntry();
    _bottomCardSpringController.dispose();
    _digitPulseController.dispose();
    super.dispose();
  }

  void _triggerBottomCardMotion(
    Map<String, Map<String, dynamic>> openByDocId,
  ) {
    _bottomCardSpringController.forward(from: 0);
    final bookable = _selectedDayIsBookable(openByDocId);
    if (bookable) {
      _digitPulseController.repeat(reverse: true);
    } else {
      _digitPulseController
        ..stop()
        ..reset();
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Glass toast: fade + slide up from bottom (past / closed day feedback).
  void _showCalendarToast(
    BuildContext context,
    String message, {
    IconData icon = Icons.event_busy_rounded,
  }) {
    _removeCalendarToastEntry();
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
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
                onDismissed: () => _onCalendarToastDismissed(entry),
              ),
            ),
          ),
        ),
      ),
    );
    _calendarToastEntry = entry;
    overlay.insert(entry);
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
    HapticFeedback.selectionClick();
    final s = S.of(context);
    final status = (widget.mergedDoctorData['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status != 'approved') {
      _showCalendarToast(
        context,
        'دکتۆر هێشتا قبوڵ نەکراوە بۆ نۆرەگرتن',
        icon: Icons.verified_user_outlined,
      );
      return;
    }
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
    _triggerBottomCardMotion(openByDocId);

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

    // Open day: selection only — secretary confirms via bottom card button.
  }

  String _formatSelectedDateSubline(BuildContext context, DateTime date) {
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    final s = S.of(context);
    if (lang == HrNoraLanguage.ckb) {
      final wd = s.translate(_weekdayTranslationKey(date));
      final mo = s.translate('cal_month_${date.month}');
      return s.translate(
        'patient_calendar_date_subline',
        params: {
          'weekday': wd,
          'day': '${date.day}',
          'month': mo,
        },
      );
    }
    if (lang == HrNoraLanguage.ar) {
      return DateFormat('EEEE، d MMMM', 'ar').format(date);
    }
    return DateFormat('EEEE, MMMM d', 'en').format(date);
  }

  bool _selectedDayIsBookable(
    Map<String, Map<String, dynamic>> openByDocId,
  ) {
    final sel = _selectedDay;
    if (sel == null) return false;
    final status = (widget.mergedDoctorData['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status != 'approved') return false;
    final selOnly = _dateOnly(sel);
    if (selOnly.isBefore(_dateOnly(DateTime.now()))) return false;
    final docId = availableDayDocumentId(
      doctorUserId: _doctorUid,
      dateLocal: selOnly,
    );
    final data = openByDocId[docId];
    return data != null && availableDayIsOpen(data);
  }

  void _onConfirmOrViewSchedule(
    BuildContext context,
    Map<String, Map<String, dynamic>> openByDocId,
  ) {
    final s = S.of(context);
    HapticFeedback.lightImpact();
    final status = (widget.mergedDoctorData['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status != 'approved') {
      _showCalendarToast(
        context,
        'دکتۆر هێشتا قبوڵ نەکراوە بۆ نۆرەگرتن',
        icon: Icons.verified_user_outlined,
      );
      return;
    }
    if (_selectedDay == null) {
      _showCalendarToast(
        context,
        s.translate('patient_calendar_no_selection'),
        icon: Icons.touch_app_rounded,
      );
      return;
    }
    final sel = _dateOnly(_selectedDay!);
    if (sel.isBefore(_dateOnly(DateTime.now()))) {
      _showCalendarToast(
        context,
        s.translate('available_days_patient_past_day'),
        icon: Icons.schedule_rounded,
      );
      return;
    }
    final docId = availableDayDocumentId(
      doctorUserId: _doctorUid,
      dateLocal: sel,
    );
    final data = openByDocId[docId];
    if (data == null || !availableDayIsOpen(data)) {
      _showCalendarToast(
        context,
        s.translate('patient_calendar_pick_open_day'),
        icon: Icons.event_busy_rounded,
      );
      return;
    }
    _openSummary(context, availableDayDocId: docId, dateLocal: sel);
  }

  Widget _buildSelectedDateBottomCard(
    BuildContext context,
    Map<String, Map<String, dynamic>> openByDocId,
  ) {
    final s = S.of(context);
    final dir = AppLocaleScope.of(context).textDirection;
    final sel = _selectedDay;
    final subline = sel != null
        ? _formatSelectedDateSubline(context, sel)
        : s.translate('patient_calendar_no_selection');
    final bookable = _selectedDayIsBookable(openByDocId);
    final hasSelection = sel != null;
    final statusLabel = !hasSelection
        ? s.translate('patient_calendar_status_pick')
        : bookable
            ? s.translate('patient_calendar_status_available')
            : s.translate('patient_calendar_status_unavailable');
    final statusDot = !hasSelection
        ? const Color(0xFF94A3B8)
        : bookable
            ? const Color(0xFF2ECC71)
            : const Color(0xFFE74C3C);

    const navyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF1E88E5),
        Color(0xFF0D47A1),
        Color(0xFF0A1931),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.11),
              blurRadius: 30,
              offset: const Offset(0, 14),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: _kGoldMid.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.94),
                    Colors.white.withValues(alpha: 0.78),
                  ],
                ),
                border: Border.all(
                  color: _kGoldMid.withValues(alpha: 0.9),
                  width: 1.45,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(2.75),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19.5),
                  border: Border.all(
                    color: _kGoldMid.withValues(alpha: 0.42),
                    width: 0.85,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        textDirection: dir,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              s.translate('patient_calendar_selected_heading'),
                              style: TextStyle(
                                fontFamily: kPatientNrtBoldFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                letterSpacing: 0.35,
                                color: _kHintGrey.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  statusLabel,
                                  textAlign: TextAlign.end,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: kPatientNrtBoldFont,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    height: 1.2,
                                    color: _kDoctorNameNavy,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusDot,
                                  boxShadow: bookable
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF2ECC71)
                                                .withValues(alpha: 0.55),
                                            blurRadius: 6,
                                            spreadRadius: 0.5,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _bottomCardSpringController,
                        builder: (context, _) {
                          return Transform.translate(
                            offset: Offset(0, _bottomCardSlideY.value),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              textDirection: dir,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                    opacity: anim,
                                    child: child,
                                  ),
                                  child: sel != null
                                      ? KeyedSubtree(
                                          key: ValueKey<String>(
                                            '${sel.year}-${sel.month}-${sel.day}',
                                          ),
                                          child: AnimatedBuilder(
                                            animation: _digitPulseController,
                                            builder: (context, _) {
                                              final scale = bookable
                                                  ? _digitPulseScale.value
                                                  : 1.0;
                                              return Transform.scale(
                                                scale: scale,
                                                child: ShaderMask(
                                                  blendMode: BlendMode.srcIn,
                                                  shaderCallback: (bounds) =>
                                                      navyGradient
                                                          .createShader(
                                                    bounds,
                                                  ),
                                                  child: Text(
                                                    '${sel.day}',
                                                    style: const TextStyle(
                                                      fontFamily:
                                                          kPatientNrtBoldFont,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 56,
                                                      height: 1.0,
                                                      color: Colors.white,
                                                      letterSpacing: -1,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : Text(
                                          '—',
                                          key: const ValueKey<String>('dash'),
                                          style: TextStyle(
                                            fontFamily: kPatientNrtBoldFont,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 48,
                                            height: 1.0,
                                            color: _kHintGrey.withValues(
                                              alpha: 0.45,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 280),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    transitionBuilder: (child, anim) =>
                                        FadeTransition(
                                      opacity: anim,
                                      child: child,
                                    ),
                                    child: Row(
                                      key: ValueKey<String>(subline),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      textDirection: dir,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Icon(
                                            Icons.calendar_month_rounded,
                                            size: 19,
                                            color: _kGoldMid.withValues(
                                              alpha: 0.92,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            subline,
                                            textAlign: TextAlign.start,
                                            style: const TextStyle(
                                              fontFamily: kPatientNrtBoldFont,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5,
                                              height: 1.32,
                                              color: _kDoctorNameNavy,
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
                        },
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (bookable)
                            Positioned(
                              left: -6,
                              right: -6,
                              top: 4,
                              bottom: -4,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _kGoldLight.withValues(
                                        alpha: 0.55,
                                      ),
                                      blurRadius: 22,
                                      spreadRadius: 1,
                                    ),
                                    BoxShadow(
                                      color: _kGoldMid.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 28,
                                      spreadRadius: -4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _onConfirmOrViewSchedule(
                                context,
                                openByDocId,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: bookable
                                      ? RadialGradient(
                                          center: const Alignment(-0.2, -0.45),
                                          radius: 1.55,
                                          colors: [
                                            _kGoldLight,
                                            _kGoldShine,
                                            _kGoldMid,
                                            _kGoldDark,
                                          ],
                                          stops: const [
                                            0.0,
                                            0.22,
                                            0.52,
                                            1.0,
                                          ],
                                        )
                                      : null,
                                  color: bookable
                                      ? null
                                      : Colors.grey.shade300,
                                  border: Border.all(
                                    color: bookable
                                        ? _kGoldLight.withValues(alpha: 0.75)
                                        : Colors.grey.shade400,
                                    width: 0.85,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.translate('confirm_booking'),
                                      style: TextStyle(
                                        fontFamily: kPatientNrtBoldFont,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: bookable
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                        shadows: bookable
                                            ? const [
                                                Shadow(
                                                  color: Color(0x66000000),
                                                  offset: Offset(0, 1),
                                                  blurRadius: 2,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: OutlinedButton(
                          onPressed: () => _onConfirmOrViewSchedule(
                            context,
                            openByDocId,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kGoldDark,
                            side: BorderSide(
                              color: _kGoldMid.withValues(alpha: 0.88),
                              width: 1.35,
                            ),
                            backgroundColor: Colors.transparent,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 9,
                            ),
                          ),
                          child: Text(
                            s.translate('patient_calendar_view_schedule'),
                            style: const TextStyle(
                              fontFamily: kPatientNrtBoldFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
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
    );
  }

  static const double _kCalHeaderReserve = 52;
  static const double _kCalPadVReserve = 22;
  static const double _kCalMaxRows = 6;

  Widget _patientTableCalendar(
    BuildContext context,
    Map<String, Map<String, dynamic>> openByDocId, {
    required double rowHeight,
    required double daysOfWeekHeight,
    required double dowFontSize,
    required double headerTitleSize,
    required double chevronSize,
  }) {
    return TableCalendar<void>(
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      rowHeight: rowHeight,
      daysOfWeekHeight: daysOfWeekHeight,
      selectedDayPredicate: (d) =>
          _selectedDay != null && isSameDay(_selectedDay!, d),
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      startingDayOfWeek: StartingDayOfWeek.saturday,
      locale: Localizations.localeOf(context).toLanguageTag(),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: _kDaysOfWeekBlue,
          fontFamily: kPatientNrtBoldFont,
          fontSize: dowFontSize,
          fontWeight: FontWeight.w800,
        ),
        weekendStyle: TextStyle(
          color: _kDaysOfWeekBlue,
          fontFamily: kPatientNrtBoldFont,
          fontSize: dowFontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        headerPadding: EdgeInsets.zero,
        titleTextStyle: TextStyle(
          color: _kDoctorNameNavy,
          fontSize: headerTitleSize,
          fontWeight: FontWeight.w800,
          fontFamily: kPatientNrtBoldFont,
          letterSpacing: 0.2,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left_rounded,
          color: const Color(0xFF1565C0),
          size: chevronSize,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right_rounded,
          color: const Color(0xFF1565C0),
          size: chevronSize,
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
        setState(() => _focusedDay = focused);
      },
      onDaySelected: (sel, foc) =>
          _onDaySelected(context, sel, foc, openByDocId),
      enabledDayPredicate: (day) {
        final today = _dateOnly(DateTime.now());
        return !_dateOnly(day).isBefore(today);
      },
      calendarBuilders: CalendarBuilders<void>(
        defaultBuilder: (ctx, day, fDay) => _patientDayCell(
          day: day,
          focusedDay: fDay,
          openByDocId: openByDocId,
        ),
        disabledBuilder: (ctx, day, fDay) => _patientDayCell(
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
        selectedBuilder: (ctx, day, fDay) => _patientDayCell(
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
    );
  }

  Widget _calendarGlassShell(
    BuildContext context,
    Map<String, Map<String, dynamic>> openByDocId, {
    required double rowHeight,
    required double daysOfWeekHeight,
    required bool shrinkRowsToFit,
    required double dowFontSize,
    required double headerTitleSize,
    required double chevronSize,
  }) {
    final table = shrinkRowsToFit
        ? LayoutBuilder(
            builder: (context, c) {
              final avail = c.maxHeight -
                  _kCalHeaderReserve -
                  daysOfWeekHeight -
                  _kCalPadVReserve;
              final rh =
                  (avail / _kCalMaxRows).clamp(24.0, rowHeight);
              return _patientTableCalendar(
                context,
                openByDocId,
                rowHeight: rh,
                daysOfWeekHeight: daysOfWeekHeight,
                dowFontSize: dowFontSize,
                headerTitleSize: headerTitleSize,
                chevronSize: chevronSize,
              );
            },
          )
        : _patientTableCalendar(
            context,
            openByDocId,
            rowHeight: rowHeight,
            daysOfWeekHeight: daysOfWeekHeight,
            dowFontSize: dowFontSize,
            headerTitleSize: headerTitleSize,
            chevronSize: chevronSize,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
            child: table,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableDaysStream(
    BuildContext context, {
    required AppLocalizations s,
    required DateTime monthStart,
    required DateTime monthEnd,
    required bool calendarInExpanded,
    required double rowHeight,
    required double daysOfWeekHeight,
    required double dowFontSize,
    required double headerTitleSize,
    required double chevronSize,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              expectedCompositeIndexHint: kAvailableDaysDoctorDateRangeIndexHint,
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

        final calendar = _calendarGlassShell(
          context,
          openByDocId,
          rowHeight: rowHeight,
          daysOfWeekHeight: daysOfWeekHeight,
          shrinkRowsToFit: calendarInExpanded,
          dowFontSize: dowFontSize,
          headerTitleSize: headerTitleSize,
          chevronSize: chevronSize,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: Color(0xFF42A5F5),
                ),
              ),
            if (calendarInExpanded)
              Expanded(child: calendar)
            else
              calendar,
            _buildSelectedDateBottomCard(context, openByDocId),
          ],
        );
      },
    );
  }

  Widget _buildHeaderAndInstruction(AppLocalizations s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.translate('available_days_patient_title'),
          style: const TextStyle(
            color: _kDoctorNameNavy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: kPatientNrtBoldFont,
            height: 1.15,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.62),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.92),
                  width: 0.75,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: _kInfoBoxBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.translate('available_days_patient_hint_calendar'),
                        style: const TextStyle(
                          color: _kHintGrey,
                          fontSize: 12.5,
                          fontFamily: kPatientNrtBoldFont,
                          fontWeight: FontWeight.w600,
                          height: 1.34,
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
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);

    const rowH = 40.0;
    const dowH = 28.0;
    const dowFont = 11.0;
    const headerTitle = 15.0;
    const chevron = 20.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final useViewportFit =
            constraints.hasBoundedHeight && h.isFinite && h > 160;

        final stream = _buildAvailableDaysStream(
          context,
          s: s,
          monthStart: monthStart,
          monthEnd: monthEnd,
          calendarInExpanded: useViewportFit,
          rowHeight: rowH,
          daysOfWeekHeight: dowH,
          dowFontSize: dowFont,
          headerTitleSize: headerTitle,
          chevronSize: chevron,
        );

        if (!useViewportFit) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderAndInstruction(s),
              stream,
            ],
          );
        }

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(height: h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderAndInstruction(s),
                Expanded(child: stream),
              ],
            ),
          ),
        );
      },
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
    final dayCapacity = row == null
        ? 0
        : maxBookableSlotsForDayData(row, _dateOnly(day));
    final currentBookings = row == null
        ? 0
        : ((row[AvailableDayFields.currentBookings] as num?)?.toInt() ?? 0);
    final fullyBooked =
        row != null && dayCapacity > 0 && currentBookings >= dayCapacity;
    final closedOrFull = !open || fullyBooked;

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
      fill = _kSelectedNavy;
      borderColor = _kSelectedGoldRing;
      borderWidth = 2.0;
    } else if (isOutside) {
      fill = const Color(0xFFF7F7F8);
      borderColor = const Color(0xFFE8EAED).withValues(alpha: 0.9);
      borderWidth = 0.75;
    } else if (isPast) {
      fill = _kPastFill;
      borderColor = _kPastBorder;
      borderWidth = 0.75;
    } else if (!closedOrFull) {
      fill = _kOpenDayFill;
      borderColor = _kOpenDayBorder;
      borderWidth = 1.25;
    } else {
      fill = _kClosedDayFill;
      borderColor = _kClosedDayBorder;
      borderWidth = 1.25;
    }

    if (isToday && !isSelected) {
      borderColor = _kSelectedGoldRing;
      borderWidth = 3.0;
    }

    /// Strikethrough only for days strictly before today (non-interactive via [enabledDayPredicate]).
    final strikeThrough = isPast;

    Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isPast) {
      textColor = _kPastSlate;
    } else if (isOutside) {
      textColor = _kCellMuted;
    } else if (!closedOrFull) {
      textColor = Colors.white;
    } else {
      textColor = Colors.white;
    }

    const double kCellCornerRadius = 12.0;
    final radius = BorderRadius.circular(kCellCornerRadius);

    final List<BoxShadow> cellShadow;
    if (isSelected) {
      cellShadow = [
        BoxShadow(
          color: _kSelectedGoldRing.withValues(alpha: 0.5),
          blurRadius: 14,
          spreadRadius: 0.5,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: _kSelectedNavyBorder.withValues(alpha: 0.28),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (!isPast && !isOutside && !closedOrFull && !isSelected) {
      cellShadow = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 5,
          spreadRadius: -1,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: _kOpenDayFill.withValues(alpha: 0.35),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (!isPast && !isOutside && closedOrFull && !isSelected) {
      cellShadow = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 5,
          spreadRadius: -1,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: _kClosedDayFill.withValues(alpha: 0.3),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      cellShadow = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }

    final textWidget = Text(
      '${day.day}',
      style: TextStyle(
        fontFamily: kPatientNrtBoldFont,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: textColor,
        decoration:
            strikeThrough ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: _kPastSlate,
        decorationThickness: 1.75,
      ),
    );

    final isOpenGreen =
        !isPast && !isOutside && !closedOrFull && !isSelected;
    final isClosedRed =
        !isPast && !isOutside && closedOrFull && !isSelected;

    /// Simulates an inner shadow (inset depth) on bold green/red tiles.
    Widget innerDepthOverlay() {
      return Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: radius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.26),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.07),
                  ],
                  stops: const [0.0, 0.38, 0.62, 1.0],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final cellCore = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: cellShadow,
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        children: [
          if (isOpenGreen || isClosedRed) innerDepthOverlay(),
          Center(child: textWidget),
        ],
      ),
    );

    final pressed =
        _pressedDayOnly != null && isSameDay(_pressedDayOnly!, day);

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: isPast
          ? IgnorePointer(child: cellCore)
          : Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                setState(() => _pressedDayOnly = dayOnly);
              },
              onPointerUp: (_) {
                setState(() => _pressedDayOnly = null);
              },
              onPointerCancel: (_) {
                setState(() => _pressedDayOnly = null);
              },
              child: AnimatedScale(
                scale: pressed ? 0.94 : 1.0,
                duration: const Duration(milliseconds: 115),
                curve: Curves.easeOutCubic,
                child: Stack(
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(child: cellCore),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: pressed ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 90),
                        curve: Curves.easeOut,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              color: Colors.white.withValues(alpha: 0.22),
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
}
