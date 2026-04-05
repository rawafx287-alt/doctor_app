import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../firestore/appointment_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import '../widgets/pressable_scale.dart';
import 'doctor_premium_shell.dart';

/// Completed appointments for a selectable day/week/month/year — compact list + detail sheet.
class DoctorPatientArchiveScreen extends StatefulWidget {
  const DoctorPatientArchiveScreen({
    super.key,
    required this.doctorUserId,
    this.embedded = false,
  });

  final String doctorUserId;

  /// When true (doctor [DoctorHomeScreen] tab), no app bar or scaffold background — shell provides both.
  final bool embedded;

  @override
  State<DoctorPatientArchiveScreen> createState() =>
      _DoctorPatientArchiveScreenState();
}

class _DoctorPatientArchiveScreenState extends State<DoctorPatientArchiveScreen> {
  late DateTime _anchorDate;
  DoctorArchiveGranularity _granularity = DoctorArchiveGranularity.month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _anchorDate = DateTime(n.year, n.month, n.day);
  }

  static String _totalKeyForGranularity(DoctorArchiveGranularity g) {
    switch (g) {
      case DoctorArchiveGranularity.day:
        return 'doctor_archive_total_period_daily';
      case DoctorArchiveGranularity.week:
        return 'doctor_archive_total_period_weekly';
      case DoctorArchiveGranularity.month:
        return 'doctor_archive_total_period_monthly';
      case DoctorArchiveGranularity.year:
        return 'doctor_archive_total_period_yearly';
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _historyTerminalFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>>? docs,
  ) {
    if (docs == null) return [];
    final out = docs.where((d) {
      final st = (d.data()[AppointmentFields.status] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return st == 'completed' ||
          st == 'cancelled' ||
          st == 'canceled';
    }).toList();
    out.sort(
      (a, b) => appointmentSlotDateTimeForStaffSort(b.data()).compareTo(
        appointmentSlotDateTimeForStaffSort(a.data()),
      ),
    );
    return out;
  }

  String _visitDateLine(BuildContext context, Map<String, dynamic> data) {
    final raw = data[AppointmentFields.date];
    final time = (data[AppointmentFields.time] ?? '').toString().trim();
    DateTime? day;
    if (raw is Timestamp) {
      final d = raw.toDate();
      day = DateTime(d.year, d.month, d.day);
    }
    if (day == null) return time.isEmpty ? '—' : time;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final df = DateFormat.yMMMd(locale);
    final datePart = df.format(day);
    if (time.isEmpty) return datePart;
    return '$datePart · $time';
  }

  String _compactVisitLine(BuildContext context, Map<String, dynamic> data) {
    final time = (data[AppointmentFields.time] ?? '').toString().trim();
    final raw = data[AppointmentFields.date];
    DateTime? day;
    if (raw is Timestamp) {
      final d = raw.toDate();
      day = DateTime(d.year, d.month, d.day);
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (day != null) {
      final ds = DateFormat.MMMd(locale).format(day);
      if (time.isNotEmpty) return '$ds · $time';
      return ds;
    }
    return time.isEmpty ? '—' : time;
  }

  String _archivePatientInitials(String rawName) {
    final t = rawName.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      final a = parts.first;
      final b = parts.last;
      return '${a[0]}${b[0]}'.toUpperCase();
    }
    return t[0].toUpperCase();
  }

  String _weekRangeLabel(BuildContext context) {
    final a = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
    final sat = archiveWeekRangeStartSaturday(a);
    final fri = sat.add(const Duration(days: 6));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final df = DateFormat.yMMMd(locale);
    return '${df.format(sat)} – ${df.format(fri)}';
  }

  void _shiftWeek(int deltaWeeks) {
    setState(() {
      _anchorDate = _anchorDate.add(Duration(days: 7 * deltaWeeks));
    });
  }

  Future<void> _showArchiveJumpCalendar(BuildContext context) async {
    final labels = MaterialLocalizations.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: labels.modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: Duration.zero,
      transitionBuilder: (ctx, anim, secondaryAnimation, child) => child,
      pageBuilder: (ctx, animation, secondaryAnimation) =>
          _ArchiveJumpCalendarDialog(
        initial: _anchorDate,
        onDateChosen: (d) {
          setState(() {
            _anchorDate = DateTime(d.year, d.month, d.day);
          });
        },
      ),
    );
  }

  /// Daily tab: single control to open the themed calendar — no horizontal strip.
  Widget _buildDailyDateSelectButton(
    BuildContext context,
    AppLocalizations strings, {
    required bool enabled,
  }) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLine = DateFormat.yMMMd(locale).format(_anchorDate);
    return PressableScale(
      enabled: enabled,
      onTap: enabled ? () => _showArchiveJumpCalendar(context) : null,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.72),
              width: 1.15,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: kStaffLuxGold.withValues(alpha: 0.95),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.translate('doctor_archive_select_day_button'),
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.25,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.2,
                        color: kStaffLuxGold.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _archiveDropdownDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: kStaffLuxGold.withValues(alpha: 0.9),
        fontFamily: kPatientPrimaryFont,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: kStaffLuxGold.withValues(alpha: 0.45),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: kStaffLuxGold,
          width: 1.2,
        ),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _archiveStatsBanner(AppLocalizations strings, int count) {
    final key = _totalKeyForGranularity(_granularity);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.42),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            strings.translate(
              key,
              params: {'count': '$count'},
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              height: 1.35,
              color: Color(0xFFE8EEF4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _granularityBar(AppLocalizations strings, {required bool enabled}) {
    final style = SegmentedButton.styleFrom(
      foregroundColor: Colors.white,
      selectedForegroundColor: Colors.white,
      selectedBackgroundColor: kStaffLuxGold.withValues(alpha: 0.42),
      backgroundColor: Colors.black.withValues(alpha: 0.22),
      side: BorderSide(color: kStaffLuxGold.withValues(alpha: 0.45)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      textStyle: const TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w700,
        fontSize: 10.5,
        height: 1.1,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SegmentedButton<DoctorArchiveGranularity>(
        style: style,
        showSelectedIcon: false,
        multiSelectionEnabled: false,
        emptySelectionAllowed: false,
        segments: [
          ButtonSegment(
            value: DoctorArchiveGranularity.day,
            label: Text(strings.translate('doctor_archive_period_daily')),
          ),
          ButtonSegment(
            value: DoctorArchiveGranularity.week,
            label: Text(strings.translate('doctor_archive_period_weekly')),
          ),
          ButtonSegment(
            value: DoctorArchiveGranularity.month,
            label: Text(strings.translate('doctor_archive_period_monthly')),
          ),
          ButtonSegment(
            value: DoctorArchiveGranularity.year,
            label: Text(strings.translate('doctor_archive_period_yearly')),
          ),
        ],
        selected: {_granularity},
        onSelectionChanged: enabled
            ? (Set<DoctorArchiveGranularity> next) {
                if (next.isEmpty) return;
                setState(() => _granularity = next.first);
              }
            : null,
      ),
    );
  }

  Widget _periodControls(
    BuildContext context,
    AppLocalizations strings, {
    required bool enabled,
    required List<DropdownMenuItem<int>> monthItems,
    required List<DropdownMenuItem<int>> yearItems,
  }) {
    Widget row(Widget child) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: child,
        );

    switch (_granularity) {
      case DoctorArchiveGranularity.day:
        return row(
          _buildDailyDateSelectButton(context, strings, enabled: enabled),
        );
      case DoctorArchiveGranularity.week:
        return row(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: enabled ? () => _shiftWeek(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
                color: kStaffLuxGold,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kStaffLuxGold.withValues(alpha: 0.38),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.translate('doctor_archive_week_caption'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.4,
                          color: kStaffLuxGold.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _weekRangeLabel(context),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: enabled ? () => _shiftWeek(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                color: kStaffLuxGold,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      case DoctorArchiveGranularity.month:
        return row(
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: _archiveDropdownDecoration(
                    strings.translate('doctor_archive_filter_month'),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _anchorDate.month,
                      isExpanded: true,
                      iconEnabledColor: kStaffLuxGold,
                      dropdownColor: const Color(0xFF152238),
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      items: monthItems,
                      onChanged: enabled
                          ? (v) {
                              if (v == null) return;
                              setState(() {
                                final y = _anchorDate.year;
                                final last = DateTime(y, v + 1, 0).day;
                                final d = _anchorDate.day.clamp(1, last);
                                _anchorDate = DateTime(y, v, d);
                              });
                            }
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InputDecorator(
                  decoration: _archiveDropdownDecoration(
                    strings.translate('doctor_archive_filter_year'),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _anchorDate.year,
                      isExpanded: true,
                      iconEnabledColor: kStaffLuxGold,
                      dropdownColor: const Color(0xFF152238),
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      items: yearItems,
                      onChanged: enabled
                          ? (v) {
                              if (v == null) return;
                              setState(() {
                                final m = _anchorDate.month;
                                final last = DateTime(v, m + 1, 0).day;
                                final d = _anchorDate.day.clamp(1, last);
                                _anchorDate = DateTime(v, m, d);
                              });
                            }
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case DoctorArchiveGranularity.year:
        return row(
          InputDecorator(
            decoration: _archiveDropdownDecoration(
              strings.translate('doctor_archive_filter_year'),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _anchorDate.year,
                isExpanded: true,
                iconEnabledColor: kStaffLuxGold,
                dropdownColor: const Color(0xFF152238),
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                items: yearItems,
                onChanged: enabled
                    ? (v) {
                        if (v == null) return;
                        setState(() {
                          _anchorDate = DateTime(v, 1, 1);
                        });
                      }
                    : null,
              ),
            ),
          ),
        );
    }
  }

  void _showArchivePatientDetail(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final s = S.of(context);
    final name = (data[AppointmentFields.patientName] ?? '').toString().trim();
    final initials = _archivePatientInitials(name);
    final phone = (data[AppointmentFields.bookingPhone] ?? '').toString().trim();
    final ageRaw = data[AppointmentFields.bookingAge];
    final age = ageRaw == null ? '' : ageRaw.toString().trim();
    final gender = (data[AppointmentFields.bookingGender] ?? '').toString().trim();
    final blood = (data[AppointmentFields.bloodGroup] ?? '').toString().trim();
    final notes = (data[AppointmentFields.bookingMedicalNotes] ?? '').toString().trim();
    final visit = _visitDateLine(context, data);

    Widget row(String label, String value, {int maxLines = 4}) {
      final v = value.trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: kStaffLuxGold.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              v.isEmpty ? '—' : v,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      );
    }

    final labels = MaterialLocalizations.of(context);
    final h = MediaQuery.sizeOf(context).height;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: labels.modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: Duration.zero,
      transitionBuilder: (ctx, anim, secondaryAnimation, child) => child,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Directionality(
            textDirection: AppLocaleScope.of(ctx).textDirection,
            child: SizedBox(
              height: h * 0.94,
              width: MediaQuery.sizeOf(ctx).width,
              child: Material(
                color: Colors.transparent,
                child: DraggableScrollableSheet(
                  initialChildSize: 0.58,
                  minChildSize: 0.38,
                  maxChildSize: 0.94,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            kStaffShellGradientTop.withValues(alpha: 0.98),
                            kStaffShellGradientBottom.withValues(alpha: 0.99),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        border: Border.all(
                          color: kStaffLuxGold.withValues(alpha: 0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: kStaffLuxGold.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      kStaffLuxGold.withValues(alpha: 0.22),
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name.isEmpty ? '—' : name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                  color: kStaffLuxGold,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                20 + MediaQuery.paddingOf(context).bottom,
                              ),
                              children: [
                                row(s.translate('doctor_archive_detail_visit'),
                                    visit,
                                    maxLines: 2),
                                row(s.translate('doctor_archive_field_full_name'),
                                    name),
                                row(s.translate('doctor_archive_field_phone'),
                                    phone),
                                row(s.translate('doctor_archive_field_age'),
                                    age),
                                row(s.translate('doctor_archive_field_gender'),
                                    gender),
                                row(s.translate('doctor_archive_field_blood'),
                                    blood),
                                row(s.translate('doctor_archive_field_notes'),
                                    notes,
                                    maxLines: 80),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _compactHistoryCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final name =
        (data[AppointmentFields.patientName] ?? '—').toString();
    final subtitle = _compactVisitLine(context, data);
    final initials = _archivePatientInitials(name);
    final st = (data[AppointmentFields.status] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isCancelled = st == 'cancelled' || st == 'canceled';
    final clinicClosed = (data[AppointmentFields.cancellationReason] ?? '')
            .toString()
            .trim() ==
        kAppointmentCancellationReasonClinicClosed;
    final s = S.of(context);

    return PressableScale(
      onTap: () => _showArchivePatientDetail(context, data),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.34),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: kStaffLuxGold.withValues(alpha: 0.2),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Colors.white,
                        height: 1.2,
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor:
                            Colors.white.withValues(alpha: 0.45),
                        decorationThickness: 1.1,
                      ),
                    ),
                    if (clinicClosed && isCancelled) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB71C1C)
                              .withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFFE57373)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          s.translate('doctor_appt_tag_clinic_closed'),
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: kStaffLuxGold.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final did = widget.doctorUserId.trim();
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    final yearItems = <DropdownMenuItem<int>>[];
    final y0 = DateTime.now().year;
    for (var y = y0 - 5; y <= y0 + 1; y++) {
      yearItems.add(DropdownMenuItem(value: y, child: Text('$y')));
    }

    final monthItems = <DropdownMenuItem<int>>[];
    for (var m = 1; m <= 12; m++) {
      final label = DateFormat.MMMM(localeTag).format(DateTime(2000, m));
      monthItems.add(DropdownMenuItem(value: m, child: Text(label)));
    }

    final Widget mainContent;
    if (did.isEmpty) {
      mainContent = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _granularityBar(s, enabled: false),
          _periodControls(
            context,
            s,
            enabled: false,
            monthItems: monthItems,
            yearItems: yearItems,
          ),
          _archiveStatsBanner(s, 0),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  s.translate('doctor_archive_unavailable'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      mainContent = StreamBuilder<
          List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: watchDoctorArchiveAppointmentDocs(
          doctorUserId: did,
          granularity: _granularity,
          anchorLocal: _anchorDate,
        ),
        builder: (context, snapshot) {
          final completed = _historyTerminalFromDocs(snapshot.data);
          final count = completed.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _granularityBar(s, enabled: true),
              KeyedSubtree(
                key: ValueKey(_granularity),
                child: _periodControls(
                  context,
                  s,
                  enabled: true,
                  monthItems: monthItems,
                  yearItems: yearItems,
                ),
              ),
              _archiveStatsBanner(s, count),
              const SizedBox(height: 6),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: kStaffLuxGold,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontFamily: kPatientPrimaryFont,
                            ),
                          ),
                        ),
                      );
                    }
                    if (completed.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            s.translate('doctor_archive_empty_period'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1.4,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        12 + MediaQuery.paddingOf(context).bottom,
                      ),
                      itemCount: completed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final doc = completed[i];
                        final data = doc.data();
                        return _compactHistoryCard(context, data);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    final shell = Stack(
      fit: StackFit.expand,
      children: [
        const DoctorPremiumBackground(),
        SafeArea(child: mainContent),
      ],
    );

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        extendBodyBehindAppBar: !widget.embedded,
        backgroundColor: widget.embedded
            ? Colors.transparent
            : kDoctorPremiumGradientBottom,
        appBar: widget.embedded
            ? null
            : doctorPremiumAppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: kStaffLuxGold,
                  onPressed: () => Navigator.maybePop(context),
                ),
                title: Text(s.translate('doctor_archive_title')),
              ),
        body: widget.embedded ? mainContent : shell,
      ),
    );
  }
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ArchiveJumpCalendarDialog extends StatefulWidget {
  const _ArchiveJumpCalendarDialog({
    required this.initial,
    required this.onDateChosen,
  });

  final DateTime initial;
  final ValueChanged<DateTime> onDateChosen;

  @override
  State<_ArchiveJumpCalendarDialog> createState() =>
      _ArchiveJumpCalendarDialogState();
}

class _ArchiveJumpCalendarDialogState extends State<_ArchiveJumpCalendarDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  void _prevMonth() {
    setState(() {
      if (_month <= 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month >= 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    // Monday-first grid (aligned with header row below).
    final leading =
        (DateTime(_year, _month, 1).weekday - DateTime.monday + 7) % 7;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Center(
      child: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 340,
              constraints: const BoxConstraints(maxHeight: 460),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kStaffShellGradientTop.withValues(alpha: 0.98),
                    const Color(0xFF0D1B2A).withValues(alpha: 0.98),
                  ],
                ),
                border: Border.all(
                  color: kStaffLuxGold.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _prevMonth,
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: kStaffLuxGold,
                        ),
                        Expanded(
                          child: Text(
                            DateFormat.yMMMM(localeTag).format(
                              DateTime(_year, _month),
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _nextMonth,
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: kStaffLuxGold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(7, (i) {
                        final d = DateTime(2024, 1, 1 + i);
                        return Expanded(
                          child: Text(
                            DateFormat.E(localeTag).format(d),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: kStaffLuxGold.withValues(alpha: 0.88),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 5,
                        crossAxisSpacing: 5,
                        childAspectRatio: 1.05,
                      ),
                      itemCount: totalCells,
                      itemBuilder: (context, i) {
                        if (i < leading) return const SizedBox.shrink();
                        final dayNum = i - leading + 1;
                        if (dayNum > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        final cell = DateTime(_year, _month, dayNum);
                        final today = DateTime.now();
                        final isToday = _isSameCalendarDay(
                          cell,
                          DateTime(today.year, today.month, today.day),
                        );
                        final isSel = _isSameCalendarDay(cell, widget.initial);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              widget.onDateChosen(cell);
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? kStaffLuxGold.withValues(alpha: 0.4)
                                    : isToday
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel || isToday
                                      ? kStaffLuxGold.withValues(alpha: 0.75)
                                      : kStaffLuxGold.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Colors.white.withValues(
                                    alpha: isSel ? 1 : 0.92,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          S.of(context).translate('close'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
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
    );
  }
}
