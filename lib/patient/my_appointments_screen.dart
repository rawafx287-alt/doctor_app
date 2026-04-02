import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/appointment_queries.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth/firestore_user_doc_id.dart';
import '../auth/patient_session_cache.dart';
import '../auth/phone_auth_config.dart';
import '../auth/phone_normalization.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';

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

void _sortPatientAppointmentsAll(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
) {
  list.sort((a, b) {
    final da = _parseAppointmentDate(a.data()[AppointmentFields.date]);
    final db = _parseAppointmentDate(b.data()[AppointmentFields.date]);
    if (da != null && db != null) {
      final c = db.compareTo(da);
      if (c != 0) return c;
    } else if (da != null) {
      return 1;
    } else if (db != null) {
      return -1;
    }
    final ta = a.data()[AppointmentFields.createdAt];
    final tb = b.data()[AppointmentFields.createdAt];
    if (ta is Timestamp && tb is Timestamp) {
      final c = tb.compareTo(ta);
      if (c != 0) return c;
    }
    return _appointmentTimeSortMinutes(b.data()[AppointmentFields.time])
        .compareTo(_appointmentTimeSortMinutes(a.data()[AppointmentFields.time]));
  });
}

String _normAppointmentStatus(dynamic raw) =>
    (raw ?? 'pending').toString().trim().toLowerCase();

bool _isPastAppointmentStatus(String st) =>
    st == 'completed' || st == 'cancelled' || st == 'canceled';

/// Active section: [pending] rows first, then others; within each bucket, newest date/time first.
void _sortActiveAppointmentsForDisplay(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
) {
  int pendingRank(String st) => st == 'pending' ? 0 : 1;
  list.sort((a, b) {
    final sa = _normAppointmentStatus(a.data()[AppointmentFields.status]);
    final sb = _normAppointmentStatus(b.data()[AppointmentFields.status]);
    final ra = pendingRank(sa);
    final rb = pendingRank(sb);
    if (ra != rb) return ra.compareTo(rb);

    final da = _parseAppointmentDate(a.data()[AppointmentFields.date]);
    final db = _parseAppointmentDate(b.data()[AppointmentFields.date]);
    if (da != null && db != null) {
      final c = db.compareTo(da);
      if (c != 0) return c;
    } else if (da != null) {
      return 1;
    } else if (db != null) {
      return -1;
    }
    final ta = a.data()[AppointmentFields.createdAt];
    final tb = b.data()[AppointmentFields.createdAt];
    if (ta is Timestamp && tb is Timestamp) {
      final c = tb.compareTo(ta);
      if (c != 0) return c;
    }
    return _appointmentTimeSortMinutes(b.data()[AppointmentFields.time])
        .compareTo(_appointmentTimeSortMinutes(a.data()[AppointmentFields.time]));
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
      kAppointmentStatusCompletedBg,
      kAppointmentStatusCompletedFg,
      tr.translate('status_completed'),
    );
  }
  if (s == 'cancelled' || s == 'canceled') {
    return (
      const Color(0xFFC62828),
      kAppointmentStatusPendingFg,
      tr.translate('status_cancelled'),
    );
  }
  if (s == 'confirmed') {
    final c = appointmentStatusBadgeColors('confirmed');
    return (c.$1, c.$2, tr.translate('status_confirmed'));
  }
  if (s == 'arrived') {
    final c = appointmentStatusBadgeColors('arrived');
    return (c.$1, c.$2, tr.translate('status_arrived'));
  }
  final c = appointmentStatusBadgeColors('pending');
  return (c.$1, c.$2, tr.translate('status_pending'));
}

Color _statusPillBorder(String status, {required bool isPast}) {
  if (isPast) return const Color(0xFF9E9E9E).withValues(alpha: 0.55);
  final s = status.toLowerCase().trim();
  if (s == 'completed') return const Color(0xFF1B5E20).withValues(alpha: 0.65);
  if (s == 'pending') return const Color(0xFFBF360C).withValues(alpha: 0.58);
  if (s == 'cancelled' || s == 'canceled') {
    return const Color(0xFF8B0000).withValues(alpha: 0.55);
  }
  if (s == 'confirmed') return const Color(0xFF1A237E).withValues(alpha: 0.55);
  if (s == 'arrived') return const Color(0xFF3E2723).withValues(alpha: 0.5);
  return const Color(0xFFD4AF37).withValues(alpha: 0.7);
}

