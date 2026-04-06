import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firestore/root_notifications_firestore.dart';
import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';
import 'patient_notification_formatting.dart';

/// Premium glass-style notification row: doctor avatar, headline, message, badge, timeago, delete + swipe.
class PatientNotificationTile extends StatelessWidget {
  const PatientNotificationTile({
    super.key,
    required this.doc,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  static const Color _navy = Color(0xFF0D2137);
  static const Color _rejectRed = Color(0xFFC62828);
  static const Color _rejectTint = Color(0xFFFFEBEE);

  Future<bool> _confirmDelete(BuildContext context) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          s.translate('patient_notif_delete'),
          style: const TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          s.translate('patient_notif_delete_confirm'),
          style: const TextStyle(fontFamily: kPatientPrimaryFont),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.translate('schedule_slot_cancel_no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.translate('patient_notif_delete')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteDoc(BuildContext context) async {
    if (!await _confirmDelete(context) || !context.mounted) return;
    try {
      await doc.reference.delete();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).translate('patient_notif_delete'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final row = doc.data();
    final doctorName =
        (row[RootNotificationFields.doctorName] ?? '').toString().trim();
    final doctorImage =
        (row[RootNotificationFields.doctorImage] ?? '').toString().trim();
    final message = (row[RootNotificationFields.message] ?? '')
        .toString()
        .trim();
    final titleFallback =
        (row[RootNotificationFields.title] ?? 'نۆرینگە').toString();
    final type =
        (row[RootNotificationFields.type] ?? '').toString().toLowerCase();
    final isClinicClosed = type == 'clinic_closed';
    final isDoctorDayClosed = type == 'doctor_day_closed';
    final isRejected = type.contains('cancel') || isClinicClosed || isDoctorDayClosed;
    final created = notificationDisplayTime(row);
    final timeLabel = formatPatientNotificationTimestamp(
      context,
      created?.toDate(),
    );

    final headline = doctorName.isNotEmpty
        ? s.translate(
            'patient_notif_headline_doctor_rejected',
            params: {'name': doctorName},
          )
        : titleFallback;

    final badgeLabel = isClinicClosed
        ? s.translate('patient_notif_badge_clinic')
        : isDoctorDayClosed
            ? s.translate('patient_notif_badge_doctor_closed')
            : isRejected
                ? s.translate('patient_notif_badge_rejected')
                : s.translate('patient_notif_badge_update');

    final badgeColor = isClinicClosed
        ? const Color(0xFFEF6C00)
        : isDoctorDayClosed
            ? _rejectRed
            : isRejected
                ? _rejectRed
                : const Color(0xFF1565C0);
    final badgeBg = isClinicClosed
        ? const Color(0xFFFFF3E0)
        : isDoctorDayClosed
            ? _rejectTint
            : isRejected
                ? _rejectTint
                : const Color(0xFFE3F2FD);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DoctorAvatar(
                    imageUrl: doctorImage,
                    isRejected: isRejected,
                    isClinicClosed: isClinicClosed,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: badgeColor.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: badgeColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          badgeLabel,
                                          style: TextStyle(
                                            fontFamily: kPatientPrimaryFont,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (timeLabel.isNotEmpty)
                                    Text(
                                      timeLabel,
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: _navy.withValues(alpha: 0.45),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 22,
                                color: _navy.withValues(alpha: 0.42),
                              ),
                              onPressed: () => _deleteDoc(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          headline,
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.35,
                            color: _navy,
                          ),
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            message,
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.4,
                              color: (isRejected && !isClinicClosed)
                                  ? _rejectRed.withValues(alpha: 0.92)
                                  : _navy.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Dismissible(
        key: ValueKey<String>('notif_${doc.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) async {
          try {
            await doc.reference.delete();
          } catch (_) {}
        },
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: 24),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _rejectRed.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: card,
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({
    required this.imageUrl,
    required this.isRejected,
    required this.isClinicClosed,
  });

  final String imageUrl;
  final bool isRejected;
  final bool isClinicClosed;

  @override
  Widget build(BuildContext context) {
    final borderColor = isClinicClosed
        ? const Color(0xFFFFB74D).withValues(alpha: 0.85)
        : isRejected
            ? const Color(0xFFE57373).withValues(alpha: 0.65)
            : const Color(0xFF90CAF9).withValues(alpha: 0.7);

    Widget child;
    if (imageUrl.isNotEmpty) {
      child = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (context, url) => const _AvatarPlaceholder(),
          errorWidget: (context, url, error) => const _AvatarPlaceholder(),
        ),
      );
    } else {
      child = const _AvatarPlaceholder();
    }

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(child: child),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFFE8EEF4),
      child: const Icon(
        Icons.person_rounded,
        size: 30,
        color: Color(0xFF78909C),
      ),
    );
  }
}
