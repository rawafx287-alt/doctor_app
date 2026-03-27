import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_rtl.dart';

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

  static _DaysRemainingStyle fromAppointmentDay(DateTime appointmentDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = appointmentDay.difference(today).inDays;
    if (diff < 0) {
      return const _DaysRemainingStyle(
        label: 'کاتی بەسەرچووە',
        foreground: Color(0xFFB0BEC5),
        background: Color(0x28FFFFFF),
      );
    }
    if (diff == 0) {
      return const _DaysRemainingStyle(
        label: 'ئەمڕۆ',
        foreground: Color(0xFF81D4FA),
        background: Color(0x331565C0),
      );
    }
    if (diff == 1) {
      return const _DaysRemainingStyle(
        label: 'بەیانی',
        foreground: Color(0xFFFFCC80),
        background: Color(0x33FF9800),
      );
    }
    return _DaysRemainingStyle(
      label: '$diff ڕۆژی ماوە',
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

(Color bg, Color fg, String label) _appointmentStatusBadge(String status) {
  final s = status.toLowerCase();
  if (s == 'completed') {
    return (
      const Color(0x3322C55E),
      const Color(0xFFA5D6A7),
      'تەواو',
    );
  }
  if (s == 'cancelled' || s == 'canceled') {
    return (
      const Color(0x33EF5350),
      const Color(0xFFFFAB91),
      'هەڵوەشاوە',
    );
  }
  return (
    const Color(0x3364B5F6),
    const Color(0xFF90CAF9),
    'چاوەڕوان',
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
    final badge = _appointmentStatusBadge(status);
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
                textDirection: kRtlTextDirection,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: isPreview
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'HR Nora',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: _labelDim,
                                  fontSize: labelSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                doctorName,
                                textAlign: TextAlign.right,
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
                            textDirection: kRtlTextDirection,
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
                                  textAlign: TextAlign.right,
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
                    'بەروار: $dateStr',
                    textAlign: TextAlign.right,
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
                    'کات: $timeStr',
                    textAlign: TextAlign.right,
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
                    'نەخۆش: $patientName',
                    textAlign: TextAlign.right,
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
                      alignment: Alignment.centerRight,
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
      textDirection: kRtlTextDirection,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
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
                        label: const Text(
                          'داخستن',
                          style: TextStyle(
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
/// Set [embedded] to true when used inside [PatientHomeScreen] bottom tab (no [Scaffold]/[AppBar]).
class PatientAppointmentsScreen extends StatelessWidget {
  const PatientAppointmentsScreen({super.key, this.embedded = false});

  final bool embedded;

  static const Color _bg = Color(0xFF0A0E21);
  static const Color _teal = Color(0xFF42A5F5);
  static const Color _text = Color(0xFFD9E2EC);
  static const Color _muted = Color(0xFF829AB1);

  String _queueLabel(Map<String, dynamic> data, int fallbackIndex) {
    final q = data['queueNumber'];
    if (q is int && q > 0) {
      return '#${q.toString().padLeft(2, '0')}';
    }
    if (q is num && q > 0) {
      return '#${q.toInt().toString().padLeft(2, '0')}';
    }
    final h = (fallbackIndex + 1).toString().padLeft(2, '0');
    return '#$h';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final body = uid == null
        ? const Center(
            child: Text(
              'چوونەژوورەوە پێویستە',
              style: TextStyle(color: _muted, fontFamily: 'KurdishFont'),
            ),
          )
        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patientId', isEqualTo: uid)
                .snapshots(),
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
                      'هەڵە (${snapshot.error})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
              sorted.sort((a, b) {
                final da = a.data();
                final db = b.data();
                final ta = da['createdAt'];
                final tb = db['createdAt'];
                if (ta is Timestamp && tb is Timestamp) {
                  return tb.compareTo(ta);
                }
                final dateA = da['date'];
                final dateB = db['date'];
                if (dateA is Timestamp && dateB is Timestamp) {
                  return dateB.compareTo(dateA);
                }
                return 0;
              });

              if (sorted.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'هێشتا نۆرەیەک تۆمار نەکردووە.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                  final doctorName =
                      (data['doctorName'] ?? data['doctorId'] ?? '—').toString();
                  final patientName =
                      (data['patientName'] ?? '—').toString();
                  final status = (data['status'] ?? 'pending').toString();
                  final timeStr = (data['time'] ?? '—').toString();
                  final rawDate = data['date'];
                  final parsedDay = _parseAppointmentDate(rawDate);
                  String dateStr = '—';
                  if (parsedDay != null) {
                    dateStr = DateFormat.yMMMEd().format(parsedDay);
                  } else if (rawDate != null) {
                    dateStr = rawDate.toString();
                  }
                  final daysStyle = parsedDay != null
                      ? _DaysRemainingStyle.fromAppointmentDay(parsedDay)
                      : null;
                  final queueLabel = _queueLabel(data, index);
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

    if (embedded) {
      return Directionality(
        textDirection: kRtlTextDirection,
        child: ColoredBox(color: _bg, child: body),
      );
    }

    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: _text,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'گەڕانەوە',
          ),
          title: const Text(
            'نۆرەکانم',
            style: TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
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
