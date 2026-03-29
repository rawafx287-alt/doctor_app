import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/appointment_queries.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';

/// Parses [date] from Firestore: [Timestamp], [DateTime], or strings like `2026/03/30`.
DateTime? _parseAppointmentDate(dynamic value) {
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

bool _isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Minutes from midnight for [AppointmentFields.time] keys like `09:30`; unknown → large value (last).
int _appointmentTimeSortMinutes(dynamic timeVal) {
  final s = (timeVal ?? '').toString().trim();
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
  if (m != null) {
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }
  return 1 << 20;
}

String _appointmentQueueLabel(Map<String, dynamic> data, int fallbackIndex) {
  final q = data[AppointmentFields.queueNumber];
  if (q is int && q > 0) {
    return '#${q.toString().padLeft(2, '0')}';
  }
  if (q is num && q > 0) {
    return '#${q.toInt().toString().padLeft(2, '0')}';
  }
  final h = (fallbackIndex + 1).toString().padLeft(2, '0');
  return '#$h';
}

void _sortPatientAppointmentsToday(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
) {
  list.sort((a, b) => _appointmentTimeSortMinutes(
        a.data()[AppointmentFields.time],
      ).compareTo(
        _appointmentTimeSortMinutes(b.data()[AppointmentFields.time]),
      ));
}

void _sortPatientAppointmentsAll(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
) {
  list.sort((a, b) {
    final da = _parseAppointmentDate(a.data()[AppointmentFields.date]);
    final db = _parseAppointmentDate(b.data()[AppointmentFields.date]);
    if (da != null && db != null) {
      final c = da.compareTo(db);
      if (c != 0) return c;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    final ta = a.data()[AppointmentFields.createdAt];
    final tb = b.data()[AppointmentFields.createdAt];
    if (ta is Timestamp && tb is Timestamp) {
      final c = ta.compareTo(tb);
      if (c != 0) return c;
    }
    return _appointmentTimeSortMinutes(a.data()[AppointmentFields.time])
        .compareTo(_appointmentTimeSortMinutes(b.data()[AppointmentFields.time]));
  });
}

/// Kurdish label + colors for چەند ڕۆژی ماوە / ئەمڕۆ / بەیانی / بەسەرچوو.
class _DaysRemainingStyle {
  const _DaysRemainingStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  static _DaysRemainingStyle fromAppointmentDay(
    BuildContext context,
    DateTime appointmentDay,
  ) {
    final s = S.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = appointmentDay.difference(today).inDays;
    if (diff < 0) {
      return _DaysRemainingStyle(
        label: s.translate('day_expired'),
        foreground: const Color(0xFFB0BEC5),
        background: const Color(0x28FFFFFF),
      );
    }
    if (diff == 0) {
      return _DaysRemainingStyle(
        label: s.translate('day_today'),
        foreground: const Color(0xFF81D4FA),
        background: const Color(0x331565C0),
      );
    }
    if (diff == 1) {
      return _DaysRemainingStyle(
        label: s.translate('day_tomorrow'),
        foreground: const Color(0xFFFFCC80),
        background: const Color(0x33FF9800),
      );
    }
    return _DaysRemainingStyle(
      label: s.translate('day_n_days_left', params: {'n': '$diff'}),
      foreground: const Color(0xFF90CAF9),
      background: const Color(0x331976D2),
    );
  }
}

/// Horizontal dashed line with side "punch" holes (ticket perforation).
class _TicketTearRow extends StatelessWidget {
  const _TicketTearRow({
    required this.holeColor,
    required this.dashColor,
  });

  static const double _holeDiameter = 14;

  final Color holeColor;
  final Color dashColor;

  @override
  Widget build(BuildContext context) {
    final halfHole = _holeDiameter / 2;
    return SizedBox(
      height: 12,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, 12),
            painter: _DashedLinePainter(color: dashColor),
          ),
          PositionedDirectional(
            start: -halfHole,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: _holeDiameter,
                height: _holeDiameter,
                decoration: BoxDecoration(
                  color: holeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: -halfHole,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: _holeDiameter,
                height: _holeDiameter,
                decoration: BoxDecoration(
                  color: holeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;
    const dash = 3.5;
    const gap = 3.0;
    double x = 12;
    final y = size.height / 2;
    while (x < size.width - 12) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

(Color bg, Color fg, String label) _appointmentStatusBadge(
  BuildContext context,
  String status,
) {
  final tr = S.of(context);
  final s = status.toLowerCase();
  if (s == 'completed') {
    return (
      const Color(0x3322C55E),
      const Color(0xFFA5D6A7),
      tr.translate('status_completed'),
    );
  }
  if (s == 'cancelled' || s == 'canceled') {
    return (
      const Color(0x33EF5350),
      const Color(0xFFFFAB91),
      tr.translate('status_cancelled'),
    );
  }
  return (
    const Color(0x3364B5F6),
    const Color(0xFF90CAF9),
    tr.translate('status_pending'),
  );
}

/// Digital ticket — list ([isPreview] false) or enlarged preview ([isPreview] true).
class _TicketVisual extends StatelessWidget {
  const _TicketVisual({
    required this.doctorName,
    required this.patientName,
    required this.dateStr,
    required this.timeStr,
    required this.status,
    required this.queueLabel,
    required this.daysStyle,
    required this.holeColor,
    required this.isPreview,
  });

  final String doctorName;
  final String patientName;
  final String dateStr;
  final String timeStr;
  final String status;
  final String queueLabel;
  final _DaysRemainingStyle? daysStyle;
  final Color holeColor;
  final bool isPreview;

  static const Color _ticketBg = Color(0xFF1E1E2C);
  static const Color _ticketBorder = Color(0xFF3D3D52);
  static const Color _doctorAccent = Color(0xFFFFD700);
  static const Color _labelDim = Color(0xFF8B95A8);
  static const Color _bodyLight = Color(0xFFECEFF4);
  static const Color _bodyMuted = Color(0xFFC5CBD6);
  static const Color _queueLight = Color(0xFF81D4FA);
  static const Color _dashSubtle = Color(0xFF4A4A5E);

  @override
  Widget build(BuildContext context) {
    final badge = _appointmentStatusBadge(context, status);
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;
    final textEnd = isRtl ? TextAlign.right : TextAlign.left;
    final rowDir = Directionality.of(context);
    final r = BorderRadius.circular(isPreview ? 16 : 12);
    final innerR = BorderRadius.circular(isPreview ? 15 : 11);

    final double doctorSize = isPreview ? 24 : 13;
    final int doctorMaxLines = isPreview ? 4 : 1;
    final double queueSize = isPreview ? 56 : 30;
    final double labelSize = isPreview ? 12 : 10;
    final double bodyMutedSize = isPreview ? 15 : 12.5;
    final double patientSize = isPreview ? 16 : 13;
    final double badgeFont = isPreview ? 11 : 9;
    final EdgeInsets headerPad = isPreview
        ? const EdgeInsets.fromLTRB(18, 16, 18, 10)
        : const EdgeInsets.fromLTRB(12, 10, 12, 6);
    final EdgeInsets footerPad = isPreview
        ? const EdgeInsets.fromLTRB(18, 10, 18, 18)
        : const EdgeInsets.fromLTRB(12, 6, 12, 12);
    final double queueVPad = isPreview ? 14 : 6;
    final double daysChipFont = isPreview ? 12 : 10;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isPreview ? 0 : 2),
      decoration: BoxDecoration(
        color: _ticketBg,
        borderRadius: r,
        border: Border.all(
          color: _ticketBorder,
          width: isPreview ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isPreview ? 0.55 : 0.45),
            blurRadius: isPreview ? 28 : 18,
            offset: Offset(0, isPreview ? 12 : 8),
            spreadRadius: isPreview ? -4 : -6,
          ),
          BoxShadow(
            color: const Color(0xFF64B5F6).withValues(alpha: isPreview ? 0.1 : 0.06),
            blurRadius: isPreview ? 20 : 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: innerR,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: headerPad,
              child: Row(
                textDirection: rowDir,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: isPreview
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'HR Nora',
                                textAlign: textEnd,
                                style: TextStyle(
                                  color: _labelDim,
                                  fontSize: labelSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                S.of(context).translate('ticket_doctor_label'),
                                textAlign: textEnd,
                                style: TextStyle(
                                  color: _labelDim,
                                  fontSize: labelSize * 0.92,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                doctorName,
                                textAlign: textEnd,
                                maxLines: doctorMaxLines,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _doctorAccent,
                                  fontFamily: 'KurdishFont',
                                  fontWeight: FontWeight.w800,
                                  fontSize: doctorSize,
                                  height: 1.25,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x40000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            textDirection: rowDir,
                            children: [
                              Text(
                                'HR Nora',
                                style: TextStyle(
                                  color: _labelDim,
                                  fontSize: labelSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: _labelDim.withValues(alpha: 0.45),
                                  fontSize: labelSize,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  doctorName,
                                  textAlign: textEnd,
                                  maxLines: doctorMaxLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _doctorAccent,
                                    fontFamily: 'KurdishFont',
                                    fontWeight: FontWeight.w700,
                                    fontSize: doctorSize,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(width: isPreview ? 10 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isPreview ? 8 : 6,
                      vertical: isPreview ? 4 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: badge.$1,
                      borderRadius: BorderRadius.circular(isPreview ? 8 : 6),
                      border: Border.all(
                        color: badge.$2.withValues(alpha: 0.35),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      badge.$3,
                      style: TextStyle(
                        color: badge.$2,
                        fontFamily: 'KurdishFont',
                        fontSize: badgeFont,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isPreview ? 14 : 10),
              child: _TicketTearRow(
                holeColor: holeColor,
                dashColor: _dashSubtle,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: queueVPad),
              child: Center(
                child: Text(
                  queueLabel,
                  style: TextStyle(
                    color: _queueLight,
                    fontSize: queueSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: isPreview ? 1.2 : 0.5,
                    height: 1,
                    shadows: isPreview
                        ? const [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isPreview ? 14 : 10),
              child: _TicketTearRow(
                holeColor: holeColor,
                dashColor: _dashSubtle,
              ),
            ),
            Padding(
              padding: footerPad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${S.of(context).translate('ticket_date')}: $dateStr',
                    textAlign: textEnd,
                    style: TextStyle(
                      color: _bodyMuted,
                      fontFamily: 'KurdishFont',
                      fontSize: bodyMutedSize,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: isPreview ? 5 : 3),
                  Text(
                    '${S.of(context).translate('ticket_time')}: $timeStr',
                    textAlign: textEnd,
                    style: TextStyle(
                      color: _bodyMuted,
                      fontFamily: 'KurdishFont',
                      fontSize: bodyMutedSize,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: isPreview ? 5 : 3),
                  Text(
                    '${S.of(context).translate('ticket_patient')}: $patientName',
                    textAlign: textEnd,
                    style: TextStyle(
                      color: _bodyLight,
                      fontFamily: 'KurdishFont',
                      fontSize: patientSize,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (daysStyle != null) ...[
                    SizedBox(height: isPreview ? 10 : 6),
                    Align(
                      alignment: isRtl
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isPreview ? 10 : 8,
                          vertical: isPreview ? 5 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: daysStyle!.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: daysStyle!.foreground.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          daysStyle!.label,
                          style: TextStyle(
                            color: daysStyle!.foreground,
                            fontFamily: 'KurdishFont',
                            fontSize: daysChipFont,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketPreviewPage extends StatelessWidget {
  const _TicketPreviewPage({
    required this.heroTag,
    required this.doctorName,
    required this.patientName,
    required this.dateStr,
    required this.timeStr,
    required this.status,
    required this.queueLabel,
    required this.daysStyle,
    required this.holeColor,
  });

  final String heroTag;
  final String doctorName;
  final String patientName;
  final String dateStr;
  final String timeStr;
  final String status;
  final String queueLabel;
  final _DaysRemainingStyle? daysStyle;
  final Color holeColor;

  @override
  Widget build(BuildContext context) {
    final maxW = math.min(
      440.0,
      MediaQuery.sizeOf(context).width * 0.94,
    );

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.52),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF90CAF9),
                          size: 22,
                        ),
                        label: Text(
                          S.of(context).translate('close'),
                          style: const TextStyle(
                            color: Color(0xFFECEFF4),
                            fontFamily: 'KurdishFont',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const SizedBox.expand(),
                          ),
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxW,
                                maxHeight: constraints.maxHeight * 0.88,
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: GestureDetector(
                                  onTap: () {},
                                  behavior: HitTestBehavior.translucent,
                                  child: Hero(
                                    tag: heroTag,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: _TicketVisual(
                                        doctorName: doctorName,
                                        patientName: patientName,
                                        dateStr: dateStr,
                                        timeStr: timeStr,
                                        status: status,
                                        queueLabel: queueLabel,
                                        daysStyle: daysStyle,
                                        holeColor: holeColor,
                                        isPreview: true,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _openTicketPreview(
  BuildContext context, {
  required String heroTag,
  required String doctorName,
  required String patientName,
  required String dateStr,
  required String timeStr,
  required String status,
  required String queueLabel,
  required _DaysRemainingStyle? daysStyle,
  required Color holeColor,
}) {
  Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _TicketPreviewPage(
          heroTag: heroTag,
          doctorName: doctorName,
          patientName: patientName,
          dateStr: dateStr,
          timeStr: timeStr,
          status: status,
          queueLabel: queueLabel,
          daysStyle: daysStyle,
          holeColor: holeColor,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
    ),
  );
}

/// Patient view: نۆرەکانم — lists [appointments] for the signed-in user.
/// Set [embedded] to true when used inside a parent shell without a root [Scaffold]/[AppBar].
class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  static const Color _bg = Color(0xFF0A0E21);
  static const Color _teal = Color(0xFF42A5F5);
  static const Color _text = Color(0xFFD9E2EC);
  static const Color _muted = Color(0xFF829AB1);

  bool _todayOnly = true;
  late DateTime _todayAnchor;
  Timer? _dayTick;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _todayAnchor = DateTime(n.year, n.month, n.day);
    _dayTick = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      final d = DateTime(now.year, now.month, now.day);
      if (d != _todayAnchor) {
        setState(() => _todayAnchor = d);
      }
    });
  }

  @override
  void dispose() {
    _dayTick?.cancel();
    super.dispose();
  }

  void _toggleTodayOnly() => setState(() => _todayOnly = !_todayOnly);

  Widget _filterToggleBar(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          onPressed: _toggleTodayOnly,
          icon: Icon(
            _todayOnly ? Icons.list_alt_outlined : Icons.today_outlined,
            size: 20,
            color: _teal,
          ),
          label: Text(
            _todayOnly
                ? s.translate('appointments_show_all')
                : s.translate('appointments_show_today'),
            style: const TextStyle(
              color: _teal,
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final listBody = uid == null
        ? Center(
            child: Text(
              S.of(context).translate('appointments_need_login'),
              style: const TextStyle(color: _muted, fontFamily: 'KurdishFont'),
            ),
          )
        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Indexed query: `userId` + `orderBy(date).orderBy(time)` — see [patientAppointmentsQuery].
            stream: patientAppointmentsQuery(
              patientUid: uid,
              dateLocalDay: _todayOnly ? _todayAnchor : null,
            ).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _teal),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      S.of(context).translate(
                        'error_with_details',
                        params: {'detail': '${snapshot.error}'},
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                  ),
                );
              }
              var docs =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                snapshot.data?.docs ?? [],
              );
              if (_todayOnly) {
                docs = docs.where((d) {
                  final day = _parseAppointmentDate(d.data()[AppointmentFields.date]);
                  return day != null && _isSameCalendarDay(day, _todayAnchor);
                }).toList();
              }
              final sorted =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
              if (_todayOnly) {
                _sortPatientAppointmentsToday(sorted);
              } else {
                _sortPatientAppointmentsAll(sorted);
              }

              if (sorted.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      S.of(context).translate(
                        _todayOnly
                            ? 'appointments_empty_today'
                            : 'appointments_empty',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _muted,
                        fontFamily: 'KurdishFont',
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final data = sorted[index].data();
                  final doctorName = (data[AppointmentFields.doctorName] ??
                          data[AppointmentFields.doctorId] ??
                          '—')
                      .toString();
                  final patientName =
                      (data[AppointmentFields.patientName] ?? '—').toString();
                  final status =
                      (data[AppointmentFields.status] ?? 'pending').toString();
                  final timeStr =
                      (data[AppointmentFields.time] ?? '—').toString();
                  final rawDate = data[AppointmentFields.date];
                  final parsedDay = _parseAppointmentDate(rawDate);
                  String dateStr = '—';
                  if (parsedDay != null) {
                    dateStr = DateFormat.yMMMEd().format(parsedDay);
                  } else if (rawDate != null) {
                    dateStr = rawDate.toString();
                  }
                  final daysStyle = parsedDay != null
                      ? _DaysRemainingStyle.fromAppointmentDay(
                          context,
                          parsedDay,
                        )
                      : null;
                  final queueLabel = _appointmentQueueLabel(data, index);
                  final docId = sorted[index].id;
                  final heroTag = 'appointment_ticket_$docId';

                  return GestureDetector(
                    onTap: () => _openTicketPreview(
                      context,
                      heroTag: heroTag,
                      doctorName: doctorName,
                      patientName: patientName,
                      dateStr: dateStr,
                      timeStr: timeStr,
                      status: status,
                      queueLabel: queueLabel,
                      daysStyle: daysStyle,
                      holeColor: _bg,
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Hero(
                      tag: heroTag,
                      child: Material(
                        color: Colors.transparent,
                        child: _TicketVisual(
                          doctorName: doctorName,
                          patientName: patientName,
                          dateStr: dateStr,
                          timeStr: timeStr,
                          status: status,
                          queueLabel: queueLabel,
                          daysStyle: daysStyle,
                          holeColor: _bg,
                          isPreview: false,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );

    final body = uid == null
        ? listBody
        : widget.embedded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _filterToggleBar(context),
                  Expanded(child: listBody),
                ],
              )
            : listBody;

    final pageDir = AppLocaleScope.of(context).textDirection;
    final pageRtl = pageDir == ui.TextDirection.rtl;

    if (widget.embedded) {
      return Directionality(
        textDirection: pageDir,
        child: ColoredBox(color: _bg, child: body),
      );
    }

    return Directionality(
      textDirection: pageDir,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: _text,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              pageRtl
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: S.of(context).translate('back'),
          ),
          title: Text(
            S.of(context).translate('appointments'),
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          actions: [
            if (uid != null)
              IconButton(
                icon: Icon(
                  _todayOnly
                      ? Icons.calendar_view_month_outlined
                      : Icons.today_outlined,
                ),
                tooltip: _todayOnly
                    ? S.of(context).translate('appointments_show_all')
                    : S.of(context).translate('appointments_show_today'),
                onPressed: _toggleTodayOnly,
              ),
          ],
        ),
        body: body,
      ),
    );
  }
}

/// Full-screen route after booking (back button). Same UI as [PatientAppointmentsScreen] standalone.
class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PatientAppointmentsScreen(embedded: false);
}
