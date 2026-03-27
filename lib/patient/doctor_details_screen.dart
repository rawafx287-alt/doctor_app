import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_rtl.dart';
import 'my_appointments_screen.dart';

/// One day entry from [weekly_schedule] on the doctor's user document.
class _ScheduleDayEntry {
  const _ScheduleDayEntry({
    required this.id,
    required this.labelKu,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String id;
  final String labelKu;
  final int startMinutes;
  final int endMinutes;
}

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
    required this.doctorData,
  });

  final String doctorId;
  final Map<String, dynamic> doctorData;

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  String? _selectedDayId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;
  bool _hasAutoSelectedDay = false;

  static const List<String> _dayIds = [
    'saturday',
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

  @override
  void didUpdateWidget(covariant DoctorDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctorId != widget.doctorId) {
      _hasAutoSelectedDay = false;
      _selectedDayId = null;
      _selectedDate = null;
      _selectedTime = null;
    }
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  int _weekdayFromKey(String id) {
    switch (id) {
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      default:
        return DateTime.monday;
    }
  }

  /// Short Kurdish label when schedule has no custom [day] string.
  String _fallbackDayLabelKu(String id) {
    switch (id) {
      case 'saturday':
        return 'شەممە';
      case 'sunday':
        return 'یەکشەممە';
      case 'monday':
        return 'دووشەممە';
      case 'tuesday':
        return 'سێشەممە';
      case 'wednesday':
        return 'چوارشەممە';
      case 'thursday':
        return 'پێنجشەممە';
      case 'friday':
        return 'هەینی';
      default:
        return id;
    }
  }

  TimeOfDay _timeFromMinutes(int m) {
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String _formatMinutes(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  List<_ScheduleDayEntry> _parseSchedule(Map<String, dynamic>? weekly) {
    if (weekly == null || weekly.isEmpty) return [];
    final out = <_ScheduleDayEntry>[];
    for (final id in _dayIds) {
      final raw = weekly[id];
      if (raw is! Map) continue;
      if (raw['enabled'] != true) continue;
      final sm = _asInt(raw['startMinutes']);
      final em = _asInt(raw['endMinutes']);
      if (em <= sm) continue;
      final label = (raw['day'] ?? '').toString().trim();
      out.add(
        _ScheduleDayEntry(
          id: id,
          labelKu: label.isNotEmpty ? label : _fallbackDayLabelKu(id),
          startMinutes: sm,
          endMinutes: em,
        ),
      );
    }
    return out;
  }

  _ScheduleDayEntry? _entryFor(List<_ScheduleDayEntry> days, String id) {
    for (final d in days) {
      if (d.id == id) return d;
    }
    return null;
  }

  _ScheduleDayEntry? _selectedEntry(List<_ScheduleDayEntry> days) {
    if (_selectedDayId == null) return null;
    return _entryFor(days, _selectedDayId!);
  }

  /// Next [count] calendar dates matching [targetWeekday] (starting today).
  List<DateTime> _upcomingDatesForWeekday(int targetWeekday, int count) {
    final out = <DateTime>[];
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    final end = d.add(const Duration(days: 120));
    while (!d.isAfter(end) && out.length < count) {
      if (d.weekday == targetWeekday) {
        out.add(d);
      }
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  /// Start times every 30 minutes within the doctor's window.
  List<int> _slotStartMinutes(_ScheduleDayEntry day) {
    final list = <int>[];
    for (var m = day.startMinutes; m < day.endMinutes; m += 30) {
      list.add(m);
    }
    return list;
  }

  void _primeSelectionForDay(_ScheduleDayEntry day) {
    final dates = _upcomingDatesForWeekday(_weekdayFromKey(day.id), 8);
    _selectedDate = dates.isNotEmpty ? dates.first : null;
    final slots = _slotStartMinutes(day);
    _selectedTime = slots.isNotEmpty ? _timeFromMinutes(slots.first) : null;
  }

  Future<void> _confirmAppointment(
    String patientName,
    String doctorDisplayName,
    _ScheduleDayEntry? day,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (day == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تکایە ڕۆژ و کات هەڵبژێرە',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final timeStr =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      // Always persist the doctor's display name from Firestore (users.fullName), not only UI cache.
      var doctorNameToSave = doctorDisplayName.trim();
      try {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.doctorId)
            .get();
        final fromServer = (doctorDoc.data()?['fullName'] ?? '').toString().trim();
        if (fromServer.isNotEmpty) {
          doctorNameToSave = fromServer;
        }
      } catch (_) {
        /* use doctorDisplayName */
      }
      if (doctorNameToSave.isEmpty) {
        doctorNameToSave = 'پزیشک';
      }

      var queueNumber = 1;
      try {
        final d = _selectedDate!;
        final start = DateTime(d.year, d.month, d.day);
        final end = start.add(const Duration(days: 1));
        final countAgg = await FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: widget.doctorId)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(end))
            .count()
            .get();
        queueNumber = (countAgg.count ?? 0) + 1;
      } catch (_) {
        queueNumber = (DateTime.now().millisecondsSinceEpoch % 90) + 10;
      }

      await FirebaseFirestore.instance.collection('appointments').add({
        'patientId': uid,
        'doctorId': widget.doctorId,
        'doctorName': doctorNameToSave,
        'patientName': patientName,
        'date': Timestamp.fromDate(_selectedDate!),
        'time': timeStr,
        'status': 'pending',
        'queueNumber': queueNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: kRtlTextDirection,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'سەرکەوتوو',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'KurdishFont',
                color: Color(0xFFD9E2EC),
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'نۆرەکەت بە سەرکەوتوویی تۆمارکرا',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'KurdishFont',
                color: Color(0xFF829AB1),
                height: 1.4,
              ),
            ),
            actionsAlignment: MainAxisAlignment.start,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'باشە',
                  style: TextStyle(
                    color: Color(0xFF42A5F5),
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const MyAppointmentsScreen(),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هەڵە (${e.code})',
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هەڵە لە پاشەکەوتکردن: $e',
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doctorName = (widget.doctorData['fullName'] ?? 'پزیشک').toString();
    final specialty = (widget.doctorData['specialty'] ?? '—').toString();

    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'گەڕانەوە',
          ),
          title: Text(
            doctorName,
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.doctorId)
              .snapshots(),
          builder: (context, snap) {
            final merged = <String, dynamic>{
              ...widget.doctorData,
              if (snap.data?.data() != null) ...snap.data!.data()!,
            };
            final mergedSpecialty = (merged['specialty'] ?? specialty).toString();
            final doctorDisplayName = (merged['fullName'] ?? doctorName).toString();
            final profileImageUrl = (merged['profileImageUrl'] ?? '').toString().trim();
            final weekly = merged['weekly_schedule'];
            final scheduleDays = _parseSchedule(
              weekly is Map<String, dynamic> ? weekly : null,
            );

            if (!_hasAutoSelectedDay && scheduleDays.isNotEmpty) {
              _hasAutoSelectedDay = true;
              final first = scheduleDays.first;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _selectedDayId = first.id;
                  _primeSelectionForDay(first);
                });
              });
            }

            return uid == null
                ? const Center(
                    child: Text(
                      'چوونەژوورەوە پێویستە',
                      style: TextStyle(color: Color(0xFF829AB1), fontFamily: 'KurdishFont'),
                    ),
                  )
                : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                    builder: (context, patientSnap) {
                      final patientName =
                          (patientSnap.data?.data()?['fullName'] ?? 'نەخۆش').toString();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D1E33),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                textDirection: kRtlTextDirection,
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF42A5F5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        profileImageUrl.isNotEmpty
                                            ? profileImageUrl
                                            : _placeholderImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: const Color(0xFF1D1E33),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.medical_services_rounded,
                                            color: Color(0xFF42A5F5),
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'پسپۆڕی: $mergedSpecialty',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Color(0xFF829AB1),
                                        fontSize: 15,
                                        fontFamily: 'KurdishFont',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'نۆرەگرتن',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFFD9E2EC),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'KurdishFont',
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'ڕۆژەکانی کار (تەنها ئەوانەی پزیشک چالاکی کردووە)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFF829AB1),
                                fontSize: 12,
                                fontFamily: 'KurdishFont',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (scheduleDays.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D1E33),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Text(
                                  'ئەم پزیشکە هێشتا خشتەی کار تۆمار نەکردووە. دواتر هەوڵ بدەرەوە.',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Color(0xFF829AB1),
                                    fontFamily: 'KurdishFont',
                                    height: 1.4,
                                  ),
                                ),
                              )
                            else ...[
                              SizedBox(
                                height: 48,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _dayIds.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final id = _dayIds[index];
                                    final entry = _entryFor(scheduleDays, id);
                                    final available = entry != null;
                                    final selected =
                                        available && _selectedDayId == id;
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: switch (entry) {
                                          null => null,
                                          final e => () => setState(() {
                                                _selectedDayId = id;
                                                _primeSelectionForDay(e);
                                              }),
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !available
                                                ? const Color(0xFF1D1E33)
                                                    .withValues(alpha: 0.5)
                                                : selected
                                                    ? const Color(0xFF42A5F5)
                                                        .withValues(alpha: 0.28)
                                                    : const Color(0xFF1D1E33),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: !available
                                                  ? Colors.white12
                                                  : selected
                                                      ? const Color(0xFF42A5F5)
                                                      : Colors.white24,
                                              width: selected ? 2 : 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              switch (entry) {
                                                null => _fallbackDayLabelKu(id),
                                                final e => e.labelKu,
                                              },
                                              style: TextStyle(
                                                fontFamily: 'KurdishFont',
                                                fontWeight: selected
                                                    ? FontWeight.w800
                                                    : FontWeight.w500,
                                                fontSize: 13,
                                                color: !available
                                                    ? const Color(0xFF829AB1)
                                                        .withValues(alpha: 0.45)
                                                    : selected
                                                        ? const Color(0xFFD9E2EC)
                                                        : const Color(0xFF829AB1),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_selectedEntry(scheduleDays) != null) ...[
                                const SizedBox(height: 18),
                                Builder(
                                  builder: (context) {
                                    final day = _selectedEntry(scheduleDays)!;
                                    final dates =
                                        _upcomingDatesForWeekday(_weekdayFromKey(day.id), 8);
                                    final slots = _slotStartMinutes(day);

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'بەروار',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Color(0xFF829AB1),
                                            fontSize: 13,
                                            fontFamily: 'KurdishFont',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (dates.isEmpty)
                                          const Text(
                                            'بەروارێکی بەردەست نییە',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: Color(0xFF829AB1),
                                              fontFamily: 'KurdishFont',
                                            ),
                                          )
                                        else
                                          SizedBox(
                                            height: 42,
                                            child: ListView.separated(
                                              scrollDirection: Axis.horizontal,
                                              reverse: true,
                                              itemCount: dates.length,
                                              separatorBuilder: (_, _) =>
                                                  const SizedBox(width: 8),
                                              itemBuilder: (context, i) {
                                                final dt = dates[i];
                                                final sel = _selectedDate != null &&
                                                    _selectedDate!.year == dt.year &&
                                                    _selectedDate!.month == dt.month &&
                                                    _selectedDate!.day == dt.day;
                                                return FilterChip(
                                                  label: Text(
                                                    DateFormat.yMMMd().format(dt),
                                                    style: TextStyle(
                                                      fontFamily: 'KurdishFont',
                                                      fontWeight: sel
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color: sel
                                                          ? const Color(0xFF102A43)
                                                          : const Color(0xFFD9E2EC),
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  selected: sel,
                                                  onSelected: (_) {
                                                    setState(() => _selectedDate = dt);
                                                  },
                                                  selectedColor: const Color(0xFF42A5F5),
                                                  backgroundColor: const Color(0xFF1D1E33),
                                                  checkmarkColor: const Color(0xFF102A43),
                                                  side: BorderSide(
                                                    color: sel
                                                        ? const Color(0xFF42A5F5)
                                                        : Colors.white24,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        const SizedBox(height: 18),
                                        const Text(
                                          'کاتەکان',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Color(0xFF829AB1),
                                            fontSize: 13,
                                            fontFamily: 'KurdishFont',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ناوچە: ${_formatMinutes(day.startMinutes)} — ${_formatMinutes(day.endMinutes)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            color: Color(0xFF829AB1),
                                            fontSize: 12,
                                            fontFamily: 'KurdishFont',
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (slots.isEmpty)
                                          const Text(
                                            'کاتێک دیاری نەکراوە',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: Color(0xFF829AB1),
                                              fontFamily: 'KurdishFont',
                                            ),
                                          )
                                        else
                                          Wrap(
                                            alignment: WrapAlignment.end,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: slots.map((m) {
                                              final t = _timeFromMinutes(m);
                                              final sel = _selectedTime != null &&
                                                  _toMinutes(_selectedTime!) == m;
                                              return FilterChip(
                                                label: Text(
                                                  _formatMinutes(m),
                                                  style: TextStyle(
                                                    fontFamily: 'KurdishFont',
                                                    fontWeight: sel
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: sel
                                                        ? const Color(0xFF102A43)
                                                        : const Color(0xFFD9E2EC),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                selected: sel,
                                                onSelected: (_) {
                                                  setState(() => _selectedTime = t);
                                                },
                                                selectedColor: const Color(0xFF42A5F5),
                                                backgroundColor: const Color(0xFF1D1E33),
                                                checkmarkColor: const Color(0xFF102A43),
                                                side: BorderSide(
                                                  color: sel
                                                      ? const Color(0xFF42A5F5)
                                                      : Colors.white24,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 22),
                                ElevatedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _confirmAppointment(
                                            patientName,
                                            doctorDisplayName,
                                            _selectedEntry(scheduleDays),
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF42A5F5),
                                    foregroundColor: const Color(0xFF102A43),
                                    minimumSize: const Size(double.infinity, 54),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.2),
                                        )
                                      : const Text(
                                          'دوپاتکردنەوەی نۆرە',
                                          style: TextStyle(
                                            fontFamily: 'KurdishFont',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  );
          },
        ),
      ),
    );
  }
}
