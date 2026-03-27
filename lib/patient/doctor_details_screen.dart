import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_rtl.dart';

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

  static const List<String> _dayIds = [
    'saturday',
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

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
      final sm = raw['startMinutes'];
      final em = raw['endMinutes'];
      if (sm is! int || em is! int) continue;
      final label = (raw['day'] ?? id).toString();
      out.add(
        _ScheduleDayEntry(
          id: id,
          labelKu: label,
          startMinutes: sm,
          endMinutes: em,
        ),
      );
    }
    return out;
  }

  _ScheduleDayEntry? _selectedEntry(List<_ScheduleDayEntry> days) {
    if (_selectedDayId == null) return null;
    for (final d in days) {
      if (d.id == _selectedDayId) return d;
    }
    return null;
  }

  Future<void> _pickDateForDay(_ScheduleDayEntry day) async {
    final targetWeekday = _weekdayFromKey(day.id);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDateMatchingWeekday(today, targetWeekday),
      firstDate: today,
      lastDate: today.add(const Duration(days: 120)),
      selectableDayPredicate: (d) {
        final normalized = DateTime(d.year, d.month, d.day);
        return normalized.weekday == targetWeekday && !normalized.isBefore(today);
      },
      builder: (context, child) {
        return Directionality(
          textDirection: kRtlTextDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  DateTime _nextDateMatchingWeekday(DateTime from, int weekday) {
    var d = from;
    for (var i = 0; i < 14; i++) {
      if (d.weekday == weekday) return d;
      d = d.add(const Duration(days: 1));
    }
    return from;
  }

  Future<void> _pickTimeInRange(_ScheduleDayEntry day) async {
    final initial = _selectedTime ?? _timeFromMinutes(day.startMinutes);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Directionality(
          textDirection: kRtlTextDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    final pm = _toMinutes(picked);
    if (pm < day.startMinutes || pm > day.endMinutes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'کات دەبێت لە نێوان کاتەکانی کاردا بێت',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }
    setState(() => _selectedTime = picked);
  }

  Future<void> _confirmAppointment(
    String patientName,
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

      await FirebaseFirestore.instance.collection('appointments').add({
        'patientId': uid,
        'doctorId': widget.doctorId,
        'patientName': patientName,
        'date': Timestamp.fromDate(_selectedDate!),
        'time': timeStr,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'نۆرەکە دوپاتکرایەوە',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هەڵە (${e.code})')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هەڵە لە پاشەکەوتکردن')),
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
          backgroundColor: const Color(0xFF243B53),
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
            final profileImageUrl = (merged['profileImageUrl'] ?? '').toString().trim();
            final weekly = merged['weekly_schedule'];
            final scheduleDays = _parseSchedule(
              weekly is Map<String, dynamic> ? weekly : null,
            );

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
                                        color: const Color(0xFF2CB1BC),
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
                                            color: Color(0xFF2CB1BC),
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
                            const SizedBox(height: 20),
                            const Text(
                              'ڕۆژە بەردەستەکان',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFFD9E2EC),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
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
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 10,
                                runSpacing: 10,
                                children: scheduleDays.map((d) {
                                  final selected = _selectedDayId == d.id;
                                  return ChoiceChip(
                                    label: Text(
                                      d.labelKu,
                                      style: TextStyle(
                                        fontFamily: 'KurdishFont',
                                        fontWeight:
                                            selected ? FontWeight.w700 : FontWeight.w500,
                                        color: selected
                                            ? const Color(0xFF102A43)
                                            : const Color(0xFFD9E2EC),
                                      ),
                                    ),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedDayId = d.id;
                                        _selectedDate = null;
                                        _selectedTime = _timeFromMinutes(d.startMinutes);
                                      });
                                    },
                                    selectedColor: const Color(0xFF2CB1BC),
                                    backgroundColor: const Color(0xFF1D1E33),
                                    side: BorderSide(
                                      color: selected
                                          ? const Color(0xFF2CB1BC)
                                          : Colors.white24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (_selectedEntry(scheduleDays) != null) ...[
                                const SizedBox(height: 18),
                                Builder(
                                  builder: (context) {
                                    final day = _selectedEntry(scheduleDays)!;
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1D1E33),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          const Text(
                                            'کاتەکانی کار',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: Color(0xFF829AB1),
                                              fontSize: 13,
                                              fontFamily: 'KurdishFont',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'دەستپێک: ${_formatMinutes(day.startMinutes)}  —  کۆتایی: ${_formatMinutes(day.endMinutes)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              color: Color(0xFFD9E2EC),
                                              fontSize: 16,
                                              fontFamily: 'KurdishFont',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          OutlinedButton.icon(
                                            onPressed: () => _pickDateForDay(day),
                                            icon: const Icon(Icons.calendar_month_rounded,
                                                color: Color(0xFF2CB1BC)),
                                            label: Text(
                                              _selectedDate == null
                                                  ? 'هەڵبژاردنی ڕۆژ'
                                                  : '${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}',
                                              style: const TextStyle(
                                                fontFamily: 'KurdishFont',
                                                color: Color(0xFFD9E2EC),
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Colors.white24),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: () => _pickTimeInRange(day),
                                            icon: const Icon(Icons.schedule_rounded,
                                                color: Color(0xFF2CB1BC)),
                                            label: Text(
                                              _selectedTime == null
                                                  ? 'هەڵبژاردنی کات'
                                                  : _formatMinutes(_toMinutes(_selectedTime!)),
                                              style: const TextStyle(
                                                fontFamily: 'KurdishFont',
                                                color: Color(0xFFD9E2EC),
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Colors.white24),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _confirmAppointment(
                                            patientName,
                                            _selectedEntry(scheduleDays),
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2CB1BC),
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
