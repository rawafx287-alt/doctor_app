import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/available_days_queries.dart';
import '../firestore/firestore_index_error_log.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/patient_profile_read.dart';
import '../theme/patient_premium_theme.dart';

/// Doctor/Secretary: day settings + full slot list vs live [appointments] for that date.
class DayManagementScreen extends StatelessWidget {
  const DayManagementScreen({
    super.key,
    required this.doctorUserId,
    required this.availableDayDocId,
    required this.dateLocal,
  });

  final String doctorUserId;
  final String availableDayDocId;
  final DateTime dateLocal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final title = DateFormat.yMMMEd(localeTag).format(
      DateTime(dateLocal.year, dateLocal.month, dateLocal.day),
    );

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0E21),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: const Color(0xFFD9E2EC),
            leading: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              onPressed: () => Navigator.pop(context),
              tooltip: s.translate('tooltip_back'),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'NRT',
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            bottom: TabBar(
              indicatorColor: const Color(0xFF42A5F5),
              labelColor: const Color(0xFFD9E2EC),
              unselectedLabelColor: const Color(0xFF829AB1),
              labelStyle: const TextStyle(
                fontFamily: 'NRT',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: s.translate('day_mgmt_tab_settings')),
                Tab(text: s.translate('day_mgmt_tab_patients')),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _SettingsTab(availableDayDocId: availableDayDocId),
              _PatientSlotsTab(
                doctorUserId: doctorUserId,
                availableDayDocId: availableDayDocId,
                dateLocal: dateLocal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.availableDayDocId});

  final String availableDayDocId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ref = FirebaseFirestore.instance
        .collection(AvailableDayFields.collection)
        .doc(availableDayDocId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              '${snap.error}',
              style: const TextStyle(color: Colors.redAccent, fontFamily: 'NRT'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
          );
        }
        final data = snap.data!.data();
        if (data == null) {
          return Center(child: Text(s.translate('available_day_missing')));
        }

        return _SettingsForm(
          key: ValueKey(snap.data!.id),
          availableDayDocId: availableDayDocId,
          initialStartHhMm: normalizeAvailableDayStartTimeHhMm(
            data[AvailableDayFields.startTime],
          ),
          initialClosingHhMm: normalizeAvailableDayClosingTimeHhMm(
            data[AvailableDayFields.closingTime],
          ),
          initialDuration: normalizeAppointmentDurationMinutes(
            data[AvailableDayFields.appointmentDuration],
          ),
          isOpen: availableDayIsOpen(data),
        );
      },
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({
    super.key,
    required this.availableDayDocId,
    required this.initialStartHhMm,
    required this.initialClosingHhMm,
    required this.initialDuration,
    required this.isOpen,
  });

  final String availableDayDocId;
  final String initialStartHhMm;
  final String initialClosingHhMm;
  final int initialDuration;
  final bool isOpen;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late TimeOfDay _opening;
  late TimeOfDay _closing;
  late int _durationMinutes;
  bool _saving = false;
  static const _durationChoices = [15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _applyFromWidget();
  }

  @override
  void didUpdateWidget(covariant _SettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStartHhMm != widget.initialStartHhMm ||
        oldWidget.initialClosingHhMm != widget.initialClosingHhMm ||
        oldWidget.initialDuration != widget.initialDuration) {
      _applyFromWidget();
    }
  }

  void _applyFromWidget() {
    final os = widget.initialStartHhMm.split(':');
    final oh = int.tryParse(os[0]) ?? 16;
    final om = int.tryParse(os.length > 1 ? os[1] : '0') ?? 0;
    _opening = TimeOfDay(hour: oh, minute: om);

    final cs = widget.initialClosingHhMm.split(':');
    final ch = int.tryParse(cs[0]) ?? 20;
    final cm = int.tryParse(cs.length > 1 ? cs[1] : '0') ?? 0;
    _closing = TimeOfDay(hour: ch, minute: cm);

    _durationMinutes = widget.initialDuration;
  }

  Future<void> _save(BuildContext context) async {
    final s = S.of(context);
    final sh = _opening.hour.toString().padLeft(2, '0');
    final sm = _opening.minute.toString().padLeft(2, '0');
    final ch = _closing.hour.toString().padLeft(2, '0');
    final cm = _closing.minute.toString().padLeft(2, '0');
    setState(() => _saving = true);
    try {
      await updateAvailableDayTimeSettings(
        availableDayDocId: widget.availableDayDocId,
        startTimeHhMm: '$sh:$sm',
        closingTimeHhMm: '$ch:$cm',
        appointmentDurationMinutes: _durationMinutes,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('day_mgmt_update_saved'),
              style: const TextStyle(fontFamily: 'NRT'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _closeDay(BuildContext context) async {
    final s = S.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: Text(
          s.translate('available_days_close_confirm_title'),
          style: const TextStyle(
            fontFamily: 'NRT',
            color: Color(0xFFD9E2EC),
          ),
        ),
        content: Text(
          s.translate('available_days_close_confirm_body'),
          style: const TextStyle(
            fontFamily: 'NRT',
            color: Color(0xFF829AB1),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.translate('action_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.translate('available_days_close_day_action')),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      await setAvailableDayOpenState(
        availableDayDocId: widget.availableDayDocId,
        isOpen: false,
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final openingDt = DateTime(2000, 1, 1, _opening.hour, _opening.minute);
    final closingDt = DateTime(2000, 1, 1, _closing.hour, _closing.minute);
    final openingLabel = DateFormat.jm(localeTag).format(openingDt);
    final closingLabel = DateFormat.jm(localeTag).format(closingDt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              s.translate('available_days_opening_time_label'),
              style: const TextStyle(
                fontFamily: 'NRT',
                color: Color(0xFF829AB1),
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              openingLabel,
              style: const TextStyle(
                fontFamily: 'NRT',
                color: Color(0xFFE8EEF4),
                fontSize: 16,
              ),
            ),
            trailing: const Icon(Icons.schedule_rounded, color: Color(0xFF42A5F5)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _opening);
              if (t != null) setState(() => _opening = t);
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              s.translate('available_days_closing_time_label'),
              style: const TextStyle(
                fontFamily: 'NRT',
                color: Color(0xFF829AB1),
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              closingLabel,
              style: const TextStyle(
                fontFamily: 'NRT',
                color: Color(0xFFE8EEF4),
                fontSize: 16,
              ),
            ),
            trailing: const Icon(Icons.schedule_send_rounded, color: Color(0xFF42A5F5)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _closing);
              if (t != null) setState(() => _closing = t);
            },
          ),
          const SizedBox(height: 16),
          Text(
            s.translate('available_days_duration_label'),
            style: const TextStyle(
              fontFamily: 'NRT',
              color: Color(0xFF829AB1),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _durationMinutes,
                isExpanded: true,
                dropdownColor: const Color(0xFF2A2D45),
                style: const TextStyle(
                  fontFamily: 'NRT',
                  color: Color(0xFFE8EEF4),
                  fontSize: 16,
                ),
                items: [
                  for (final m in _durationChoices)
                    DropdownMenuItem<int>(
                      value: m,
                      child: Text(
                        s.translate('duration_minutes_option', params: {'n': '$m'}),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _durationMinutes = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : () => _save(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF42A5F5),
              foregroundColor: const Color(0xFF102A43),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Text(
                    s.translate('day_mgmt_update_settings'),
                    style: const TextStyle(
                      fontFamily: 'NRT',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (widget.isOpen)
            OutlinedButton(
              onPressed: () => _closeDay(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF87171),
                side: const BorderSide(color: Color(0xFF7F1D1D)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                s.translate('available_days_close_day_action'),
                style: const TextStyle(fontFamily: 'NRT'),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatientSlotsTab extends StatelessWidget {
  const _PatientSlotsTab({
    required this.doctorUserId,
    required this.availableDayDocId,
    required this.dateLocal,
  });

  final String doctorUserId;
  final String availableDayDocId;
  final DateTime dateLocal;

  static Uri? _telUri(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.isEmpty) return null;
    return Uri.parse('tel:$cleaned');
  }

  static Future<void> _launchTel(BuildContext context, String phone) async {
    final s = S.of(context);
    final uri = _telUri(phone);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('doctor_appt_call_failed'),
              style: const TextStyle(fontFamily: 'NRT'),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('doctor_appt_call_failed'),
              style: const TextStyle(fontFamily: 'NRT'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dayOnly = DateTime(dateLocal.year, dateLocal.month, dateLocal.day);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AvailableDayFields.collection)
          .doc(availableDayDocId)
          .snapshots(),
      builder: (context, daySnap) {
        if (!daySnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)));
        }
        final dayData = daySnap.data!.data();
        if (dayData == null) {
          return Center(child: Text(s.translate('available_day_missing')));
        }

        final startHhMm = normalizeAvailableDayStartTimeHhMm(
          dayData[AvailableDayFields.startTime],
        );
        final closingHhMm = normalizeAvailableDayClosingTimeHhMm(
          dayData[AvailableDayFields.closingTime],
        );
        final dur = normalizeAppointmentDurationMinutes(
          dayData[AvailableDayFields.appointmentDuration],
        );
        final slots = generatedSlotStartsForDay(
          dateOnly: dayOnly,
          startTimeHhMm: startHhMm,
          closingTimeHhMm: closingHhMm,
          durationMinutes: dur,
        );

        // Appointments for [dayOnly]: merges Timestamp-in-range + `date` == yyyy/MM/dd (same local day).
        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: watchDoctorAppointmentsForLocalDay(
            doctorUserId: doctorUserId,
            dayLocal: dayOnly,
          ),
          builder: (context, apptSnap) {
            if (apptSnap.hasError) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => logFirestoreIndexHelpOnce(
                  apptSnap.error,
                  tag: 'day_mgmt_appts_date',
                  expectedCompositeIndexHint: kAppointmentsDoctorDateStatusIndexHint,
                ),
              );
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    s.translate(
                      'doctors_load_error_detail',
                      params: {'error': '${apptSnap.error}'},
                    ),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'NRT',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (apptSnap.connectionState == ConnectionState.waiting &&
                !apptSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              );
            }

            final docs = apptSnap.data ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final bookedKeys = bookedTimeKeysHhMmForAvailableDay(
              sameDayDocs: docs,
              availableDayDocId: availableDayDocId,
            );
            final bookedCount = bookedKeys.length;

            final byTime = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final d in docs) {
              final row = d.data();
              final st =
                  (row[AppointmentFields.status] ?? '').toString().trim().toLowerCase();
              if (st == 'cancelled') continue;
              final t = normalizeAppointmentTimeToHhMm(row[AppointmentFields.time]);
              if (t.isEmpty) continue;
              final docAid =
                  (row[AppointmentFields.availableDayDocId] ?? '').toString().trim();
              if (docAid.isNotEmpty && docAid != availableDayDocId) continue;
              byTime.putIfAbsent(t, () => d);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFF1D1E33),
                  child: Text(
                    s.translate(
                      'available_day_manage_patient_count',
                      params: {'n': '$bookedCount'},
                    ),
                    style: const TextStyle(
                      fontFamily: 'NRT',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF93C5FD),
                      fontSize: 15,
                    ),
                  ),
                ),
                Expanded(
                  child: slots.isEmpty
                      ? Center(
                          child: Text(
                            s.translate('day_mgmt_no_slots'),
                            style: const TextStyle(
                              color: Color(0xFF829AB1),
                              fontFamily: 'NRT',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: slots.length,
                          itemBuilder: (context, i) {
                            final slot = slots[i];
                            final key = formatTimeHhMm(slot);
                            final timePretty = DateFormat.jm(localeTag).format(slot);
                            final appt = byTime[key];

                            if (appt != null) {
                              final row = appt.data();
                              final name =
                                  (row[AppointmentFields.patientName] ?? '—').toString().trim();
                              final pid =
                                  (row[AppointmentFields.patientId] ?? '').toString().trim();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                color: const Color(0xFF16213E),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 84,
                                        child: Text(
                                          timePretty,
                                          style: const TextStyle(
                                            fontFamily: 'NRT',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF93C5FD),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: pid.isEmpty
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontFamily: 'NRT',
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFFE8EEF4),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    s.translate(
                                                      'doctor_appt_not_available',
                                                    ),
                                                    style: const TextStyle(
                                                      fontFamily: 'NRT',
                                                      fontSize: 12,
                                                      color: Color(0xFF829AB1),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : StreamBuilder<
                                                DocumentSnapshot<Map<String, dynamic>>>(
                                                stream: FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(pid)
                                                    .snapshots(),
                                                builder: (context, userSnap) {
                                                  final phone = patientPhoneFromUserData(
                                                    userSnap.data?.data(),
                                                  );
                                                  final hasPhone = phone.isNotEmpty;
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontFamily: 'NRT',
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFFE8EEF4),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              hasPhone
                                                                  ? phone
                                                                  : s.translate(
                                                                      'doctor_appt_not_available',
                                                                    ),
                                                              style: TextStyle(
                                                                fontFamily: 'NRT',
                                                                fontSize: 13,
                                                                color: hasPhone
                                                                    ? const Color(
                                                                        0xFFCBD5E1,
                                                                      )
                                                                    : const Color(
                                                                        0xFF829AB1,
                                                                      ),
                                                              ),
                                                            ),
                                                          ),
                                                          if (hasPhone)
                                                            IconButton(
                                                              tooltip: s.translate(
                                                                'daily_slots_call',
                                                              ),
                                                              onPressed: () =>
                                                                  _launchTel(context, phone),
                                                              icon: const Icon(
                                                                Icons.call_rounded,
                                                                color: Color(0xFF4ADE80),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      _DayAppointmentStatusPill(
                                        rawStatus:
                                            row[AppointmentFields.status],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 84,
                                        child: Text(
                                          timePretty,
                                          style: const TextStyle(
                                            fontFamily: 'NRT',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          s.translate('daily_slots_status_available'),
                                          style: const TextStyle(
                                            fontFamily: 'NRT',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF4ADE80),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DayAppointmentStatusPill extends StatelessWidget {
  const _DayAppointmentStatusPill({required this.rawStatus});

  final dynamic rawStatus;

  @override
  Widget build(BuildContext context) {
    final st = (rawStatus ?? 'pending').toString().trim().toLowerCase();
    final badge = appointmentStatusBadgeColors(st);
    final loc = S.of(context);
    final String label;
    switch (st) {
      case 'completed':
        label = loc.translate('status_completed');
        break;
      case 'cancelled':
      case 'canceled':
        label = loc.translate('status_cancelled');
        break;
      case 'confirmed':
        label = loc.translate('status_confirmed');
        break;
      case 'arrived':
        label = loc.translate('status_arrived');
        break;
      default:
        label = loc.translate('status_pending');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badge.$1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.75,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badge.$2,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFamily: 'NRT',
        ),
      ),
    );
  }
}
