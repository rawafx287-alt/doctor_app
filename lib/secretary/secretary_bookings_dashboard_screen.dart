import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/app_logout.dart';
import '../firestore/appointment_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../theme/staff_premium_theme.dart';
import '../widgets/appointment_action_confirm_dialog.dart';

DateTime? _parseAppointmentDay(dynamic value) {
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

int _timeSortMinutes(dynamic timeVal) {
  final s = (timeVal ?? '').toString().trim();
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
  if (m != null) {
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }
  return 1 << 20;
}

void _sortAppointmentsByDateThenTime(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> list,
) {
  list.sort((a, b) {
    final da = _parseAppointmentDay(a.data()[AppointmentFields.date]);
    final db = _parseAppointmentDay(b.data()[AppointmentFields.date]);
    if (da != null && db != null) {
      final c = da.compareTo(db);
      if (c != 0) return c;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    return _timeSortMinutes(a.data()[AppointmentFields.time])
        .compareTo(_timeSortMinutes(b.data()[AppointmentFields.time]));
  });
}

/// Secretary: all appointments for a selected doctor, chronological order, status + payment actions.
class SecretaryBookingsDashboardScreen extends StatefulWidget {
  const SecretaryBookingsDashboardScreen({super.key});

  @override
  State<SecretaryBookingsDashboardScreen> createState() =>
      _SecretaryBookingsDashboardScreenState();
}

class _SecretaryBookingsDashboardScreenState
    extends State<SecretaryBookingsDashboardScreen> {
  String? _pickedDoctorId;
  final Set<String> _updating = {};

  Future<void> _setStatus(String docId, String status) async {
    final id = docId.trim();
    if (id.isEmpty) return;
    setState(() => _updating.add(id));
    try {
      await FirebaseFirestore.instance
          .collection(AppointmentFields.collection)
          .doc(id)
          .update({
            AppointmentFields.status: status,
            AppointmentFields.updatedAt: FieldValue.serverTimestamp(),
          });
    } finally {
      if (mounted) {
        setState(() => _updating.remove(id));
      }
    }
  }

  Future<void> _confirmAndSetStatus(
    BuildContext context,
    String docId,
    String status,
  ) async {
    final st = status.trim().toLowerCase();
    if (st == 'completed' ||
        st == 'cancelled' ||
        st == 'canceled') {
      final ok = await showAppointmentActionConfirmDialog(
        context,
        isCompleteAction: st == 'completed',
      );
      if (ok != true || !context.mounted) return;
    }
    await _setStatus(docId, status);
  }

  void _showReceiptDialog(BuildContext context, String url) {
    final u = url.trim();
    if (u.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: AppLocaleScope.of(ctx).textDirection,
          child: Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(S.of(ctx).translate('secretary_view_receipt')),
                  leading: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: u,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic raw) {
    final d = _parseAppointmentDay(raw);
    if (d != null) {
      return DateFormat('yyyy/MM/dd', 'en_US').format(d);
    }
    if (raw == null) return '—';
    final s = raw.toString().trim();
    return s.isEmpty ? '—' : staffDigitsToEnglishAscii(s);
  }

  String _paymentLabel(BuildContext context, Map<String, dynamic> data) {
    final pm = (data[AppointmentFields.paymentMethod] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final s = S.of(context);
    if (pm == 'digital') return s.translate('secretary_payment_digital');
    if (pm == 'cash') return s.translate('secretary_payment_cash');
    return '—';
  }

  /// Localized appointment status label (e.g. CKB: چاوەڕوان, تەواو, پاشەکشە).
  String _localizedPatientAppointmentStatus(
    BuildContext context,
    String rawStatus,
  ) {
    final loc = S.of(context);
    final s = rawStatus.trim().toLowerCase();
    switch (s) {
      case 'completed':
        return loc.translate('status_completed');
      case 'cancelled':
      case 'canceled':
        return loc.translate('status_cancelled');
      case 'confirmed':
        return loc.translate('status_confirmed');
      case 'arrived':
        return loc.translate('status_arrived');
      case 'pending':
      default:
        return loc.translate('status_pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: kStaffPrimaryNavy,
          foregroundColor: const Color(0xFFD9E2EC),
          title: Text(
            s.translate('secretary_bookings_title'),
            style: staffAppBarTitleStyle().copyWith(
              color: const Color(0xFFD9E2EC),
            ),
          ),
          actions: [
            IconButton(
              tooltip: s.translate('tooltip_logout'),
              onPressed: () => performAppLogout(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'Doctor')
                      .where('isApproved', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const LinearProgressIndicator(minHeight: 2);
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Text(
                        s.translate('master_calendar_no_doctors'),
                        style: staffLabelTextStyle(),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _pickedDoctorId != null &&
                              docs.any((d) => d.id == _pickedDoctorId)
                          ? _pickedDoctorId
                          : null,
                      dropdownColor: kStaffCardSurface,
                      decoration: InputDecoration(
                        labelText: s.translate('master_calendar_pick_doctor'),
                        labelStyle: staffLabelTextStyle(),
                        filled: true,
                        fillColor: kStaffCardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kStaffSilverBorder,
                            width: kStaffCardOutlineWidth,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kStaffSilverBorder,
                            width: kStaffCardOutlineWidth,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kStaffPrimaryNavy,
                            width: 1.2,
                          ),
                        ),
                      ),
                      items: docs
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                localizedDoctorFullName(
                                  d.data(),
                                  AppLocaleScope.of(context).effectiveLanguage,
                                ),
                                style: staffHeaderTextStyle(
                                  fontSize: 15,
                                  color: kStaffBodyText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _pickedDoctorId = v),
                    );
                  },
                ),
              ),
              Expanded(
                child: _pickedDoctorId == null
                    ? Center(
                        child: Text(
                          s.translate('master_calendar_pick_doctor'),
                          style: staffLabelTextStyle(),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection(AppointmentFields.collection)
                            .where(
                              AppointmentFields.doctorId,
                              isEqualTo: _pickedDoctorId!.trim(),
                            )
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: kStaffPrimaryNavy,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            );
                          }
                          final docs = List<
                              QueryDocumentSnapshot<
                                  Map<String, dynamic>>>.from(
                            snapshot.data?.docs ?? [],
                          );
                          _sortAppointmentsByDateThenTime(docs);

                          if (docs.isEmpty) {
                            return Center(
                              child: Text(
                                s.translate('secretary_bookings_empty'),
                                style: staffLabelTextStyle(),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              16 + MediaQuery.paddingOf(context).bottom,
                            ),
                            itemCount: docs.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final doc = docs[i];
                              final data = doc.data();
                              final st = (data[AppointmentFields.status] ??
                                      'pending')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              final patient =
                                  (data[AppointmentFields.patientName] ?? '—')
                                      .toString();
                              final time =
                                  (data[AppointmentFields.time] ?? '—')
                                      .toString();
                              final dateStr =
                                  _formatDate(data[AppointmentFields.date]);
                              final queue = (data[AppointmentFields.queueNumber])
                                  .toString();
                              final receiptUrl =
                                  (data[AppointmentFields.receiptUrl] ?? '')
                                      .toString()
                                      .trim();
                              final busy = _updating.contains(doc.id);
                              final badge = staffAppointmentStatusBadgeStyle(st);
                              final timeEn = staffDigitsToEnglishAscii(time);
                              final queueEn = staffDigitsToEnglishAscii(
                                queue.isEmpty ? '—' : queue,
                              );

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: kStaffSilverBorder,
                                    width: kStaffCardOutlineWidth,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kStaffPrimaryNavy
                                          .withValues(alpha: 0.07),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        width: 4,
                                        color: kStaffAccentSlateBlue,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            14,
                                            14,
                                            14,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          s.translate(
                                                            'doctor_appt_patient_name_label',
                                                          ),
                                                          style:
                                                              staffLabelTextStyle(
                                                            fontSize: 11,
                                                          ).copyWith(
                                                            color:
                                                                kStaffAccentSlateBlue
                                                                    .withValues(
                                                              alpha: 0.78,
                                                            ),
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          patient,
                                                          style:
                                                              staffHeaderTextStyle(
                                                            fontSize: 16,
                                                          ).copyWith(
                                                            color:
                                                                kStaffAccentSlateBlue,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                    decoration:
                                                        badge.decoration,
                                                    child: Text(
                                                      _localizedPatientAppointmentStatus(
                                                        context,
                                                        st,
                                                      ),
                                                      style: TextStyle(
                                                        color: badge.foreground,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontFamily:
                                                            kPatientPrimaryFont,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Divider(
                                                height: 22,
                                                thickness: 0.8,
                                                color: kStaffLuxGold
                                                    .withValues(alpha: 0.42),
                                              ),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .calendar_today_outlined,
                                                    size: 16,
                                                    color: kStaffLuxGold,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Wrap(
                                                      spacing: 6,
                                                      runSpacing: 4,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          '${s.translate('ticket_date')}: ',
                                                          style:
                                                              staffLabelTextStyle(
                                                            fontSize: 12.5,
                                                          ),
                                                        ),
                                                        Directionality(
                                                          textDirection:
                                                              ui.TextDirection.ltr,
                                                          child: Text(
                                                            dateStr,
                                                            style:
                                                                staffLabelTextStyle(
                                                              fontSize: 12.5,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          '·',
                                                          style: TextStyle(
                                                            color: kStaffLuxGold
                                                                .withValues(
                                                              alpha: 0.75,
                                                            ),
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons
                                                              .access_time_rounded,
                                                          size: 16,
                                                          color: kStaffLuxGold,
                                                        ),
                                                        Text(
                                                          '${s.translate('ticket_time')}: ',
                                                          style:
                                                              staffLabelTextStyle(
                                                            fontSize: 12.5,
                                                          ),
                                                        ),
                                                        Directionality(
                                                          textDirection:
                                                              ui.TextDirection.ltr,
                                                          child: Text(
                                                            timeEn,
                                                            style:
                                                                staffLabelTextStyle(
                                                              fontSize: 12.5,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          '·',
                                                          style: TextStyle(
                                                            color: kStaffLuxGold
                                                                .withValues(
                                                              alpha: 0.75,
                                                            ),
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                          ),
                                                        ),
                                                        Text(
                                                          '#',
                                                          style:
                                                              staffLabelTextStyle(
                                                            fontSize: 12.5,
                                                          ),
                                                        ),
                                                        Directionality(
                                                          textDirection:
                                                              ui.TextDirection.ltr,
                                                          child: Text(
                                                            queueEn,
                                                            style:
                                                                staffLabelTextStyle(
                                                              fontSize: 12.5,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Divider(
                                                height: 22,
                                                thickness: 0.8,
                                                color: kStaffLuxGold
                                                    .withValues(alpha: 0.42),
                                              ),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.payments_outlined,
                                                    size: 18,
                                                    color: kStaffLuxGold,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      _paymentLabel(
                                                          context, data),
                                                      style:
                                                          staffLabelTextStyle(
                                                        fontSize: 14,
                                                        color: kStaffBodyText,
                                                      ),
                                                    ),
                                                  ),
                                                  if (receiptUrl.isNotEmpty)
                                                    TextButton.icon(
                                                      onPressed: busy
                                                          ? null
                                                          : () =>
                                                              _showReceiptDialog(
                                                                context,
                                                                receiptUrl,
                                                              ),
                                                      style: TextButton
                                                          .styleFrom(
                                                        foregroundColor:
                                                            kStaffLuxGoldDark,
                                                      ),
                                                      icon: Icon(
                                                        Icons
                                                            .receipt_long_rounded,
                                                        size: 18,
                                                        color: kStaffLuxGold,
                                                      ),
                                                      label: Text(
                                                        s.translate(
                                                          'secretary_view_receipt',
                                                        ),
                                                        style:
                                                            staffLabelTextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              kStaffLuxGoldDark,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        StaffGoldGradientButton(
                                          label: s.translate(
                                            'secretary_action_confirm',
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => _setStatus(
                                                    doc.id,
                                                    'confirmed',
                                                  ),
                                        ),
                                        StaffGoldGradientButton(
                                          label: s.translate(
                                            'secretary_action_arrived',
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => _setStatus(
                                                    doc.id,
                                                    'arrived',
                                                  ),
                                        ),
                                        StaffGoldGradientButton(
                                          label: s.translate(
                                            'secretary_action_completed',
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => _confirmAndSetStatus(
                                                    context,
                                                    doc.id,
                                                    'completed',
                                                  ),
                                        ),
                                        _StaffCancelActionButton(
                                          label: s.translate(
                                            'secretary_action_cancel',
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => _confirmAndSetStatus(
                                                    context,
                                                    doc.id,
                                                    'cancelled',
                                                  ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCancelActionButton extends StatelessWidget {
  const _StaffCancelActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFB71C1C),
        side: const BorderSide(
          color: Color(0xFFC62828),
          width: kStaffCardOutlineWidth,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
