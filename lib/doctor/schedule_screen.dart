import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../calendar/calendar_slot_logic.dart';
import '../auth/doctor_session_cache.dart';
import '../auth/firestore_user_doc_id.dart';
import '../firestore/appointment_queries.dart';
import '../firestore/calendar_block_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/patient_profile_read.dart';

int _appointmentSortMinutes(Map<String, dynamic> data) {
  final t = (data[AppointmentFields.time] ?? '').toString();
  final parts = t.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0].trim()) ?? 0;
  final m = int.tryParse(parts[1].trim()) ?? 0;
  return h * 60 + m;
}

String _dayCountKey(DateTime d) =>
    scheduleDateOverrideKey(DateTime(d.year, d.month, d.day));

/// Normalized `HH:mm` key for matching [AppointmentFields.time] to [formatSlotMinutesKey].
String _scheduleApptTimeKey(Map<String, dynamic> data) {
  final t = (data[AppointmentFields.time] ?? '').toString().trim();
  if (t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return '';
  final h = int.tryParse(parts[0].trim()) ?? 0;
  final m = int.tryParse(parts[1].trim()) ?? 0;
  return formatSlotMinutesKey(h * 60 + m);
}

/// Active (non-cancelled) appointment counts per calendar day for the doctor.
List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeAppointmentsSortedForDay(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final active = docs.where((d) {
    final st =
        (d.data()[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
    return st != 'cancelled';
  }).toList()
    ..sort(
      (a, b) => _appointmentSortMinutes(a.data()).compareTo(_appointmentSortMinutes(b.data())),
    );
  return active;
}

Map<String, int> _appointmentCountsByDay(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final map = <String, int>{};
  for (final d in docs) {
    final data = d.data();
    final st =
        (data[AppointmentFields.status] ?? 'pending').toString().trim().toLowerCase();
    if (st == 'cancelled') continue;
    final ts = data[AppointmentFields.date];
    if (ts is! Timestamp) continue;
    final dt = ts.toDate();
    final key = scheduleDateOverrideKey(DateTime(dt.year, dt.month, dt.day));
    map[key] = (map[key] ?? 0) + 1;
  }
  return map;
}

String _scheduleLocalizedGender(BuildContext context, String raw) {
  if (raw.isEmpty) return S.of(context).translate('doctor_appt_not_available');
  final n = raw.toLowerCase().trim();
  final s = S.of(context);
  const maleHints = {'male', 'm', 'man', 'ذكر', 'رجل', 'نێر'};
  const femaleHints = {'female', 'f', 'woman', 'أنثى', 'انثى', 'مێ'};
  if (maleHints.contains(n)) return s.translate('doctor_appt_gender_male');
  if (femaleHints.contains(n)) return s.translate('doctor_appt_gender_female');
  return raw;
}

Future<Map<String, Map<String, dynamic>>> _fetchPatientUserMaps(
  Iterable<String> patientIds,
) async {
  final unique = patientIds.where((id) => id.isNotEmpty).toSet();
  final out = <String, Map<String, dynamic>>{};
  await Future.wait(unique.map((id) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists && doc.data() != null) {
        out[id] = doc.data()!;
      }
    } catch (_) {}
  }));
  return out;
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    this.embedded = false,
    this.reloadToken,
  });

  final bool embedded;

  /// Increment (e.g. when this tab is selected) to reload [schedule_date_overrides] from Firestore.
  final ValueNotifier<int>? reloadToken;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? _resolvedDoctorId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _doctorDocSub;

  String? _doctorRefId() {
    return _resolvedDoctorId;
  }

  Map<String, dynamic> _dateOverrides = {};
  Map<String, dynamic>? _cachedWeekly;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay;
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<int> _daySlotChoices = [15, 20, 30, 45, 60];

  Map<String, dynamic> _weeklyMap() {
    final w = _cachedWeekly;
    if (w == null || w.isEmpty) return {};
    return Map<String, dynamic>.from(
      w.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.reloadToken?.addListener(_onScheduleReloadSignal);
    _bindDoctorScheduleStream();
  }

  @override
  void dispose() {
    _doctorDocSub?.cancel();
    widget.reloadToken?.removeListener(_onScheduleReloadSignal);
    super.dispose();
  }

  void _onScheduleReloadSignal() {
    _bindDoctorScheduleStream(forceRebind: true);
  }

  Future<void> _bindDoctorScheduleStream({bool forceRebind = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    final cached = await DoctorSessionCache.readDoctorRefId();
    final fallback = firestoreUserDocId(user).trim();
    final uid = (cached ?? '').trim().isNotEmpty ? (cached ?? '').trim() : fallback;
    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!forceRebind && _resolvedDoctorId == uid && _doctorDocSub != null) {
      return;
    }
    _resolvedDoctorId = uid;
    _doctorDocSub?.cancel();
    _doctorDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (doc) {
        final data = doc.data();
        final weekly = data?['weekly_schedule'];
        if (weekly is Map) {
          _cachedWeekly = Map<String, dynamic>.from(
            weekly.map((k, v) => MapEntry(k.toString(), v)),
          );
        } else {
          _cachedWeekly = null;
        }
        _dateOverrides =
            normalizeScheduleDateOverridesMap(data?['schedule_date_overrides']);
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      },
    );
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

  String _daySettingsDocId(String uid, DateTime day) {
    final k = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    return '${uid}_${k}_daySettings';
  }

  String _closedDayDocId(String uid, DateTime day) {
    final k = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    return '${uid}_${k}_closed';
  }

  Future<int?> _loadDaySettingsSlotMinutes(String uid, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    try {
      final snap = await calendarBlocksForDoctorDateRange(
        doctorUserId: uid,
        rangeStartInclusiveLocal: start,
        rangeEndExclusiveLocal: end,
      ).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data[CalendarBlockFields.isOpen] == true) {
          final raw = data[kAppointmentDurationField] ?? data[kAppointmentSlotMinutesField];
          if (raw is int && _daySlotChoices.contains(raw)) return raw;
          if (raw is num) {
            final i = raw.toInt();
            if (_daySlotChoices.contains(i)) return i;
          }
        }
        if (data[CalendarBlockFields.blockKind] != CalendarBlockFields.kindDaySettings) {
          continue;
        }
        final raw = data[kAppointmentDurationField] ?? data[kAppointmentSlotMinutesField];
        if (raw is int && _daySlotChoices.contains(raw)) return raw;
        if (raw is num) {
          final i = raw.toInt();
          if (_daySlotChoices.contains(i)) return i;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Single atomic write: [users.schedule_date_overrides] + [calendar_blocks] for this day.
  Future<void> _commitDayAvailabilityBatch({
    required String uid,
    required DateTime day,
    required bool blocked,
    required int slotMinutes,
    required Map<String, dynamic> fullOverrides,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    batch.set(
      userRef,
      {
        'schedule_date_overrides': fullOverrides,
        'scheduleUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final start = DateTime(day.year, day.month, day.day);
    final selectedDate = CalendarBlockFields.dayStatusDocumentId(start);
    // Same persistence as:
    // FirebaseFirestore.instance.collection('calendar_blocks').doc(selectedDate).set(...)
    final dayStatusRef = FirebaseFirestore.instance
        .collection(CalendarBlockFields.collection)
        .doc(selectedDate);

    final closedRef = FirebaseFirestore.instance
        .collection(CalendarBlockFields.collection)
        .doc(_closedDayDocId(uid, day));
    final settingsRef = FirebaseFirestore.instance
        .collection(CalendarBlockFields.collection)
        .doc(_daySettingsDocId(uid, day));
    batch.delete(closedRef);
    batch.delete(settingsRef);

    final statusPayload = <String, dynamic>{
      AppointmentFields.doctorId: uid,
      AppointmentFields.date: Timestamp.fromDate(start),
      CalendarBlockFields.dateKey: selectedDate,
      CalendarBlockFields.isOpen: !blocked,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!blocked) {
      statusPayload[kAppointmentDurationField] = slotMinutes;
    } else {
      statusPayload[kAppointmentDurationField] = FieldValue.delete();
    }
    batch.set(dayStatusRef, statusPayload, SetOptions(merge: true));

    await batch.commit();
    // ignore: avoid_print
    print('Data saved successfully');
  }

  int _coerceSheetSlot(int? v) {
    if (v != null && _daySlotChoices.contains(v)) return v;
    return kDefaultAppointmentSlotMinutes;
  }

  ({int startMinutes, int endMinutes})? _resolvedWindow(DateTime day) {
    return workingWindowForDateWithOverrides(
      DateTime(day.year, day.month, day.day),
      _weeklyMap(),
      _dateOverrides,
    );
  }

  bool _isBlockedOverride(DateTime day) {
    final key = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    final raw = _dateOverrides[key];
    return raw is Map && raw['blocked'] == true;
  }

  Future<void> _openDayEditor(DateTime day) async {
    final uid = _doctorRefId();
    if (uid == null || !mounted) return;

    final s = S.of(context);
    final key = scheduleDateOverrideKey(DateTime(day.year, day.month, day.day));
    final weeklyOnly = workingWindowForDate(day, _weeklyMap());
    final raw = _dateOverrides[key];
    final blocked = raw is Map && raw['blocked'] == true;
    var custom = raw is Map &&
        !blocked &&
        raw['startMinutes'] != null &&
        raw['endMinutes'] != null;
    var startT = _fromMinutes(
          raw is Map ? raw['startMinutes'] : null,
        ) ??
        (weeklyOnly != null
            ? TimeOfDay(hour: weeklyOnly.startMinutes ~/ 60, minute: weeklyOnly.startMinutes % 60)
            : const TimeOfDay(hour: 9, minute: 0));
    var endT = _fromMinutes(
          raw is Map ? raw['endMinutes'] : null,
        ) ??
        (weeklyOnly != null
            ? TimeOfDay(hour: weeklyOnly.endMinutes ~/ 60, minute: weeklyOnly.endMinutes % 60)
            : const TimeOfDay(hour: 17, minute: 0));

    final loadedSlot = await _loadDaySettingsSlotMinutes(uid, day);
    var sbSlot = _coerceSheetSlot(loadedSlot);

    if (!mounted) return;

    var sbBlocked = blocked;
    var sbCustom = custom;
    var sbStart = startT;
    var sbEnd = endT;
    var sheetSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final tabBodyHeight = (MediaQuery.sizeOf(ctx).height * 0.52).clamp(280.0, 540.0);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.paddingOf(ctx).bottom + 16,
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DateFormat.yMMMEd().format(day),
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: appointmentsForDoctorDateRange(
                    doctorUserId: uid,
                    rangeStartInclusiveLocal:
                        DateTime(day.year, day.month, day.day),
                    rangeEndExclusiveLocal:
                        DateTime(day.year, day.month, day.day)
                            .add(const Duration(days: 1)),
                  ).snapshots(),
                  builder: (ctx, apptSnap) {
                    final patientsLabel = s.translate('schedule_sheet_tab_patients');
                    final String patientsTabText;
                    if (apptSnap.hasData) {
                      final n = _activeAppointmentsSortedForDay(apptSnap.data!.docs).length;
                      patientsTabText = '$patientsLabel ($n)';
                    } else if (apptSnap.connectionState == ConnectionState.waiting) {
                      patientsTabText = patientsLabel;
                    } else {
                      patientsTabText = '$patientsLabel (0)';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: TabBar(
                            labelColor: const Color(0xFF42A5F5),
                            unselectedLabelColor: const Color(0xFF829AB1),
                            indicatorColor: const Color(0xFF42A5F5),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.white12,
                            labelStyle: const TextStyle(
                              fontFamily: 'KurdishFont',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontFamily: 'KurdishFont',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            tabs: [
                              Tab(text: s.translate('schedule_sheet_tab_settings')),
                              Tab(text: patientsTabText),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: tabBodyHeight,
                          child: TabBarView(
                            children: [
                      StatefulBuilder(
                        builder: (context, setModal) {
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        s.translate('schedule_day_blocked'),
                        style: const TextStyle(
                          color: Color(0xFFD9E2EC),
                          fontFamily: 'KurdishFont',
                        ),
                      ),
                      value: sbBlocked,
                      activeThumbColor: const Color(0xFFE53935),
                      onChanged: (v) {
                        setModal(() {
                          sbBlocked = v;
                          if (v) sbCustom = false;
                        });
                      },
                    ),
                    if (!sbBlocked) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.translate('schedule_custom_hours'),
                          style: const TextStyle(
                            color: Color(0xFFD9E2EC),
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                        subtitle: Text(
                          s.translate('schedule_use_weekday_default_hint'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'KurdishFont',
                            fontSize: 11,
                          ),
                        ),
                        value: sbCustom,
                        activeThumbColor: const Color(0xFF42A5F5),
                        onChanged: (v) => setModal(() => sbCustom = v),
                      ),
                      if (sbCustom) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final p = await showTimePicker(
                                    context: ctx,
                                    initialTime: sbStart,
                                    builder: (c, ch) => Directionality(
                                      textDirection: AppLocaleScope.of(c).textDirection,
                                      child: ch ?? const SizedBox.shrink(),
                                    ),
                                  );
                                  if (p != null) setModal(() => sbStart = p);
                                },
                                child: Text(
                                  '${s.translate('schedule_time_start')}: ${_formatTime(sbStart)}',
                                  style: const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final p = await showTimePicker(
                                    context: ctx,
                                    initialTime: sbEnd,
                                    builder: (c, ch) => Directionality(
                                      textDirection: AppLocaleScope.of(c).textDirection,
                                      child: ch ?? const SizedBox.shrink(),
                                    ),
                                  );
                                  if (p != null) setModal(() => sbEnd = p);
                                },
                                child: Text(
                                  '${s.translate('schedule_time_end')}: ${_formatTime(sbEnd)}',
                                  style: const TextStyle(fontFamily: 'KurdishFont', fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          s.translate('schedule_weekday_slot_label'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontSize: 12,
                            fontFamily: 'KurdishFont',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF12152A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: sbSlot,
                              dropdownColor: const Color(0xFF252640),
                              iconEnabledColor: const Color(0xFF42A5F5),
                              style: const TextStyle(
                                color: Color(0xFFD9E2EC),
                                fontFamily: 'KurdishFont',
                                fontSize: 14,
                              ),
                              items: _daySlotChoices
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        s.translate(
                                          'schedule_day_slot_minutes_option',
                                          params: {'minutes': '$m'},
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setModal(() => sbSlot = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: (sheetSaving || _isSaving)
                          ? null
                          : () async {
                              final next = Map<String, dynamic>.from(_dateOverrides);
                              if (sbBlocked) {
                                next[key] = {'blocked': true};
                              } else if (!sbCustom) {
                                next.remove(key);
                              } else {
                                next[key] = {
                                  'startMinutes': _toMinutes(sbStart),
                                  'endMinutes': _toMinutes(sbEnd),
                                };
                              }
                              sheetSaving = true;
                              setModal(() {});
                              try {
                                await _commitDayAvailabilityBatch(
                                  uid: uid,
                                  day: day,
                                  blocked: sbBlocked,
                                  slotMinutes: sbSlot,
                                  fullOverrides: next,
                                );
                                if (!mounted) return;
                                setState(() => _dateOverrides = next);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        s.translate('schedule_save_ok'),
                                        style: const TextStyle(fontFamily: 'KurdishFont'),
                                      ),
                                    ),
                                  );
                                  Navigator.pop(ctx);
                                }
                              } on FirebaseException catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        S.of(ctx).translate(
                                          'error_code',
                                          params: {'code': e.code},
                                        ),
                                        style: const TextStyle(fontFamily: 'KurdishFont'),
                                      ),
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        s.translate('schedule_save_error_generic'),
                                        style: const TextStyle(fontFamily: 'KurdishFont'),
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                sheetSaving = false;
                                if (ctx.mounted) setModal(() {});
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: const Color(0xFF102A43),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: sheetSaving
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF102A43),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    s.translate('schedule_saving'),
                                    style: const TextStyle(
                                      fontFamily: 'KurdishFont',
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              s.translate('schedule_save_button'),
                              style: const TextStyle(
                                fontFamily: 'KurdishFont',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                              ],
                            ),
                          );
                        },
                      ),
                      _ScheduleSheetPatientsTab(
                        doctorId: uid,
                        day: day,
                        weeklySchedule: _weeklyMap(),
                        dateOverrides: _dateOverrides,
                        appointmentsSnapshot: apptSnap,
                      ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Persists [schedule_date_overrides] on the user doc (weekly template is not edited here).
  /// Keys are normalized to `yyyy-MM-dd` via [normalizeScheduleDateOverridesMap] on load;
  /// this write keeps the in-memory map (already canonical keys).
  Future<bool> _saveSchedule() async {
    final uid = _doctorRefId();
    final s = S.of(context);
    if (uid == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_user_missing'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final toWrite = normalizeScheduleDateOverridesMap(_dateOverrides);
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'schedule_date_overrides': toWrite,
          'scheduleUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return false;
      setState(() => _dateOverrides = Map<String, dynamic>.from(toWrite));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('schedule_save_ok'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return true;
    } on FirebaseException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('schedule_save_error_generic'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final savePaddingBottom = widget.embedded ? 12.0 + bottomInset : 16.0 + bottomInset;

    final uid = _doctorRefId();
    final bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text(
                  s.translate('schedule_calendar_hint'),
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                    fontSize: 13,
                  ),
                ),
              ),
              if (uid == null)
                _buildCalendarCard(context, const {})
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: appointmentsForDoctorDateRange(
                    doctorUserId: uid,
                    rangeStartInclusiveLocal:
                        DateTime(_focusedDay.year, _focusedDay.month, 1),
                    rangeEndExclusiveLocal:
                        DateTime(_focusedDay.year, _focusedDay.month + 1, 1),
                  ).snapshots(),
                  builder: (context, apptSnap) {
                    final counts = apptSnap.hasData
                        ? _appointmentCountsByDay(apptSnap.data!.docs)
                        : <String, int>{};
                    return _buildCalendarCard(context, counts);
                  },
                ),
            ],
          );

    final saveBar = Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, savePaddingBottom),
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveSchedule(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF42A5F5),
          foregroundColor: const Color(0xFF102A43),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSaving
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      s.translate('schedule_saving'),
                      style: const TextStyle(
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(
                s.translate('schedule_save_button'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: widget.embedded
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: s.translate('tooltip_back'),
                ),
                title: Text(
                  s.translate('schedule_screen_title'),
                  style: const TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: const Color(0xFFD9E2EC),
                elevation: 0,
              ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: bodyContent,
              ),
            ),
            saveBar,
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(BuildContext context, Map<String, int> countsPerDay) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF12152A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
        child: TableCalendar<void>(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focusedDay,
          rowHeight: 46,
          daysOfWeekHeight: 34,
          selectedDayPredicate: (d) =>
              _selectedCalendarDay != null && isSameDay(_selectedCalendarDay!, d),
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          startingDayOfWeek: StartingDayOfWeek.saturday,
          locale: Localizations.localeOf(context).toLanguageTag(),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontFamily: 'KurdishFont',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            weekendStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontFamily: 'KurdishFont',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: const TextStyle(
              color: Color(0xFFE8EEF4),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'KurdishFont',
            ),
            leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF42A5F5)),
            rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF42A5F5)),
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: true,
            markersMaxCount: 0,
            cellMargin: EdgeInsets.zero,
            defaultDecoration: BoxDecoration(shape: BoxShape.rectangle),
            weekendDecoration: BoxDecoration(shape: BoxShape.rectangle),
            outsideDecoration: BoxDecoration(shape: BoxShape.rectangle),
            todayDecoration: BoxDecoration(shape: BoxShape.rectangle),
            selectedDecoration: BoxDecoration(shape: BoxShape.rectangle),
            defaultTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
            weekendTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
            outsideTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
            todayTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
            selectedTextStyle: TextStyle(fontSize: 0.1, color: Colors.transparent),
          ),
          onPageChanged: (f) => setState(() => _focusedDay = f),
          onDaySelected: (sel, foc) {
            setState(() {
              _selectedCalendarDay = sel;
              _focusedDay = foc;
            });
            _openDayEditor(sel);
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, d, fd) => _calendarCell(
              context,
              d,
              fd,
              appointmentCount: countsPerDay[_dayCountKey(d)] ?? 0,
            ),
            todayBuilder: (context, d, fd) => _calendarCell(
              context,
              d,
              fd,
              isToday: true,
              appointmentCount: countsPerDay[_dayCountKey(d)] ?? 0,
            ),
            selectedBuilder: (context, d, fd) => _calendarCell(
              context,
              d,
              fd,
              isSelected: true,
              appointmentCount: countsPerDay[_dayCountKey(d)] ?? 0,
            ),
            outsideBuilder: (context, d, fd) => _calendarCell(
              context,
              d,
              fd,
              isOutside: true,
              appointmentCount: countsPerDay[_dayCountKey(d)] ?? 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarCell(
    BuildContext context,
    DateTime day,
    DateTime focusedMonth, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
    int appointmentCount = 0,
  }) {
    final win = _resolvedWindow(day);
    final blocked = _isBlockedOverride(day);
    Color fill;
    Color border;
    if (blocked) {
      fill = const Color(0xFF3D1518);
      border = const Color(0xFFE53935);
    } else if (win != null) {
      fill = const Color(0xFF0F3D28);
      border = const Color(0xFF22C55E);
    } else {
      fill = const Color(0xFF1A1D2E);
      border = Colors.white24;
    }
    if (isOutside) {
      fill = fill.withValues(alpha: 0.45);
      border = border.withValues(alpha: 0.45);
    }
    if (isToday) {
      border = const Color(0xFF38BDF8);
    } else if (isSelected) {
      border = const Color(0xFF6366F1);
    }

    final textDir = Directionality.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: isToday || isSelected ? 2 : 1.2),
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: 'KurdishFont',
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
                color: isOutside
                    ? const Color(0xFF829AB1).withValues(alpha: 0.5)
                    : const Color(0xFFE8EEF4),
              ),
            ),
          ),
          if (appointmentCount > 0)
            Positioned.directional(
              textDirection: textDir,
              top: 1,
              end: 1,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  appointmentCount > 99 ? '99+' : '$appointmentCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _patientFullNameFromProfile(
  Map<String, dynamic>? profile,
  String appointmentFallback,
) {
  if (profile != null) {
    for (final k in ['fullName', 'fullName_ku', 'fullName_en', 'fullName_ar']) {
      final t = (profile[k] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
  }
  final f = appointmentFallback.trim();
  return f.isEmpty ? '' : f;
}

/// Dashed rounded border for “available” slot rows.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.borderRadius,
  });

  final Color color;
  final double borderRadius;

  static const double _dash = 6;
  static const double _gap = 4;
  static const double _strokeWidth = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = _strokeWidth / 2;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - _strokeWidth, size.height - _strokeWidth),
      Radius.circular(borderRadius.clamp(0, 999)),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final end = (dist + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}

void _showSchedulePatientDetailsDialog(
  BuildContext context,
  Map<String, dynamic> appointment,
  Map<String, dynamic>? patientProfile,
) {
  final s = S.of(context);
  final apptName =
      (appointment[AppointmentFields.patientName] ?? '').toString().trim();
  final displayName = _patientFullNameFromProfile(patientProfile, apptName);
  final nameShown = displayName.isEmpty
      ? s.translate('doctor_appt_not_available')
      : displayName;

  final phone = patientPhoneFromUserData(patientProfile);
  final email = patientEmailFromUserData(patientProfile);
  final age = patientAgeYearsFromUserData(patientProfile);
  final genderRaw = patientGenderRawFromUserData(patientProfile);

  final timeRaw = (appointment[AppointmentFields.time] ?? '').toString().trim();
  final timeShown = timeRaw.isEmpty ? '—' : timeRaw;

  String dash(String v) =>
      v.trim().isEmpty ? s.translate('doctor_appt_not_available') : v.trim();
  final ageStr =
      age != null ? '$age' : s.translate('doctor_appt_not_available');
  final genderStr = genderRaw.isEmpty
      ? s.translate('doctor_appt_not_available')
      : _scheduleLocalizedGender(context, genderRaw);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      final dir = AppLocaleScope.of(ctx).textDirection;
      return Directionality(
        textDirection: dir,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            s.translate('schedule_patient_details_title'),
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              color: Color(0xFFD9E2EC),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SchedulePatientInfoRow(
                  icon: Icons.schedule_rounded,
                  label: s.translate('label_times'),
                  value: timeShown,
                ),
                _SchedulePatientInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: s.translate('doctor_appt_patient_name_label'),
                  value: nameShown,
                ),
                _SchedulePatientInfoRow(
                  icon: Icons.phone_android_rounded,
                  label: s.translate('doctor_appt_label_phone'),
                  value: dash(phone),
                ),
                _SchedulePatientInfoRow(
                  icon: Icons.email_outlined,
                  label: s.translate('doctor_appt_label_email'),
                  value: dash(email),
                ),
                _SchedulePatientInfoRow(
                  icon: Icons.cake_outlined,
                  label: s.translate('doctor_appt_label_age'),
                  value: ageStr,
                ),
                _SchedulePatientInfoRow(
                  icon: Icons.wc_rounded,
                  label: s.translate('doctor_appt_label_gender'),
                  value: genderStr,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                s.translate('ok'),
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  color: Color(0xFF42A5F5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Full-day slot timeline (Schedule Management bottom sheet — tab 2).
/// [appointmentsSnapshot] is live; [calendar_blocks] is streamed inside for slot step.
class _ScheduleSheetPatientsTab extends StatelessWidget {
  const _ScheduleSheetPatientsTab({
    required this.doctorId,
    required this.day,
    required this.weeklySchedule,
    required this.dateOverrides,
    required this.appointmentsSnapshot,
  });

  final String doctorId;
  final DateTime day;
  final Map<String, dynamic> weeklySchedule;
  final Map<String, dynamic> dateOverrides;
  final AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> appointmentsSnapshot;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final snapshot = appointmentsSnapshot;

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${snapshot.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontFamily: 'KurdishFont',
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
      );
    }

    final dayNorm = DateTime(day.year, day.month, day.day);
    final dayEnd = dayNorm.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: calendarBlocksForDoctorDateRange(
        doctorUserId: doctorId,
        rangeStartInclusiveLocal: dayNorm,
        rangeEndExclusiveLocal: dayEnd,
      ).snapshots(),
      builder: (context, blockSnap) {
        if (blockSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${blockSnap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontFamily: 'KurdishFont',
                  fontSize: 12,
                ),
              ),
            ),
          );
        }
        if (blockSnap.connectionState == ConnectionState.waiting && !blockSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
          );
        }

        final blockMaps = blockSnap.data?.docs.map((e) => e.data()).toList() ?? [];
        final win = workingWindowForDateWithOverrides(
          dayNorm,
          weeklySchedule.isEmpty ? null : weeklySchedule,
          dateOverrides,
        );
        if (win == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                s.translate('schedule_timeline_no_hours'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF829AB1),
                  fontFamily: 'KurdishFont',
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          );
        }

        final step = appointmentSlotMinutesForDateWithAllBlocks(dayNorm, blockMaps);
        final slotStarts = slotStartMinutesForWindow(
          win.startMinutes,
          win.endMinutes,
          step: step,
        );

        if (slotStarts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                s.translate('schedule_timeline_no_slots'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF829AB1),
                  fontFamily: 'KurdishFont',
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final active = _activeAppointmentsSortedForDay(docs);
        final slotKeys = slotStarts.map(formatSlotMinutesKey).toSet();

        final apptBySlotKey = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final d in active) {
          final k = _scheduleApptTimeKey(d.data());
          if (k.isEmpty) continue;
          apptBySlotKey.putIfAbsent(k, () => []).add(d);
        }

        final unmatched = active.where((d) {
          final k = _scheduleApptTimeKey(d.data());
          return k.isEmpty || !slotKeys.contains(k);
        }).toList();

        final patientIds = active
            .map((e) => (e.data()[AppointmentFields.patientId] ?? '').toString().trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        return FutureBuilder<Map<String, Map<String, dynamic>>>(
          key: ValueKey('${active.map((e) => e.id).join('|')}|$patientIds'),
          future: _fetchPatientUserMaps(patientIds),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting && !profileSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              );
            }
            final profiles = profileSnap.data ?? {};

            return ListView(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              children: [
                for (var i = 0; i < slotStarts.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ScheduleTimelineSlotRow(
                    timeLabel: formatSlotMinutesKey(slotStarts[i]),
                    bookedDocs: apptBySlotKey[formatSlotMinutesKey(slotStarts[i])],
                    profiles: profiles,
                  ),
                ],
                if (unmatched.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      s.translate('schedule_timeline_other_bookings'),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  for (var j = 0; j < unmatched.length; j++) ...[
                    if (j > 0) const SizedBox(height: 8),
                    _ScheduleTimelineSlotRow(
                      timeLabel: () {
                        final tk = _scheduleApptTimeKey(unmatched[j].data());
                        return tk.isEmpty ? '—' : tk;
                      }(),
                      bookedDocs: [unmatched[j]],
                      profiles: profiles,
                    ),
                  ],
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _ScheduleTimelineSlotRow extends StatelessWidget {
  const _ScheduleTimelineSlotRow({
    required this.timeLabel,
    required this.bookedDocs,
    required this.profiles,
  });

  final String timeLabel;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>? bookedDocs;
  final Map<String, Map<String, dynamic>> profiles;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bookedList = bookedDocs ?? const [];
    final booked = bookedList.isNotEmpty;

    if (!booked) {
      return CustomPaint(
        foregroundPainter: _DashedRRectPainter(
          color: const Color(0xFF64748B),
          borderRadius: 12,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                timeLabel,
                style: const TextStyle(
                  color: Color(0xFF42A5F5),
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.translate('schedule_slot_available'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final primary = bookedList.first;
    final data = primary.data();
    final pid = (data[AppointmentFields.patientId] ?? '').toString().trim();
    final profile = pid.isNotEmpty ? profiles[pid] : null;
    final apptName = (data[AppointmentFields.patientName] ?? '').toString().trim();
    final displayName = _patientFullNameFromProfile(profile, apptName);
    final nameShown = displayName.isEmpty
        ? s.translate('doctor_appt_not_available')
        : displayName;
    final extra = bookedList.length - 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (bookedList.length <= 1) {
            _showSchedulePatientDetailsDialog(context, data, profile);
            return;
          }
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: const Color(0xFF1D1E33),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              final dir = AppLocaleScope.of(ctx).textDirection;
              return Directionality(
                textDirection: dir,
                child: SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: Color(0xFF42A5F5),
                          fontFamily: 'KurdishFont',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final doc in bookedList)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            () {
                              final dd = doc.data();
                              final p = (dd[AppointmentFields.patientId] ?? '')
                                  .toString()
                                  .trim();
                              final pr = p.isNotEmpty ? profiles[p] : null;
                              final an =
                                  (dd[AppointmentFields.patientName] ?? '').toString().trim();
                              final dn = _patientFullNameFromProfile(pr, an);
                              return dn.isEmpty
                                  ? s.translate('doctor_appt_not_available')
                                  : dn;
                            }(),
                            style: const TextStyle(
                              color: Color(0xFFD9E2EC),
                              fontFamily: 'KurdishFont',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFF829AB1),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            final dd = doc.data();
                            final p =
                                (dd[AppointmentFields.patientId] ?? '').toString().trim();
                            final pr = p.isNotEmpty ? profiles[p] : null;
                            _showSchedulePatientDetailsDialog(context, dd, pr);
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF12152A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.45), width: 1.4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_rounded, color: Color(0xFF42A5F5), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: Color(0xFF42A5F5),
                          fontFamily: 'KurdishFont',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nameShown,
                        style: const TextStyle(
                          color: Color(0xFFD9E2EC),
                          fontFamily: 'KurdishFont',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (extra > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            s.translate(
                              'schedule_timeline_more_same_slot',
                              params: {'count': '$extra'},
                            ),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontFamily: 'KurdishFont',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.35),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SchedulePatientInfoRow extends StatelessWidget {
  const _SchedulePatientInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF42A5F5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontSize: 14,
                    height: 1.25,
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
