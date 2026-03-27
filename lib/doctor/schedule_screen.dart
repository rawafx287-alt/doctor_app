import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('availability')
          .get();

      final loaded = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        loaded[doc.id] = doc.data();
      }

      for (var i = 0; i < _schedules.length; i++) {
        final current = _schedules[i];
        final data = loaded[current.id];
        if (data == null) continue;

        final start = _fromMinutes(data['startMinutes']);
        final end = _fromMinutes(data['endMinutes']);
        _schedules[i] = current.copyWith(
          isAvailable: data['isAvailable'] == true,
          startTime: start ?? current.startTime,
          endTime: end ?? current.endTime,
        );
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

  Future<void> _updateDayInFirestore(_DaySchedule day) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('availability')
          .doc(day.id)
          .set({
        'day': day.day,
        'isAvailable': day.isAvailable,
        'startMinutes': _toMinutes(day.startTime),
        'endMinutes': _toMinutes(day.endTime),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هەڵە لە نوێکردنەوەی ڕۆژ')),
      );
    }
  }

  Future<void> _pickTime(int index, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _schedules[index].startTime : _schedules[index].endTime,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
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
    await _updateDayInFirestore(_schedules[index]);
  }

  Future<void> _saveSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final day in _schedules) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('availability')
            .doc(day.id);
        batch.set(ref, {
          'day': day.day,
          'isAvailable': day.isAvailable,
          'startMinutes': _toMinutes(day.startTime),
          'endMinutes': _toMinutes(day.endTime),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پاشەکەوتکردنی خشتە تەواوبوو')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هەڵە لە پاشەکەوتکردنی خشتە')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
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
                padding: const EdgeInsets.all(16),
                itemCount: _schedules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _schedules[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.day,
                                style: const TextStyle(
                                  color: Color(0xFFD9E2EC),
                                  fontSize: 17,
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: item.isAvailable,
                              activeColor: const Color(0xFF2CB1BC),
                              onChanged: (value) async {
                                setState(() {
                                  _schedules[index] =
                                      _schedules[index].copyWith(isAvailable: value);
                                });
                                await _updateDayInFirestore(_schedules[index]);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickTime(index, isStart: true),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                  'دەستپێک: ${_schedules[index].startTime.format(context)}',
                                  style: const TextStyle(fontFamily: 'KurdishFont'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD9E2EC),
                                  side: const BorderSide(color: Colors.white24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickTime(index, isStart: false),
                                icon: const Icon(Icons.stop_rounded),
                                label: Text(
                                  'کۆتایی: ${_schedules[index].endTime.format(context)}',
                                  style: const TextStyle(fontFamily: 'KurdishFont'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD9E2EC),
                                  side: const BorderSide(color: Colors.white24),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    'پاشەکەوتکردنی خشتە',
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
