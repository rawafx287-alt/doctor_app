import 'dart:async';
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
import '../push/appointment_local_notifications.dart';
import '../push/appointment_reminder_worker.dart';

class _ModernConfirmDialog extends StatelessWidget {
  const _ModernConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.confirmColor,
    required this.icon,
    this.cancelDeadline,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final IconData icon;
  final DateTime? cancelDeadline;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatHhMmSs(Duration d) {
    final total = d.inSeconds.clamp(0, 24 * 3600 * 7); // hard cap for safety
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return '${_two(h)}:${_two(m)}:${_two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    const r = 24.0;
    final tr = S.of(context);
    final deadline = cancelDeadline;
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
                    child: StreamBuilder<DateTime>(
                      stream: deadline == null
                          ? null
                          : Stream<DateTime>.periodic(
                              const Duration(seconds: 1),
                              (_) => DateTime.now(),
                            ),
                      initialData: DateTime.now(),
                      builder: (context, snap) {
                        final now = snap.data ?? DateTime.now();
                        final remaining = deadline == null
                            ? Duration.zero
                            : deadline.difference(now);
                        final expired =
                            deadline != null && remaining.inSeconds <= 0;

                        return Column(
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
                                      color: confirmColor.withValues(
                                        alpha: 0.25,
                                      ),
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
                            if (deadline != null) ...[
                              const SizedBox(height: 14),
                              Directionality(
                                textDirection: ui.TextDirection.ltr,
                                child: Text(
                                  tr.translate(
                                    'patient_cancel_countdown_remaining',
                                    params: {'time': _formatHhMmSs(remaining)},
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    height: 1.2,
                                    color: const Color(
                                      0xFFFBBF24,
                                    ).withValues(alpha: expired ? 0.55 : 0.92),
                                  ),
                                ),
                              ),
                              if (expired) ...[
                                const SizedBox(height: 10),
                                Text(
                                  tr.translate(
                                    'patient_cancel_countdown_expired_inline',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: Colors.white.withValues(alpha: 0.78),
                                  ),
                                ),
                              ],
                            ],
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
                                      foregroundColor: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                        width: 1,
                                      ),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
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
                                    onPressed: expired
                                        ? null
                                        : () => Navigator.of(context).pop(true),
                                    style: FilledButton.styleFrom(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      minimumSize: const Size(0, 42),
                                      backgroundColor: confirmColor.withValues(
                                        alpha: expired ? 0.35 : 0.92,
                                      ),
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
                        );
                      },
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

/// Rose-gold / peach accents for bookings UI (section bars, cards, ticket highlights).
const Color _kBookingsRoseTop = Color(0xFFE5989B);
const Color _kBookingsRoseBottom = Color(0xFFB56576);
const Color _kBookingsRoseSolid = Color(0xFFCB8E8E);

const LinearGradient _kBookingsRoseBarGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_kBookingsRoseTop, _kBookingsRoseBottom],
);

/// Past bookings: classic gold / bronze (vertical) — legacy; ticket dialog keeps richer styling.
const LinearGradient _kPastBookingCardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF5E6CA), Color(0xFFD4A373), Color(0xFFA98467)],
  stops: [0.0, 0.5, 1.0],
);

const double _kPremiumBookingCardRadius = 14.0;

/// Active appointment accent (vertical bar + tints).
const Color _kBookingCardPrimaryBlue = Color(0xFF1976D2);

/// Very faint blue wash behind active list cards.
const Color _kBookingCardActiveTint = Color(0xFFF5F9FF);

/// Past / expired card surface (neutral grey).
const Color _kBookingCardPastSurface = Color(0xFFF3F4F6);

/// Soft elevation — no heavy border on cards.
const List<BoxShadow> _kPremiumBookingCardShadow = [
  BoxShadow(
    color: Color(0x18000000),
    blurRadius: 14,
    spreadRadius: 0,
    offset: Offset(0, 4),
  ),
  BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 1)),
];

/// Queue # — bold accent (rose-gold family).
const Color _kPremiumQueueAccent = Color(0xFFC45C6A);

/// Past / archived rows and dialogs: faded so active bookings read first.
const double _kArchivedBookingOpacity = 0.68;

Color _desaturatedArchivedGold(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation((hsl.saturation * 0.58).clamp(0.0, 1.0))
      .withLightness((hsl.lightness * 0.97).clamp(0.0, 1.0))
      .toColor();
}

LinearGradient _archivedPastBookingCardGradient() => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    _desaturatedArchivedGold(const Color(0xFFF5E6CA)),
    _desaturatedArchivedGold(const Color(0xFFD4A373)),
    _desaturatedArchivedGold(const Color(0xFFA98467)),
  ],
  stops: const [0.0, 0.5, 1.0],
);

const Color _kPastBookingTextBrown = Color(0xFF432818);

const Color _kPastBookingNumberInk = Color(0xFF1A120E);

/// Past booking detail dialog: perforation + depth (matte gold card).
const Color _kPastTicketDialogHoleBlend = Color(0xFF7D5A44);

const List<BoxShadow> _kPastTicketDialogOuterShadows = [
  BoxShadow(
    color: Color(0x42FFFFFF),
    blurRadius: 18,
    spreadRadius: 0,
    offset: Offset(0, 0),
  ),
  BoxShadow(
    color: Color(0x5AA98467),
    blurRadius: 28,
    spreadRadius: 0,
    offset: Offset(0, 12),
  ),
  BoxShadow(
    color: Color(0x30000000),
    blurRadius: 20,
    spreadRadius: 0,
    offset: Offset(0, 8),
  ),
];

const List<Shadow> _kPastTicketPreviewTitleShadows = [
  Shadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1)),
];

/// Ticks periodically so “active vs past” updates when [DateTime.now] crosses a slot,
/// without relying on new Firestore snapshots.
Stream<DateTime> _patientAppointmentsUiClock() async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
    yield DateTime.now();
  }
}

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

final DateFormat _appointmentTime12h = DateFormat.jm('en_US');

