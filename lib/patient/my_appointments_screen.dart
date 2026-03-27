import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
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
        foreground: Color(0xFF90A4AE),
        background: Color(0x1FFFFFFF),
      );
    }
    if (diff == 0) {
      return const _DaysRemainingStyle(
        label: 'ئەمڕۆ',
        foreground: Color(0xFF1565C0),
        background: Color(0x331565C0),
      );
    }
    if (diff == 1) {
      return const _DaysRemainingStyle(
        label: 'بەیانی',
        foreground: Color(0xFFFFB74D),
        background: Color(0x33FFB74D),
      );
    }
    return _DaysRemainingStyle(
      label: '$diff ڕۆژی ماوە',
      foreground: const Color(0xFF1976D2),
      background: const Color(0x331976D2),
    );
  }
}

/// Horizontal dashed line with side "punch" holes (ticket perforation).
class _TicketTearRow extends StatelessWidget {
  const _TicketTearRow({required this.holeColor});

  final Color holeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, 22),
            painter: _DashedLinePainter(color: const Color(0xFFB0BEC5)),
          ),
          PositionedDirectional(
            start: -11,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: holeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: -11,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 22,
                height: 22,
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
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    double x = 16;
    final y = size.height / 2;
    while (x < size.width - 16) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Digital ticket card with save-to-gallery.
class _DigitalTicketCard extends StatefulWidget {
  const _DigitalTicketCard({
    required this.doctorName,
    required this.patientName,
    required this.dateStr,
    required this.timeStr,
    required this.status,
    required this.queueLabel,
    required this.daysStyle,
    required this.holeColor,
  });

  final String doctorName;
  final String patientName;
  final String dateStr;
  final String timeStr;
  final String status;
  final String queueLabel;
  final _DaysRemainingStyle? daysStyle;
  final Color holeColor;

  @override
  State<_DigitalTicketCard> createState() => _DigitalTicketCardState();
}

class _DigitalTicketCardState extends State<_DigitalTicketCard> {
  final GlobalKey _repaintKey = GlobalKey();

  static const Color _ticketBg = Color(0xFFF5F7FA);
  static const Color _ticketBorder = Color(0xFFE2E8F0);

  (Color bg, Color fg, String label) get _badge {
    final s = widget.status.toLowerCase();
    if (s == 'completed') {
      return (
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
        'تەواو',
      );
    }
    if (s == 'cancelled' || s == 'canceled') {
      return (
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828),
        'هەڵوەشاوە',
      );
    }
    return (
      const Color(0xFFFFF8E1),
      const Color(0xFFF57F17),
      'چاوەڕوان',
    );
  }

  Future<void> _saveImage() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return;

    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(2.0, 3.5);

    try {
      final allowed = await Gal.hasAccess();
      if (!allowed) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'پێویستە مۆڵەتی گەلەری بدەیت',
                style: TextStyle(fontFamily: 'KurdishFont'),
              ),
            ),
          );
          return;
        }
      }

      final image = await boundary.toImage(pixelRatio: dpr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'HR_Nora_ticket_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'پاشەکەوت کرا لە گەلەری',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } on GalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هەڵە: ${e.type}',
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هەڵە لە پاشەکەوتکردن',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;

    return RepaintBoundary(
      key: _repaintKey,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _ticketBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _ticketBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 44, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          textDirection: kRtlTextDirection,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HR Nora',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.doctorName,
                                    textAlign: TextAlign.right,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1A237E),
                                      fontFamily: 'KurdishFont',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badge.$1,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: badge.$2.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                badge.$3,
                                style: TextStyle(
                                  color: badge.$2,
                                  fontFamily: 'KurdishFont',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _TicketTearRow(holeColor: widget.holeColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        widget.queueLabel,
                        style: TextStyle(
                          color: Colors.blueGrey.shade900,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _TicketTearRow(holeColor: widget.holeColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'بەروار: ${widget.dateStr}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.blueGrey.shade800,
                            fontFamily: 'KurdishFont',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'کات: ${widget.timeStr}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.blueGrey.shade800,
                            fontFamily: 'KurdishFont',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'نەخۆش: ${widget.patientName}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF0D47A1),
                            fontFamily: 'KurdishFont',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.daysStyle != null) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: widget.daysStyle!.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: widget.daysStyle!.foreground
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                widget.daysStyle!.label,
                                style: TextStyle(
                                  color: widget.daysStyle!.foreground,
                                  fontFamily: 'KurdishFont',
                                  fontSize: 11,
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
              PositionedDirectional(
                top: 6,
                end: 4,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    tooltip: 'پاشەکەوت وەک وێنە',
                    onPressed: _saveImage,
                    icon: Icon(
                      Icons.download_rounded,
                      color: Colors.blueGrey.shade600,
                      size: 22,
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

                  return _DigitalTicketCard(
                    doctorName: doctorName,
                    patientName: patientName,
                    dateStr: dateStr,
                    timeStr: timeStr,
                    status: status,
                    queueLabel: _queueLabel(data, index),
                    daysStyle: daysStyle,
                    holeColor: _bg,
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