class _PremiumBookingCard extends StatelessWidget {
  const _PremiumBookingCard({
    required this.queueLabel,
    required this.doctorName,
    required this.specialty,
    required this.patientName,
    required this.dateStr,
    required this.timeStr,
    required this.status,
    this.isPast = false,
    this.pendingGlow = false,
  });

  final String queueLabel;
  final String doctorName;
  final String specialty;
  final String patientName;
  final String dateStr;
  final String timeStr;
  final String status;
  final bool isPast;
  final bool pendingGlow;

  (String label, Color bg, Color fg) _statusStyle(BuildContext context) {
    final s = status.toLowerCase().trim();
    final tr = S.of(context);
    if (s == 'completed') {
      return (
        tr.translate('status_completed'),
        kAppointmentStatusCompletedBg,
        kAppointmentStatusCompletedFg,
      );
    }
    if (s == 'cancelled' || s == 'canceled') {
      return (
        tr.translate('status_cancelled'),
        const Color(0xFFFFEBEE),
        const Color(0xFFB71C1C),
      );
    }
    if (s == 'confirmed') {
      return (
        tr.translate('status_confirmed'),
        const Color(0xFFE8EAF6),
        const Color(0xFF283593),
      );
    }
    if (s == 'arrived') {
      return (
        tr.translate('status_arrived'),
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
      );
    }
    return (
      tr.translate('status_pending'),
      kAppointmentStatusPendingBg,
      kAppointmentStatusPendingFg,
    );
  }

  Widget _infoChip(IconData icon, String text) {
    final borderC = isPast
        ? const Color(0xFF9E9E9E).withValues(alpha: 0.45)
        : const Color(0xFFD4AF37).withValues(alpha: 0.55);
    final iconC =
        isPast ? const Color(0xFFBDBDBD) : const Color(0xFFFFD700);
    final textC =
        isPast ? const Color(0xFFE0E0E0) : const Color(0xFFF1F1F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPast
            ? const Color(0xFF2A2A2A).withValues(alpha: 0.85)
            : const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderC,
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconC),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: kPatientNrtBoldFont,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              color: textC,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(context);
    final gold = const Color(0xFFD4AF37);
    final borderColor =
        isPast ? const Color(0xFFB0BEC5).withValues(alpha: 0.55) : gold;
    final borderW = pendingGlow && !isPast ? 2.35 : (isPast ? 0.85 : 1.0);
    final shadows = <BoxShadow>[
      if (pendingGlow && !isPast) ...[
        BoxShadow(
          color: gold.withValues(alpha: 0.42),
          blurRadius: 22,
          spreadRadius: 0.5,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFFFFD700).withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ] else if (!isPast)
        BoxShadow(
          color: gold.withValues(alpha: 0.16),
          blurRadius: 14,
          offset: const Offset(0, 4),
        )
      else
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
    ];

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: borderW,
        ),
        boxShadow: shadows,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              queueLabel,
              style: const TextStyle(
                fontFamily: kPatientNrtBoldFont,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: Color(0xFFFFD700),
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kPatientNrtBoldFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kPatientNrtBoldFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: const Color(0xFFE8E8E8).withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusStyle.$2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _statusPillBorder(
                        status,
                        isPast: isPast,
                      ),
                      width: 0.85,
                    ),
                  ),
                  child: Text(
                    statusStyle.$1,
                    style: TextStyle(
                      fontFamily: kPatientNrtBoldFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: statusStyle.$3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  width: double.infinity,
                  color: isPast
                      ? const Color(0xFF9E9E9E).withValues(alpha: 0.35)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.45),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _infoChip(Icons.calendar_today_rounded, dateStr),
                    _infoChip(Icons.schedule_rounded, timeStr),
                    _infoChip(Icons.person_rounded, patientName),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isPast) {
      return Opacity(
        opacity: 0.86,
        child: card,
      );
    }
    return card;
  }
}