/// Formats [AppointmentFields.time] for cards: **12-hour with AM/PM** (e.g. `7:00 PM`).
///
/// Supports common Firestore values like `19:00` / `09:30` / `9:30:00`. If the string
/// already includes AM/PM, it is normalized via [DateFormat.jm]. Unrecognized values
/// are returned unchanged.
String _formatAppointmentTimeForDisplay(dynamic timeVal) {
  final raw = (timeVal ?? '').toString().trim();
  if (raw.isEmpty || raw == '—') return '—';

  final lower = raw.toLowerCase();
  if (lower.contains('am') || lower.contains('pm')) {
    for (final pattern in <DateFormat>[
      DateFormat('h:mm a', 'en_US'),
      DateFormat('hh:mm a', 'en_US'),
      DateFormat('h:mm:ss a', 'en_US'),
    ]) {
      try {
        final parsed = pattern.parse(raw);
        return _appointmentTime12h.format(
          DateTime(2000, 1, 1, parsed.hour, parsed.minute),
        );
      } catch (_) {
        continue;
      }
    }
  }

  final m24 = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(raw);
  if (m24 != null) {
    final rest = raw.substring(m24.end).trim();
    if (rest.isEmpty) {
      final h = int.parse(m24.group(1)!).clamp(0, 23);
      final min = int.parse(m24.group(2)!);
      return _appointmentTime12h.format(DateTime(2000, 1, 1, h, min));
    }
  }

  return raw;
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
    return _appointmentTimeSortMinutes(
      b.data()[AppointmentFields.time],
    ).compareTo(_appointmentTimeSortMinutes(a.data()[AppointmentFields.time]));
  });
}

String _normAppointmentStatus(dynamic raw) =>
    (raw ?? 'pending').toString().trim().toLowerCase();

bool _isPastAppointmentStatus(String st) =>
    st == 'completed' ||
    st == 'cancelled' ||
    st == 'canceled' ||
    st == 'expired';

/// Status string shown on cards / dialogs when the slot time has passed but Firestore
/// has not yet been updated to `expired`.
String _effectivePatientAppointmentStatusForUi(
  Map<String, dynamic> data,
  DateTime now,
) {
  final st = _normAppointmentStatus(data[AppointmentFields.status]);
  if (_isPastAppointmentStatus(st)) return st;
  if (st == 'completed' || st == 'complete' || st == 'done') return st;
  if (st == 'available' || st == 'rejected') return st;
  final instant = appointmentSlotDateTimeForStaffSort(data);
  if (!instant.isAfter(now) &&
      (st == 'pending' ||
          st == 'waiting' ||
          st == 'booked' ||
          st == 'confirmed' ||
          st == 'arrived')) {
    return 'expired';
  }
  return st;
}

