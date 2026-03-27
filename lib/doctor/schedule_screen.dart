import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_rtl.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final List<_DaySchedule> _schedules = [
    _DaySchedule(
      id: 'saturday',
      day: 'شەممە',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'sunday',
      day: 'یەکشەممە',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'monday',
      day: 'دووشەممە',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'tuesday',
      day: 'سێشەممە',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'wednesday',
      day: 'چوارشەممە',
      isAvailable: true,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
    _DaySchedule(
      id: 'thursday',
      day: 'پێنجشەممە',
      isAvailable: false,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 14, minute: 0),
    ),
    _DaySchedule(
      id: 'friday',
      day: 'هەینی',
      isAvailable: false,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    ),
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final weekly = data?['weekly_schedule'];

      if (weekly is Map) {
        for (var i = 0; i < _schedules.length; i++) {
          final id = _schedules[i].id;
          final dayData = weekly[id];
          if (dayData is! Map) continue;

          final start = _fromMinutes(dayData['startMinutes']);
          final end = _fromMinutes(dayData['endMinutes']);
          final enabled = dayData['enabled'] == true;

          _schedules[i] = _schedules[i].copyWith(
            isAvailable: enabled,
            startTime: start ?? _schedules[i].startTime,
            endTime: end ?? _schedules[i].endTime,
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هەڵە لە هێنانی خشتەی کاتەکان')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay? _fromMinutes(dynamic value) {
    if (value is! int || value < 0) return null;
    return TimeOfDay(hour: value ~/ 60, minute: value % 60);
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _formatTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat.jm().format(dt);
  }

  Future<void> _pickTime(int index, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _schedules[index].startTime : _schedules[index].endTime,
      builder: (context, child) {
        return Directionality(
          textDirection: kRtlTextDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;

    setState(() {
      _schedules[index] = _schedules[index].copyWith(
        startTime: isStart ? picked : _schedules[index].startTime,
        endTime: isStart ? _schedules[index].endTime : picked,
      );
    });
  }

  Map<String, dynamic> _weeklyScheduleMap() {
    final map = <String, dynamic>{};
    for (final day in _schedules) {
      map[day.id] = {
        'day': day.day,
        'enabled': day.isAvailable,
        'startMinutes': _toMinutes(day.startTime),
        'endMinutes': _toMinutes(day.endTime),
      };
    }
    return map;
  }

  Future<void> _saveSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بەکارهێنەر نەدۆزرایەوە')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'weekly_schedule': _weeklyScheduleMap(),
          'scheduleUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پاشکەوتکردن بە سەرکەوتوویی تەواوبوو')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هەڵە ڕوویدا (${e.code})')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هەڵە لە پاشکەوتکردنی خشتە')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'گەڕانەوە',
          ),
          title: const Text(
            'خشتەی کاتەکان',
            style: TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: const Color(0xFF243B53),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2CB1BC)),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _schedules.length,
<<<<<<< HEAD
                separatorBuilder: (_, _) => const SizedBox(height: 10),
=======
                separatorBuilder: (_, __) => const SizedBox(height: 12),
>>>>>>> 19b5e8db7f46545d607efa3593b4bf4f10a921fc
                itemBuilder: (context, index) {
                  final item = _schedules[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.day,
                                style: const TextStyle(
                                  color: Color(0xFFD9E2EC),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'KurdishFont',
                                ),
                              ),
                            ),
                            Text(
                              item.isAvailable ? 'چالاک' : 'ناچالاک',
                              style: TextStyle(
                                color: item.isAvailable
                                    ? const Color(0xFF2CB1BC)
                                    : const Color(0xFF829AB1),
                                fontFamily: 'KurdishFont',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: item.isAvailable,
                              activeThumbColor: const Color(0xFF2CB1BC),
<<<<<<< HEAD
                              onChanged: (value) async {
=======
                              onChanged: (value) {
>>>>>>> 19b5e8db7f46545d607efa3593b4bf4f10a921fc
                                setState(() {
                                  _schedules[index] =
                                      _schedules[index].copyWith(isAvailable: value);
                                });
                              },
                            ),
                          ],
                        ),
                        if (item.isAvailable) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pickTime(index, isStart: true),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD9E2EC),
                                    side: const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'دەستپێک',
                                        style: TextStyle(
                                          fontFamily: 'KurdishFont',
                                          fontSize: 12,
                                          color: Color(0xFF829AB1),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(_schedules[index].startTime),
                                        style: const TextStyle(
                                          fontFamily: 'KurdishFont',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pickTime(index, isStart: false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD9E2EC),
                                    side: const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'کۆتایی',
                                        style: TextStyle(
                                          fontFamily: 'KurdishFont',
                                          fontSize: 12,
                                          color: Color(0xFF829AB1),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(_schedules[index].endTime),
                                        style: const TextStyle(
                                          fontFamily: 'KurdishFont',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2CB1BC),
              foregroundColor: const Color(0xFF102A43),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Text(
                    'پاشکەوتکردن',
                    style: TextStyle(
                      fontFamily: 'KurdishFont',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DaySchedule {
  const _DaySchedule({
    required this.id,
    required this.day,
    required this.isAvailable,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String day;
  final bool isAvailable;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  _DaySchedule copyWith({
    String? id,
    String? day,
    bool? isAvailable,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return _DaySchedule(
      id: id ?? this.id,
      day: day ?? this.day,
      isAvailable: isAvailable ?? this.isAvailable,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