Widget _myBookingsSectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: kPatientNrtBoldFont,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: kPatientNavyText,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    ),
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
  const PatientAppointmentsScreen({
    super.key,
    this.embedded = false,
    this.highlightAvailableDayDocId,
  });

  final bool embedded;
  final String? highlightAvailableDayDocId;

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  static const Color _onLightMuted = Color(0xFF546E7A);

  /// Matches light sky background so ticket hero perforation blends with the page.
  Color get _holeColor => kPatientSkyTop;
  Color get _uiAccent =>
      widget.embedded ? const Color(0xFF1976D2) : kPatientDeepBlue;
  Color get _uiMuted => _onLightMuted;

  Timer? _highlightTimer;
  bool _highlightActive = false;

  @override
  void initState() {
    super.initState();
    _highlightActive = (widget.highlightAvailableDayDocId ?? '').trim().isNotEmpty;
    if (_highlightActive) {
      _highlightTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _highlightActive = false);
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Set<String> _patientIdsForQueries(User user) {
    final phoneIds = <String>{};
    final authPhone = normalizePhoneDigits((user.phoneNumber ?? '').trim());
    if (authPhone.isNotEmpty) phoneIds.add(authPhone);
    final email = (user.email ?? '').trim();
    if (email.endsWith('@$kPhoneAuthEmailDomain')) {
      final p = normalizePhoneDigits(email.split('@').first);
      if (p.isNotEmpty) phoneIds.add(p);
    }
    final ids = <String>{
      user.uid.trim(),
      firestoreUserDocId(user).trim(),
      ...phoneIds,
    };
    ids.removeWhere((e) => e.isEmpty);
    return ids;
  }

  Future<Set<String>> _resolvePatientIds() async {
    final user = FirebaseAuth.instance.currentUser;
    final ids = <String>{};
    final cached = (await PatientSessionCache.readPatientRefId() ?? '').trim();
    if (cached.isNotEmpty) ids.add(cached);
    if (user != null) {
      ids.addAll(_patientIdsForQueries(user));
    }
    ids.removeWhere((e) => e.isEmpty);
    return ids;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _watchAppointmentsForPatientIds(Set<String> ids) {
    final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final id in ids) {
      streams.add(
        FirebaseFirestore.instance
            .collection(AppointmentFields.collection)
            .where(AppointmentFields.patientId, isEqualTo: id)
            .snapshots(),
      );
      streams.add(
        FirebaseFirestore.instance
            .collection(AppointmentFields.collection)
            .where(AppointmentFields.userId, isEqualTo: id)
            .snapshots(),
      );
    }

    return Stream.multi((controller) {
      final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
        streams.length,
        null,
      );
      void emitMerged() {
        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final snap in latest) {
          for (final d in snap?.docs ?? const []) {
            byId[d.id] = d;
          }
        }
        controller.add(byId.values.toList());
      }

      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < streams.length; i++) {
        subs.add(
          streams[i].listen(
            (event) {
              latest[i] = event;
              emitMerged();
            },
            onError: controller.addError,
          ),
        );
      }
      controller.onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    });
  }


  @override
  Widget build(BuildContext context) {
    final listBody = FutureBuilder<Set<String>>(
      future: _resolvePatientIds(),
      builder: (context, idsSnap) {
        if (idsSnap.connectionState == ConnectionState.waiting &&
            !idsSnap.hasData) {
          return Center(
            child: CircularProgressIndicator(color: _uiAccent),
          );
        }
        final patientIds = idsSnap.data ?? const <String>{};
        if (patientIds.isEmpty) {
          return Center(
            child: Text(
              S.of(context).translate('appointments_need_login'),
              style: TextStyle(color: _uiMuted, fontFamily: 'KurdishFont'),
            ),
          );
        }
        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _watchAppointmentsForPatientIds(patientIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: _uiAccent),
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
                snapshot.data ?? [],
              );
              final activeDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final pastDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              for (final d in docs) {
                final st = _normAppointmentStatus(d.data()[AppointmentFields.status]);
                if (_isPastAppointmentStatus(st)) {
                  pastDocs.add(d);
                } else {
                  activeDocs.add(d);
                }
              }
              _sortActiveAppointmentsForDisplay(activeDocs);
              _sortPatientAppointmentsAll(pastDocs);

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E1E1E),
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.event_note_rounded,
                            size: 52,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'هیچ نۆرەیەکت تۆمار نەکردووە',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kPatientNavyText.withValues(alpha: 0.92),
                            fontFamily: kPatientNrtBoldFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final padBottom =
                  24 + MediaQuery.paddingOf(context).bottom + (widget.embedded ? 8 : 0);

              Widget buildCardForDoc(
                QueryDocumentSnapshot<Map<String, dynamic>> docSnap, {
                required int orderIndex,
                required bool isPastSection,
              }) {
                final data = docSnap.data();
                final doctorName = (data[AppointmentFields.doctorName] ??
                        data[AppointmentFields.doctorId] ??
                        '—')
                    .toString();
                final patientName =
                    (data[AppointmentFields.patientName] ?? '—').toString();
                final specialty = (data['doctorSpecialty'] ?? '—').toString();
                final status =
                    (data[AppointmentFields.status] ?? 'pending').toString();
                final stNorm = _normAppointmentStatus(status);
                final timeStr =
                    (data[AppointmentFields.time] ?? '—').toString();
                final rawDate = data[AppointmentFields.date];
                final parsedDay = _parseAppointmentDate(rawDate);
                String dateStr = '—';
                if (parsedDay != null) {
                  dateStr = DateFormat('yyyy/MM/dd').format(parsedDay);
                } else if (rawDate != null) {
                  dateStr = rawDate.toString();
                }
                final daysStyle = parsedDay != null
                    ? _DaysRemainingStyle.fromAppointmentDay(
                        context,
                        parsedDay,
                      )
                    : null;
                final queueLabel = _appointmentQueueLabel(data, orderIndex);
                final docId = docSnap.id;
                final heroTag = 'appointment_ticket_$docId';
                final hlId = (widget.highlightAvailableDayDocId ?? '').trim();
                final isHighlighted = _highlightActive &&
                    hlId.isNotEmpty &&
                    ((data[AppointmentFields.availableDayDocId] ?? '')
                            .toString()
                            .trim() ==
                        hlId);
                final pendingGlow =
                    !isPastSection && stNorm == 'pending';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
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
                      holeColor: _holeColor,
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Hero(
                      tag: heroTag,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: isHighlighted
                              ? Border.all(
                                  color: const Color(0xFFD4AF37),
                                  width: 1.4,
                                )
                              : null,
                          boxShadow: isHighlighted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.33),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: _PremiumBookingCard(
                            queueLabel: queueLabel,
                            doctorName: doctorName,
                            specialty: specialty,
                            patientName: patientName,
                            dateStr: dateStr,
                            timeStr: timeStr,
                            status: status,
                            isPast: isPastSection,
                            pendingGlow: pendingGlow,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              final children = <Widget>[
                _myBookingsSectionHeader('نۆرەی چالاک'),
                if (activeDocs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'هیچ نۆرەی چالاکت نییە',
                      style: TextStyle(
                        color: kPatientNavyText.withValues(alpha: 0.78),
                        fontFamily: kPatientNrtBoldFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < activeDocs.length; i++)
                    buildCardForDoc(
                      activeDocs[i],
                      orderIndex: i,
                      isPastSection: false,
                    ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    height: 1,
                    thickness: 0.6,
                    color: kPatientNavyText.withValues(alpha: 0.14),
                  ),
                ),
                _myBookingsSectionHeader('نۆرەکانی پێشوو'),
                if (pastDocs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'هیچ نۆرەی پێشووت نییە',
                      style: TextStyle(
                        color: kPatientNavyText.withValues(alpha: 0.72),
                        fontFamily: kPatientNrtBoldFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  for (var j = 0; j < pastDocs.length; j++)
                    buildCardForDoc(
                      pastDocs[j],
                      orderIndex: j,
                      isPastSection: true,
                    ),
              ];

              return ListView(
                padding: EdgeInsets.fromLTRB(14, 12, 14, padBottom),
                children: children,
              );
            },
          );
      },
    );

    final body = listBody;

    final pageDir = AppLocaleScope.of(context).textDirection;
    final pageRtl = pageDir == ui.TextDirection.rtl;

    if (widget.embedded) {
      return Directionality(
        textDirection: pageDir,
        child: body,
      );
    }

    return Directionality(
      textDirection: pageDir,
      child: Scaffold(
        backgroundColor: kPatientSkyTop,
        appBar: AppBar(
          backgroundColor: kPatientSkyTop,
          foregroundColor: kPatientNavyText,
          surfaceTintColor: Colors.transparent,
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
            'نۆرەکانم',
            style: const TextStyle(
              fontFamily: kPatientNrtBoldFont,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: kPatientNavyText,
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: body,
        ),
      ),
    );
  }
}

/// Full-screen route after booking (back button). Same UI as [PatientAppointmentsScreen] standalone.
class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({
    super.key,
    this.highlightAvailableDayDocId,
  });

  final String? highlightAvailableDayDocId;

  @override
  Widget build(BuildContext context) => PatientAppointmentsScreen(
        embedded: false,
        highlightAvailableDayDocId: highlightAvailableDayDocId,
      );
}
