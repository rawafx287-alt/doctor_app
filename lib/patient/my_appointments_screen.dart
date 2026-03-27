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
        foreground: Color(0xFF90A4AE),
        background: Color(0x1FFFFFFF),
      );
    }
    if (diff == 0) {
      return const _DaysRemainingStyle(
        label: 'ئەمڕۆ',
        foreground: Color(0xFF42A5F5),
        background: Color(0x332CB1BC),
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
      foreground: const Color(0xFF4FC3F7),
      background: const Color(0x334FC3F7),
    );
  }
}

/// Patient view: نۆرەکانم — lists [appointments] for the signed-in user.
/// Set [embedded] to true when used inside [PatientHomeScreen] bottom tab (no [Scaffold]/[AppBar]).
class PatientAppointmentsScreen extends StatelessWidget {
  const PatientAppointmentsScreen({super.key, this.embedded = false});

  final bool embedded;

  static const Color _bg = Color(0xFF0A0E21);
  static const Color _card = Color(0xFF1D1E33);
  static const Color _teal = Color(0xFF42A5F5);
  static const Color _text = Color(0xFFD9E2EC);
  static const Color _muted = Color(0xFF829AB1);

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
                      style: const TextStyle(color: Colors.redAccent, fontFamily: 'KurdishFont'),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = sorted[index].data();
                  final doctorName = (data['doctorName'] ?? data['doctorId'] ?? '—').toString();
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
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          textDirection: kRtlTextDirection,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _teal.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status == 'pending'
                                    ? 'چاوەڕوان'
                                    : status == 'completed'
                                        ? 'تەواو'
                                        : status,
                                style: const TextStyle(
                                  color: _teal,
                                  fontFamily: 'KurdishFont',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.medical_services_rounded, color: _teal, size: 22),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          doctorName,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: _text,
                            fontFamily: 'KurdishFont',
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          textDirection: kRtlTextDirection,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'بەروار: $dateStr',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontFamily: 'KurdishFont',
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'کات: $timeStr',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontFamily: 'KurdishFont',
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (daysStyle != null) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: daysStyle.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: daysStyle.foreground.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  daysStyle.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: daysStyle.foreground,
                                    fontFamily: 'KurdishFont',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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