/// Active list: soonest slot first (chronological).
void _sortActiveAppointmentsForDisplay(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
) {
  list.sort((a, b) {
    final ia = appointmentSlotDateTimeForStaffSort(a.data());
    final ib = appointmentSlotDateTimeForStaffSort(b.data());
    final c = ia.compareTo(ib);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
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
        foreground: _kBookingsRoseTop,
        background: _kBookingsRoseBottom.withValues(alpha: 0.22),
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
  const _TicketTearRow({required this.holeColor, required this.dashColor});

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
  String status, {
  String? cancellationReason,
}) {
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
    if (cancellationReason == kAppointmentCancellationReasonClinicClosed) {
      return (
        const Color(0xFFC62828),
        kAppointmentStatusPendingFg,
        tr.translate('patient_appt_status_cancelled_clinic_closed'),
      );
    }
    if (cancellationReason == kAppointmentCancellationReasonDoctorDayClosed) {
      return (
        const Color(0xFFC62828),
        kAppointmentStatusPendingFg,
        tr.translate('patient_appt_status_cancelled_by_doctor'),
      );
    }
    return (
      const Color(0xFFC62828),
      kAppointmentStatusPendingFg,
      tr.translate('status_cancelled'),
    );
  }
  if (s == 'expired') {
    return (
      const Color(0xFF546E7A),
      Colors.white,
      tr.translate('status_expired'),
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
  if (s == 'waiting') {
    final c = appointmentStatusBadgeColors('pending');
    return (c.$1, c.$2, tr.translate('status_pending'));
  }
  final c = appointmentStatusBadgeColors('pending');
  return (c.$1, c.$2, tr.translate('status_pending'));
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
    required this.createdAt,
    required this.now,
    required this.onCancel,
    this.cancellationReason = '',
    this.isPast = false,
  });

  final String queueLabel;
  final String doctorName;
  final String specialty;
  final String patientName;
  final String dateStr;
  final String timeStr;
  final String status;
  final DateTime? createdAt;
  final DateTime now;
  final VoidCallback? onCancel;
  final String cancellationReason;
  final bool isPast;

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
      if (cancellationReason == kAppointmentCancellationReasonClinicClosed) {
        return (
          tr.translate('patient_appt_status_cancelled_clinic_closed'),
          const Color(0xFFFFEBEE),
          const Color(0xFFB71C1C),
        );
      }
      if (cancellationReason == kAppointmentCancellationReasonDoctorDayClosed) {
        return (
          tr.translate('patient_appt_status_cancelled_by_doctor'),
          const Color(0xFFFFEBEE),
          const Color(0xFFB71C1C),
        );
      }
      return (
        tr.translate('status_cancelled'),
        const Color(0xFFFFEBEE),
        const Color(0xFFB71C1C),
      );
    }
    if (s == 'expired') {
      return (
        tr.translate('status_expired'),
        const Color(0xFFECEFF1),
        const Color(0xFF546E7A),
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
    if (s == 'waiting') {
      return (
        tr.translate('status_pending'),
        kAppointmentStatusPendingBg,
        kAppointmentStatusPendingFg,
      );
    }
    return (
      tr.translate('status_pending'),
      kAppointmentStatusPendingBg,
      kAppointmentStatusPendingFg,
    );
  }

  IconData _statusIconFor(String stNorm) {
    switch (stNorm) {
      case 'pending':
      case 'waiting':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.event_available_outlined;
      case 'arrived':
        return Icons.local_hospital_outlined;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel_outlined;
      case 'expired':
        return Icons.event_busy_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  (Color bg, Color fg) _modernChipSurface(String stNorm) {
    switch (stNorm) {
      case 'pending':
      case 'waiting':
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case 'confirmed':
        return (const Color(0xFFE8EAF6), const Color(0xFF283593));
      case 'arrived':
        return (const Color(0xFFFFF3E0), const Color(0xFFBF360C));
      case 'completed':
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case 'cancelled':
      case 'canceled':
        return (const Color(0xFFFFEBEE), const Color(0xFFC62828));
      case 'expired':
        return (const Color(0xFFECEFF1), const Color(0xFF546E7A));
      default:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(context);
    final stNorm = _normAppointmentStatus(status);
    final lineThroughDoctor = stNorm == 'cancelled' || stNorm == 'canceled';
    final isExpired = stNorm == 'expired';

    final muted = isPast;
    final subColor = muted ? const Color(0xFF78909C) : const Color(0xFF78909C);

    /// Doctor name in header — primary emphasis (top row with queue badge).
    final doctorHeaderColor = muted
        ? const Color(0xFF455A64)
        : kPatientNavyText;

    /// Patient name — centered below date/time (separate from doctor header).
    final patientCenterColor = muted
        ? const Color(0xFF455A64)
        : const Color(0xFF0D2137);

    /// Date/time row — darker & bolder than secondary meta labels.
    final dateTimeTextColor = muted
        ? const Color(0xFF455A64)
        : const Color(0xFF263238);
    final dateTimeIconColor = muted
        ? const Color(0xFF607D8B)
        : const Color(0xFF455A64);
    final metaGrey = const Color(0xFF90A4AE);
    final chipSurface = _modernChipSurface(stNorm);
    final statusIcon = _statusIconFor(stNorm);

    final surfaceColor = muted
        ? _kBookingCardPastSurface
        : _kBookingCardActiveTint;
    final barColor = muted ? const Color(0xFFB0BEC5) : _kBookingCardPrimaryBlue;

    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipSurface.$1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: chipSurface.$2.withValues(alpha: 0.22),
          width: 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: ui.TextDirection.rtl,
        children: [
          Text(
            statusStyle.$1,
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 10.75,
              height: 1.2,
              color: chipSurface.$2,
            ),
          ),
          const SizedBox(width: 5),
          Icon(statusIcon, size: 13, color: chipSurface.$2),
        ],
      ),
    );

    final bool cancelWindowOk =
        createdAt != null &&
        now.difference(createdAt!) < const Duration(hours: 2);
    final bool canShowCancelAction =
        onCancel != null &&
        !isPast &&
        !isExpired &&
        stNorm != 'completed' &&
        stNorm != 'cancelled' &&
        stNorm != 'canceled' &&
        stNorm != 'expired';

    final queueDigits = queueLabel.startsWith('#')
        ? queueLabel.substring(1)
        : queueLabel;

    final queueBadge = Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: muted ? const Color(0xFFECEFF1) : const Color(0xFFE8F4FC),
        border: Border.all(
          color: muted
              ? const Color(0xFFCFD8DC)
              : _kBookingCardPrimaryBlue.withValues(alpha: 0.22),
          width: 1.25,
        ),
        boxShadow: [
          BoxShadow(
            color: _kBookingCardPrimaryBlue.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        queueDigits,
        style: TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w900,
          fontSize: 24,
          height: 1,
          letterSpacing: 0.2,
          color: muted
              ? _kPremiumQueueAccent.withValues(alpha: 0.55)
              : _kBookingCardPrimaryBlue,
        ),
      ),
    );

    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: ui.TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      doctorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 18.5,
                        height: 1.15,
                        color: doctorHeaderColor,
                        decoration: lineThroughDoctor
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: doctorHeaderColor.withValues(
                          alpha: 0.5,
                        ),
                        decorationThickness: 1.1,
                      ),
                    ),
                    if (specialty.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                          color: subColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              queueBadge,
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: metaGrey.withValues(alpha: muted ? 0.22 : 0.35),
          ),
          // Date + calendar on the LEFT; time + clock on the RIGHT (same styles as before).
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: ui.TextDirection.ltr,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: dateTimeIconColor.withValues(alpha: 0.92),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        height: 1.2,
                        color: dateTimeTextColor.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: ui.TextDirection.rtl,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 24,
                      color: dateTimeIconColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                        height: 1.15,
                        color: dateTimeTextColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Patient — one compact RTL row (name + icon) centered; avoid [Expanded] so
          // the pair doesn't stretch to opposite edges of the card.
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: ui.TextDirection.rtl,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (MediaQuery.sizeOf(context).width * 0.58).clamp(
                        120.0,
                        300.0,
                      ),
                    ),
                    child: Text(
                      patientName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.25,
                        color: patientCenterColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: patientCenterColor.withValues(alpha: 0.88),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: statusChip),
          const SizedBox(height: 10),
          if (canShowCancelAction && cancelWindowOk)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 32,
                child: FilledButton(
                  onPressed: onCancel,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFB91C1C,
                    ).withValues(alpha: 0.88),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    S
                        .of(context)
                        .translate('schedule_slot_cancel_appointment_short'),
                    style: const TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            )
          else if (canShowCancelAction && !cancelWindowOk)
            Text(
              S
                  .of(context)
                  .translate('patient_cancel_window_expired_contact_secretary'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
                color: const Color(0xFF94A3B8).withValues(alpha: 0.95),
              ),
            ),
          if (isExpired) ...[
            const SizedBox(height: 8),
            Text(
              S.of(context).translate('patient_appt_expired_label'),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: metaGrey.withValues(alpha: 0.95),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );

    Widget card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kPremiumBookingCardRadius),
        boxShadow: _kPremiumBookingCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kPremiumBookingCardRadius),
        // ListView children get unbounded max height; [IntrinsicHeight] gives this
        // [Row] a finite height so [CrossAxisAlignment.stretch] cannot be infinite.
        child: IntrinsicHeight(
          child: Row(
            textDirection: ui.TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(color: surfaceColor, child: inner),
              ),
              Container(width: 5, color: barColor),
            ],
          ),
        ),
      ),
    );

    const greyscale = ColorFilter.matrix(<double>[
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);

    if (isExpired) {
      return ColorFiltered(
        colorFilter: greyscale,
        child: Opacity(opacity: 0.6, child: card),
      );
    }
    if (isPast) {
      return ColorFiltered(
        colorFilter: greyscale,
        child: Opacity(opacity: _kArchivedBookingOpacity, child: card),
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
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: _kBookingsRoseBarGradient,
            boxShadow: [
              BoxShadow(
                color: _kBookingsRoseSolid.withValues(alpha: 0.42),
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
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.bold,
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
    this.cancellationReason = '',
    required this.queueLabel,
    required this.daysStyle,
    required this.holeColor,
    required this.isPreview,
    this.archivedAppearance = false,
  });

  final String doctorName;
  final String patientName;
  final String dateStr;
  final String timeStr;
  final String status;
  final String cancellationReason;
  final String queueLabel;
  final _DaysRemainingStyle? daysStyle;
  final Color holeColor;
  final bool isPreview;

  /// Muted ticket in detail dialog (past / archived bookings).
  final bool archivedAppearance;

  static const Color _ticketBg = Color(0xFF1E1E2C);
  static const Color _ticketBorder = Color(0xFF3D3D52);
  static const Color _doctorAccent = _kBookingsRoseTop;
  static const Color _labelDim = Color(0xFF8B95A8);
  static const Color _bodyLight = Color(0xFFECEFF4);
  static const Color _bodyMuted = Color(0xFFC5CBD6);
  static const Color _queueLight = Color(0xFF81D4FA);
  static const Color _dashSubtle = Color(0xFF4A4A5E);

  @override
  Widget build(BuildContext context) {
    final badge = _appointmentStatusBadge(
      context,
      status,
      cancellationReason: cancellationReason.trim().isEmpty
          ? null
          : cancellationReason.trim(),
    );
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;
    final textEnd = isRtl ? TextAlign.right : TextAlign.left;
    final rowDir = Directionality.of(context);
    final r = BorderRadius.circular(isPreview ? 16 : 12);
    final innerR = BorderRadius.circular(isPreview ? 15 : 11);
    final ticketFont = isPreview ? kAppFontFamily : kPatientPrimaryFont;

    final double doctorSize = isPreview ? 20 : 13;
    final int doctorMaxLines = isPreview ? 3 : 1;
    final double queueSize = isPreview ? 40 : 30;
    final double labelSize = isPreview ? 12 : 10;
    final double bodyMutedSize = isPreview ? 15 : 12.5;
    final double patientSize = isPreview ? 16 : 13;
    final double badgeFont = isPreview ? 9.5 : 9;
    final EdgeInsets headerPad = isPreview
        ? const EdgeInsets.fromLTRB(13, 11, 13, 7)
        : const EdgeInsets.fromLTRB(12, 10, 12, 6);
    final EdgeInsets footerPad = isPreview
        ? const EdgeInsets.fromLTRB(13, 7, 13, 11)
        : const EdgeInsets.fromLTRB(12, 6, 12, 12);
    final double queueVPad = isPreview ? 7 : 6;
    final double daysChipFont = isPreview ? 12 : 10;

    final effectiveHole = isPreview ? _kPastTicketDialogHoleBlend : holeColor;
    final effectiveDash = isPreview
        ? _kPastBookingTextBrown.withValues(alpha: 0.32)
        : _dashSubtle;
    final labelMuted = isPreview
        ? _kPastBookingTextBrown.withValues(alpha: 0.78)
        : _labelDim;
    final ticketColumn = Column(
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
                              color: labelMuted,
                              fontFamily: ticketFont,
                              fontSize: labelSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            S.of(context).translate('ticket_doctor_label'),
                            textAlign: textEnd,
                            style: TextStyle(
                              color: labelMuted,
                              fontFamily: ticketFont,
                              fontSize: labelSize * 0.92,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctorName,
                            textAlign: textEnd,
                            maxLines: doctorMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPreview
                                  ? _kPastBookingTextBrown
                                  : _doctorAccent,
                              fontFamily: ticketFont,
                              fontWeight: FontWeight.w700,
                              fontSize: doctorSize,
                              height: 1.25,
                              shadows: isPreview
                                  ? _kPastTicketPreviewTitleShadows
                                  : const <Shadow>[
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
                                fontFamily: ticketFont,
                                fontWeight: FontWeight.w700,
                                fontSize: doctorSize,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(width: isPreview ? 7 : 6),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isPreview ? 6 : 6,
                  vertical: isPreview ? 3 : 2,
                ),
                decoration: BoxDecoration(
                  color: badge.$1,
                  borderRadius: BorderRadius.circular(isPreview ? 8 : 6),
                  border: Border.all(
                    color: isPreview
                        ? _kPastBookingTextBrown.withValues(alpha: 0.35)
                        : badge.$2.withValues(alpha: 0.35),
                    width: isPreview ? 0.85 : 0.7,
                  ),
                ),
                child: Text(
                  badge.$3,
                  style: TextStyle(
                    color: badge.$2,
                    fontFamily: ticketFont,
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
          padding: EdgeInsets.symmetric(horizontal: isPreview ? 10 : 10),
          child: _TicketTearRow(
            holeColor: effectiveHole,
            dashColor: effectiveDash,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: queueVPad),
          child: Center(
            child: Text(
              queueLabel,
              style: TextStyle(
                fontFamily: ticketFont,
                color: isPreview ? _kPastBookingNumberInk : _queueLight,
                fontSize: queueSize,
                fontWeight: FontWeight.w700,
                letterSpacing: isPreview ? 1.2 : 0.5,
                height: 1,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isPreview ? 10 : 10),
          child: _TicketTearRow(
            holeColor: effectiveHole,
            dashColor: effectiveDash,
          ),
        ),
        Padding(
          padding: footerPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPreview) ...[
                Text.rich(
                  textAlign: textEnd,
                  TextSpan(
                    style: TextStyle(
                      fontFamily: ticketFont,
                      fontSize: bodyMutedSize * 0.95,
                      height: 1.22,
                      fontWeight: FontWeight.w700,
                      color: _kPastBookingTextBrown.withValues(alpha: 0.88),
                    ),
                    children: [
                      TextSpan(
                        text: '${S.of(context).translate('ticket_date')}: ',
                      ),
                      TextSpan(
                        text: dateStr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kPastBookingNumberInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  textAlign: textEnd,
                  TextSpan(
                    style: TextStyle(
                      fontFamily: ticketFont,
                      fontSize: bodyMutedSize * 0.95,
                      height: 1.22,
                      fontWeight: FontWeight.w700,
                      color: _kPastBookingTextBrown.withValues(alpha: 0.88),
                    ),
                    children: [
                      TextSpan(
                        text: '${S.of(context).translate('ticket_time')}: ',
                      ),
                      TextSpan(
                        text: timeStr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kPastBookingNumberInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  textAlign: textEnd,
                  TextSpan(
                    style: TextStyle(
                      fontFamily: ticketFont,
                      fontSize: patientSize * 0.95,
                      height: 1.22,
                      fontWeight: FontWeight.w700,
                      color: _kPastBookingTextBrown.withValues(alpha: 0.88),
                    ),
                    children: [
                      TextSpan(
                        text: '${S.of(context).translate('ticket_patient')}: ',
                      ),
                      TextSpan(
                        text: patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kPastBookingNumberInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  '${S.of(context).translate('ticket_date')}: $dateStr',
                  textAlign: textEnd,
                  style: TextStyle(
                    color: _bodyMuted,
                    fontFamily: ticketFont,
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
                    fontFamily: ticketFont,
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
                    fontFamily: ticketFont,
                    fontSize: patientSize,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
              ],
              if (daysStyle != null) ...[
                SizedBox(height: isPreview ? 7 : 6),
                Align(
                  alignment: isRtl
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isPreview ? 7 : 8,
                      vertical: isPreview ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isPreview
                          ? _kPastBookingTextBrown.withValues(alpha: 0.08)
                          : daysStyle!.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPreview
                            ? _kPastBookingTextBrown.withValues(alpha: 0.28)
                            : daysStyle!.foreground.withValues(alpha: 0.35),
                        width: isPreview ? 0.85 : 1,
                      ),
                    ),
                    child: Text(
                      daysStyle!.label,
                      style: TextStyle(
                        color: isPreview
                            ? _kPastBookingTextBrown
                            : daysStyle!.foreground,
                        fontFamily: ticketFont,
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
        if (isPreview) const SizedBox(height: 20),
      ],
    );

    if (!isPreview) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _ticketBg,
          borderRadius: r,
          border: Border.all(color: _ticketBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -6,
            ),
            BoxShadow(
              color: const Color(0xFF64B5F6).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: innerR, child: ticketColumn),
      );
    }

    final previewGradient = archivedAppearance
        ? _archivedPastBookingCardGradient()
        : _kPastBookingCardGradient;

    final previewTicket = Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: _kPastTicketDialogOuterShadows,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Container(
          decoration: BoxDecoration(
            gradient: previewGradient,
            borderRadius: r,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.42),
              width: 1.0,
            ),
          ),
          child: ticketColumn,
        ),
      ),
    );

    if (archivedAppearance) {
      return Opacity(opacity: _kArchivedBookingOpacity, child: previewTicket);
    }
    return previewTicket;
  }
}

/// Ticket inside modal — blur + transitions are composed in [_openTicketPreview].
class _AppointmentDetailCard extends StatelessWidget {
  const _AppointmentDetailCard({
    required this.heroTag,
    required this.doctorName,
    required this.patientName,
    required this.dateStr,
    required this.timeStr,
    required this.status,
    this.cancellationReason = '',
    required this.queueLabel,
    required this.daysStyle,
    required this.holeColor,
    required this.isPastBooking,
  });

  final String heroTag;
  final String doctorName;
  final String patientName;
  final String dateStr;
  final String timeStr;
  final String status;
  final String cancellationReason;
  final String queueLabel;
  final _DaysRemainingStyle? daysStyle;
  final Color holeColor;
  final bool isPastBooking;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padBottom = MediaQuery.paddingOf(context).bottom;
    final maxPanelW = size.width * 0.85;
    final maxPanelH = size.height * 0.70;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxPanelW, maxHeight: maxPanelH),
        child: SingleChildScrollView(
          clipBehavior: Clip.hardEdge,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(top: 8, bottom: 12 + padBottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxPanelW),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Hero(
                  tag: heroTag,
                  child: Material(
                    type: MaterialType.transparency,
                    color: Colors.transparent,
                    clipBehavior: Clip.none,
                    child: _TicketVisual(
                      doctorName: doctorName,
                      patientName: patientName,
                      dateStr: dateStr,
                      timeStr: timeStr,
                      status: status,
                      cancellationReason: cancellationReason,
                      queueLabel: queueLabel,
                      daysStyle: daysStyle,
                      holeColor: holeColor,
                      isPreview: true,
                      archivedAppearance: isPastBooking,
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
}

Widget _appointmentDetailTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
  final scale = Tween<double>(
    begin: 0.9,
    end: 1.0,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));

  return Directionality(
    textDirection: AppLocaleScope.of(context).textDirection,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: fade,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          maintainBottomViewPadding: true,
          child: Center(
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void _openTicketPreview(
  BuildContext context, {
  required String heroTag,
  required String doctorName,
  required String patientName,
  required String dateStr,
  required String timeStr,
  required String status,
  String cancellationReason = '',
  required String queueLabel,
  required _DaysRemainingStyle? daysStyle,
  required Color holeColor,
  required bool isPastBooking,
}) {
  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: _appointmentDetailTransition,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _AppointmentDetailCard(
        heroTag: heroTag,
        doctorName: doctorName,
        patientName: patientName,
        dateStr: dateStr,
        timeStr: timeStr,
        status: status,
        cancellationReason: cancellationReason,
        queueLabel: queueLabel,
        daysStyle: daysStyle,
        holeColor: holeColor,
        isPastBooking: isPastBooking,
      );
    },
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
  static const Color _historyTitleNavy = Color(0xFF1A237E);
  static const Color _historyChipSelectedBg = Color(0xFF1A237E);
  static const Color _historyChipUnselectedBorder = Color(0xFFEEEEEE);
  static const Color _historyChipUnselectedText = Color(0xFF607D8B);

  /// Matches light sky background so ticket hero perforation blends with the page.
  Color get _holeColor => kPatientSkyTop;
  Color get _uiAccent =>
      widget.embedded ? const Color(0xFF1976D2) : kPatientDeepBlue;
  Color get _uiMuted => _onLightMuted;

  /// Monthly filter for previous appointments.
  /// This is purely local filtering to avoid Firestore index requirements.
  String _selectedPastMonth = 'All';

  Timer? _highlightTimer;
  bool _highlightActive = false;

  /// Prevents showing the "doctor closed day" alert repeatedly for the same appointment.
  final Set<String> _doctorClosedAlertedApptIds = <String>{};
  final Map<String, String> _lastStatusByApptId = <String, String>{};

  /// Prevents repeated writes for the same outdated appointment.
  final Set<String> _expiredWriteAttemptedApptIds = <String>{};
  bool _expireWriteInFlight = false;

  DateTime? _parseCreatedAt(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  Future<void> _cancelAppointmentIfAllowed({
    required BuildContext context,
    required String appointmentDocId,
    required Map<String, dynamic> priorData,
    required DateTime now,
  }) async {
    final tr = S.of(context);
    final createdAt = _parseCreatedAt(priorData[AppointmentFields.createdAt]);
    final withinWindow =
        createdAt != null &&
        now.difference(createdAt) < const Duration(hours: 2);
    if (!withinWindow) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr.translate('patient_cancel_window_expired_contact_secretary'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
      return;
    }

    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, sec) {
        return _ModernConfirmDialog(
          title: tr.translate('schedule_are_you_sure'),
          message: tr.translate('schedule_slot_cancel_confirm_title'),
          confirmText: tr.translate('schedule_slot_cancel_yes'),
          cancelText: tr.translate('schedule_slot_cancel_no'),
          confirmColor: const Color(0xFFB91C1C),
          icon: Icons.warning_amber_rounded,
          cancelDeadline: createdAt.add(const Duration(hours: 2)),
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
    if (ok != true || !context.mounted) return;

    try {
      await archivePatientCancelledAppointmentAndFreeSlot(
        appointmentRef: FirebaseFirestore.instance
            .collection(AppointmentFields.collection)
            .doc(appointmentDocId),
        priorData: priorData,
      );
      await AppointmentLocalNotifications.cancelAppointmentAlerts(
        appointmentDocId,
      );
      await AppointmentReminderWorker.removeBooking(appointmentDocId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr.translate('patient_cancel_ok_snack'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr.translate('patient_cancel_error_snack'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(AppointmentLocalNotifications.requestPermissions());
    _highlightActive = (widget.highlightAvailableDayDocId ?? '')
        .trim()
        .isNotEmpty;
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

  void _maybeShowDoctorClosedAlert(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    for (final d in docs) {
      final id = d.id;
      final data = d.data();
      final status = _normAppointmentStatus(data[AppointmentFields.status]);
      final cancelReason = (data[AppointmentFields.cancellationReason] ?? '')
          .toString()
          .trim();

      final last = _lastStatusByApptId[id];
      _lastStatusByApptId[id] = status;

      final becameCancelledByDoctor =
          (status == 'cancelled' || status == 'canceled') &&
          last != status &&
          cancelReason == kAppointmentCancellationReasonDoctorDayClosed;

      if (!becameCancelledByDoctor) continue;
      if (_doctorClosedAlertedApptIds.contains(id)) continue;
      _doctorClosedAlertedApptIds.add(id);

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            S.of(context).translate('patient_appt_cancelled_by_doctor_alert'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
      break;
    }
  }

  Future<void> _maybeExpireOutdatedAppointments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (!mounted) return;
    if (_expireWriteInFlight) return;

    final now = DateTime.now();

    final toExpire = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in docs) {
      if (_expiredWriteAttemptedApptIds.contains(d.id)) continue;
      final data = d.data();
      final st = _normAppointmentStatus(data[AppointmentFields.status]);
      if (st == 'completed' || st == 'complete' || st == 'done') continue;
      if (st == 'cancelled' || st == 'canceled') continue;
      if (st == 'expired') continue;
      if (st == 'available' || st == 'rejected') continue;
      if (st != 'pending' &&
          st != 'waiting' &&
          st != 'booked' &&
          st != 'confirmed' &&
          st != 'arrived') {
        continue;
      }
      final instant = appointmentSlotDateTimeForStaffSort(data);
      if (instant.isAfter(now)) continue;
      toExpire.add(d);
    }

    if (toExpire.isEmpty) return;
    _expireWriteInFlight = true;

    try {
      // Batch in chunks to stay within Firestore limits.
      const chunkSize = 400;
      for (var i = 0; i < toExpire.length; i += chunkSize) {
        final slice = toExpire.skip(i).take(chunkSize).toList();
        final batch = FirebaseFirestore.instance.batch();
        for (final d in slice) {
          _expiredWriteAttemptedApptIds.add(d.id);
          batch.update(d.reference, {
            AppointmentFields.status: 'expired',
            AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (_) {
      // Best-effort: if rules block client writes, UI will still show day_expired badge,
      // but the DB won't be updated.
    } finally {
      _expireWriteInFlight = false;
    }
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
  _watchAppointmentsForUserId(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection(AppointmentFields.collection)
        .where(AppointmentFields.userId, isEqualTo: id)
        .snapshots()
        .map((e) => e.docs);
  }

  static const List<String> _kMonthLabels = <String>[
    'All',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  int? _monthNumberFromSelectedLabel(String label) {
    final i = _kMonthLabels.indexOf(label);
    if (i <= 0) return null;
    return i; // Jan=1 ... Dec=12
  }

  int? _monthNumberFromDoc(Map<String, dynamic> data) {
    final raw = data['month'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final s = raw.trim();
      final asInt = int.tryParse(s);
      if (asInt != null) return asInt;
      final idx = _kMonthLabels.indexOf(s);
      if (idx > 0) return idx;
    }
    return null;
  }

  Widget _pastMonthChipsBar(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: _kMonthLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _kMonthLabels[index];
          final selected = _selectedPastMonth == label;
          return FilterChip(
            label: Text(
              label,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: selected ? Colors.white : const Color(0xFF2B3440),
              ),
            ),
            selected: selected,
            onSelected: (_) {
              if (!mounted) return;
              setState(() => _selectedPastMonth = label);
            },
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: selected
                    ? Colors.transparent
                    : kPatientNavyText.withValues(alpha: 0.10),
              ),
            ),
            selectedColor: kPatientDeepBlue,
            backgroundColor: const Color(0xFFF1F5F9),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listBody = Builder(
      builder: (context) {
        final user = FirebaseAuth.instance.currentUser;
        final uid = (user?.uid ?? '').trim();
        if (uid.isEmpty) {
          return Center(
            child: Text(
              S.of(context).translate('appointments_need_login'),
              style: TextStyle(color: _uiMuted, fontFamily: 'NRT'),
            ),
          );
        }

        return StreamBuilder<DateTime>(
          stream: _patientAppointmentsUiClock(),
          initialData: DateTime.now(),
          builder: (context, clockSnap) {
            final now = clockSnap.data ?? DateTime.now();
            return StreamBuilder<
              List<QueryDocumentSnapshot<Map<String, dynamic>>>
            >(
              stream: _watchAppointmentsForUserId(uid),
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
                        S
                            .of(context)
                            .translate(
                              'error_with_details',
                              params: {'detail': '${snapshot.error}'},
                            ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontFamily: kPatientPrimaryFont,
                        ),
                      ),
                    ),
                  );
                }
                var docs =
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                      snapshot.data ?? [],
                    );
                final activeDocs =
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                for (final d in docs) {
                  final data = d.data();
                  final st = _normAppointmentStatus(
                    data[AppointmentFields.status],
                  );
                  final instant = appointmentSlotDateTimeForStaffSort(data);
                  if (_isPastAppointmentStatus(st)) {
                    // handled below (past section)
                  } else if (instant.isAfter(now)) {
                    activeDocs.add(d);
                  } else {
                    // handled below (past section)
                  }
                }
                _sortActiveAppointmentsForDisplay(activeDocs);
                _maybeShowDoctorClosedAlert(docs);
                // Best-effort Firestore status → expired when slot time has passed.
                unawaited(_maybeExpireOutdatedAppointments(docs));

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
                                color: _kBookingsRoseSolid,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _kBookingsRoseTop.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.event_note_rounded,
                              size: 52,
                              color: _kBookingsRoseTop,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'هیچ نۆرەیەکت تۆمار نەکردووە',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kPatientNavyText.withValues(alpha: 0.92),
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final padBottom =
                    24 +
                    MediaQuery.paddingOf(context).bottom +
                    (widget.embedded ? 8 : 0);

                Widget buildCardForDoc(
                  QueryDocumentSnapshot<Map<String, dynamic>> docSnap, {
                  required int orderIndex,
                  required bool isPastSection,
                }) {
                  final data = docSnap.data();
                  final doctorName =
                      (data[AppointmentFields.doctorName] ??
                              data[AppointmentFields.doctorId] ??
                              '—')
                          .toString();
                  final patientName =
                      (data[AppointmentFields.patientName] ?? '—').toString();
                  final specialty = (data['doctorSpecialty'] ?? '—').toString();
                  final displayStatus = _effectivePatientAppointmentStatusForUi(
                    data,
                    now,
                  );
                  final stNorm = _normAppointmentStatus(displayStatus);
                  final timeStr = _formatAppointmentTimeForDisplay(
                    data[AppointmentFields.time],
                  );
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
                  final cancelReason =
                      (data[AppointmentFields.cancellationReason] ?? '')
                          .toString()
                          .trim();
                  final createdAt = _parseCreatedAt(
                    data[AppointmentFields.createdAt],
                  );
                  final docId = docSnap.id;
                  final heroTag = 'appointment_ticket_$docId';
                  final hlId = (widget.highlightAvailableDayDocId ?? '').trim();
                  final isHighlighted =
                      _highlightActive &&
                      hlId.isNotEmpty &&
                      ((data[AppointmentFields.availableDayDocId] ?? '')
                              .toString()
                              .trim() ==
                          hlId);
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
                        status: displayStatus,
                        cancellationReason: cancelReason,
                        queueLabel: queueLabel,
                        daysStyle: daysStyle,
                        holeColor: _holeColor,
                        isPastBooking:
                            isPastSection || _isPastAppointmentStatus(stNorm),
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Hero(
                        tag: heroTag,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              _kPremiumBookingCardRadius,
                            ),
                            border: isHighlighted
                                ? Border.all(
                                    color: const Color(0xFFD4A373),
                                    width: 1.4,
                                  )
                                : null,
                            boxShadow: isHighlighted
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFA98467,
                                      ).withValues(alpha: 0.38),
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
                              status: displayStatus,
                              createdAt: createdAt,
                              now: now,
                              onCancel: () => _cancelAppointmentIfAllowed(
                                context: context,
                                appointmentDocId: docId,
                                priorData: Map<String, dynamic>.from(data),
                                now: now,
                              ),
                              cancellationReason: cancelReason,
                              isPast: isPastSection,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final children = <Widget>[
                  _myBookingsSectionHeader('نۆرەی چالاک'),
                  const SizedBox(height: 10),
                  _MonthlyHistoryEntryButton(
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const MonthlyHistoryPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  if (activeDocs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        'هیچ نۆرەی چالاکت نییە',
                        style: TextStyle(
                          color: kPatientNavyText.withValues(alpha: 0.78),
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.bold,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _myBookingsSectionHeader('نۆرەکانی پێشوو'),
                        const SizedBox(height: 8),
                        _pastMonthChipsBar(context),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final allPastDocs =
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      for (final d in docs) {
                        if (activeDocs.any((e) => e.id == d.id)) continue;
                        final data = d.data();
                        final st = _normAppointmentStatus(
                          data[AppointmentFields.status],
                        );
                        final instant = appointmentSlotDateTimeForStaffSort(
                          data,
                        );
                        final isPast =
                            _isPastAppointmentStatus(st) ||
                            !instant.isAfter(now);
                        if (isPast) allPastDocs.add(d);
                      }

                      final selectedMonthNum = _monthNumberFromSelectedLabel(
                        _selectedPastMonth,
                      );
                      final filteredList = selectedMonthNum == null
                          ? allPastDocs
                          : allPastDocs
                                .where(
                                  (doc) =>
                                      _monthNumberFromDoc(doc.data()) ==
                                      selectedMonthNum,
                                )
                                .toList();

                      _sortPatientAppointmentsAll(filteredList);

                      if (filteredList.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'هیچ نۆرەی پێشووت نییە',
                            style: TextStyle(
                              color: kPatientNavyText.withValues(alpha: 0.72),
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (var j = 0; j < filteredList.length; j++)
                            buildCardForDoc(
                              filteredList[j],
                              orderIndex: j,
                              isPastSection: true,
                            ),
                        ],
                      );
                    },
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
      },
    );

    final body = listBody;

    final pageDir = AppLocaleScope.of(context).textDirection;
    final pageRtl = pageDir == ui.TextDirection.rtl;

    if (widget.embedded) {
      return Directionality(textDirection: pageDir, child: body);
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
          actions: [
            IconButton(
              tooltip: 'Test notification',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () async {
                await AppointmentLocalNotifications.scheduleTestAfter(
                  delay: const Duration(seconds: 5),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text(
                      'Test notification scheduled (5s).',
                      style: TextStyle(fontFamily: kPatientPrimaryFont),
                    ),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Test notification now',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () async {
                await AppointmentLocalNotifications.showTestNow();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text(
                      'Immediate test notification sent.',
                      style: TextStyle(fontFamily: kPatientPrimaryFont),
                    ),
                  ),
                );
              },
            ),
          ],
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
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.bold,
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

class _MonthlyHistoryEntryButton extends StatelessWidget {
  const _MonthlyHistoryEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: _PatientAppointmentsScreenState._historyTitleNavy,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'مێژووی مانگانە',
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _PatientAppointmentsScreenState._historyTitleNavy,
                  ),
                ),
              ),
              Icon(
                Directionality.of(context) == ui.TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: _PatientAppointmentsScreenState._onLightMuted.withValues(
                  alpha: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple month key (local calendar month).
class _MonthKey {
  const _MonthKey(this.year, this.month);
  final int year;
  final int month; // 1..12

  DateTime get startLocal => DateTime(year, month, 1);
  DateTime get endLocalExclusive => DateTime(year, month + 1, 1);

  @override
  bool operator ==(Object other) =>
      other is _MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

String _monthChipLabelKu(_MonthKey key) => 'مانگی ${key.month}';

class MonthlyHistoryPage extends StatefulWidget {
  const MonthlyHistoryPage({super.key});

  @override
  State<MonthlyHistoryPage> createState() => _MonthlyHistoryPageState();
}

class _MonthlyHistoryPageState extends State<MonthlyHistoryPage> {
  static const Color _titleNavy =
      _PatientAppointmentsScreenState._historyTitleNavy;
  static const Color _chipSelectedBg =
      _PatientAppointmentsScreenState._historyChipSelectedBg;
  static const Color _chipUnselectedBorder =
      _PatientAppointmentsScreenState._historyChipUnselectedBorder;
  static const Color _chipUnselectedText =
      _PatientAppointmentsScreenState._historyChipUnselectedText;

  _MonthKey _selected = _MonthKey(DateTime.now().year, DateTime.now().month);

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
    if (user != null) ids.addAll(_patientIdsForQueries(user));
    ids.removeWhere((e) => e.isEmpty);
    return ids;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchAppointments(
    Set<String> ids,
  ) {
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
          streams[i].listen((event) {
            latest[i] = event;
            emitMerged();
          }, onError: controller.addError),
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
    final pageDir = AppLocaleScope.of(context).textDirection;
    final pageRtl = pageDir == ui.TextDirection.rtl;

    final months = List<_MonthKey>.generate(
      12,
      (i) => _MonthKey(_selected.year, i + 1),
    );

    final selectedStart = _selected.startLocal;
    final selectedEnd = _selected.endLocalExclusive;

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
          title: const Text(
            'مێژووی مانگانە',
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _titleNavy,
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: FutureBuilder<Set<String>>(
            future: _resolvePatientIds(),
            builder: (context, idsSnap) {
              if (idsSnap.connectionState == ConnectionState.waiting &&
                  !idsSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _titleNavy),
                );
              }
              final ids = idsSnap.data ?? const <String>{};
              if (ids.isEmpty) {
                return Center(
                  child: Text(
                    S.of(context).translate('appointments_need_login'),
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      color: kPatientNavyText.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return StreamBuilder<DateTime>(
                stream: _patientAppointmentsUiClock(),
                initialData: DateTime.now(),
                builder: (context, clockSnap) {
                  final now = clockSnap.data ?? DateTime.now();
                  return StreamBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  >(
                    stream: _watchAppointments(ids),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: _titleNavy),
                        );
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              S
                                  .of(context)
                                  .translate(
                                    'error_with_details',
                                    params: {'detail': '${snap.error}'},
                                  ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontFamily: kPatientPrimaryFont,
                              ),
                            ),
                          ),
                        );
                      }

                      final docs =
                          List<
                            QueryDocumentSnapshot<Map<String, dynamic>>
                          >.from(snap.data ?? const []);

                      final inMonth =
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      for (final d in docs) {
                        final data = d.data();
                        final st = _normAppointmentStatus(
                          data[AppointmentFields.status],
                        );
                        // Monthly history focuses on past/terminal appointments.
                        if (!_isPastAppointmentStatus(st)) continue;
                        final day = _parseAppointmentDate(
                          data[AppointmentFields.date],
                        );
                        if (day == null) continue;
                        if (!day.isBefore(selectedStart) &&
                            day.isBefore(selectedEnd)) {
                          inMonth.add(d);
                        }
                      }
                      _sortPatientAppointmentsAll(inMonth);

                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          12,
                          14,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              itemCount: months.length,
                              separatorBuilder: (_, unused) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final key = months[i];
                                final isSelected = key.month == _selected.month;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() => _selected = key),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _chipSelectedBg
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.transparent
                                            : _chipUnselectedBorder,
                                        width: 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.14,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: Text(
                                      _monthChipLabelKu(key),
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : _chipUnselectedText,
                                        fontSize: 12.5,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (inMonth.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                'هیچ نۆرەیەک لەم مانگەدا نییە',
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  color: kPatientNavyText.withValues(
                                    alpha: 0.78,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < inMonth.length; i++)
                              _MonthlyHistoryAppointmentCard(
                                docSnap: inMonth[i],
                                index: i,
                                now: now,
                                holeColor: kPatientSkyTop,
                              ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MonthlyHistoryAppointmentCard extends StatelessWidget {
  const _MonthlyHistoryAppointmentCard({
    required this.docSnap,
    required this.index,
    required this.now,
    required this.holeColor,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> docSnap;
  final int index;
  final DateTime now;
  final Color holeColor;

  DateTime? _parseCreatedAt(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = docSnap.data();
    final doctorName =
        (data[AppointmentFields.doctorName] ??
                data[AppointmentFields.doctorId] ??
                '—')
            .toString();
    final patientName = (data[AppointmentFields.patientName] ?? '—').toString();
    final specialty = (data['doctorSpecialty'] ?? '—').toString();
    final displayStatus = _effectivePatientAppointmentStatusForUi(data, now);
    final stNorm = _normAppointmentStatus(displayStatus);
    final timeStr = _formatAppointmentTimeForDisplay(
      data[AppointmentFields.time],
    );
    final rawDate = data[AppointmentFields.date];
    final parsedDay = _parseAppointmentDate(rawDate);
    String dateStr = '—';
    if (parsedDay != null) {
      dateStr = DateFormat('yyyy/MM/dd').format(parsedDay);
    } else if (rawDate != null) {
      dateStr = rawDate.toString();
    }
    final daysStyle = parsedDay != null
        ? _DaysRemainingStyle.fromAppointmentDay(context, parsedDay)
        : null;
    final queueLabel = _appointmentQueueLabel(data, index);
    final cancelReason = (data[AppointmentFields.cancellationReason] ?? '')
        .toString()
        .trim();
    final createdAt = _parseCreatedAt(data[AppointmentFields.createdAt]);
    final docId = docSnap.id;
    final heroTag = 'monthly_history_$docId';

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
          status: displayStatus,
          cancellationReason: cancelReason,
          queueLabel: queueLabel,
          daysStyle: daysStyle,
          holeColor: holeColor,
          isPastBooking: _isPastAppointmentStatus(stNorm),
        ),
        behavior: HitTestBehavior.opaque,
        child: Hero(
          tag: heroTag,
          child: Material(
            color: Colors.transparent,
            child: _PremiumBookingCard(
              queueLabel: queueLabel,
              doctorName: doctorName,
              specialty: specialty,
              patientName: patientName,
              dateStr: dateStr,
              timeStr: timeStr,
              status: displayStatus,
              createdAt: createdAt,
              now: now,
              onCancel: null,
              cancellationReason: cancelReason,
              isPast: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen route after booking (back button). Same UI as [PatientAppointmentsScreen] standalone.
class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key, this.highlightAvailableDayDocId});

  final String? highlightAvailableDayDocId;

  @override
  Widget build(BuildContext context) => PatientAppointmentsScreen(
    embedded: false,
    highlightAvailableDayDocId: highlightAvailableDayDocId,
  );
}
