import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'appointment_queries.dart';

/// Top-level [notifications] collection — patient apps query
/// `where(patientId == …).orderBy(createdAt desc)` (matches Firestore composite index).
abstract final class RootNotificationFields {
  static const String collection = 'notifications';

  /// Firestore user doc ids that should receive this row (patientId, userId, …).
  static const String recipientKeys = 'recipientKeys';

  /// Indexed with [createdAt] for patient list queries.
  static const String patientId = 'patientId';

  static const String message = 'message';
  static const String title = 'title';

  /// Prefer for ordering and display (matches your Firestore index).
  static const String createdAt = 'createdAt';

  /// Legacy field on older rows; fallback when [createdAt] is missing.
  static const String timestamp = 'timestamp';

  /// `unread` | `read`
  static const String status = 'status';

  static const String appointmentId = 'appointmentId';
  static const String type = 'type';

  /// Display name from `users/{doctorId}` when staff rejects a slot.
  static const String doctorName = 'doctorName';

  /// Profile image URL (`profileImageUrl` on doctor user doc).
  static const String doctorImage = 'doctorImage';
}

/// Doctor profile snippet stored on each [notifications] row for patient UI.
class DoctorNotificationSnapshot {
  const DoctorNotificationSnapshot({this.name = '', this.imageUrl = ''});

  final String name;
  final String imageUrl;

  bool get hasName => name.trim().isNotEmpty;
}

/// Loads [fullName_ku] / [fullName] / [name] and [profileImageUrl] for FCM + notifications.
Future<DoctorNotificationSnapshot> loadDoctorNotificationSnapshot(
  String doctorUserId,
) async {
  final id = doctorUserId.trim();
  if (id.isEmpty) return const DoctorNotificationSnapshot();
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(id).get();
    final data = doc.data() ?? {};
    final name = (data['fullName_ku'] ??
            data['fullName'] ??
            data['name'] ??
            '')
        .toString()
        .trim();
    final imageUrl = (data['profileImageUrl'] ?? '').toString().trim();
    return DoctorNotificationSnapshot(name: name, imageUrl: imageUrl);
  } catch (_) {
    return const DoctorNotificationSnapshot();
  }
}

Set<String> recipientKeysFromAppointmentData(Map<String, dynamic> data) {
  final keys = <String>{};
  for (final field in [
    AppointmentFields.patientId,
    AppointmentFields.userId,
  ]) {
    final v = (data[field] ?? '').toString().trim();
    if (v.isNotEmpty) keys.add(v);
  }
  return keys;
}

/// Stable day key for deduping clinic-closure notifications per patient.
String? appointmentNotificationDayKey(Map<String, dynamic> data) {
  final raw = data[AppointmentFields.date];
  if (raw is Timestamp) {
    final d = raw.toDate();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})').firstMatch(s);
  if (m != null) {
    return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-${m.group(3)!.padLeft(2, '0')}';
  }
  return null;
}

/// System + in-app title for slot rejection / cancel pushes.
const String kPatientPushTitleAppointmentRejectedKu = 'ئاگاداری نۆرە';

/// Body template for FCM + notifications list (`[Date]` = `yyyy/MM/dd`).
String patientPushBodyAppointmentRejectedKu(String dateLabel) =>
    'ببوورە، نۆرەکەت لە ڕێکەوتی $dateLabel ڕەتکرایەوە.';

/// Title + message for doctor/secretary cancel and per-slot bulk (non–clinic-closed).
(String title, String message) patientAppointmentRejectedNotificationCopy(
  Map<String, dynamic> appointmentData,
) {
  final dateLabel = formatAppointmentDateForNotificationKu(appointmentData);
  return (
    kPatientPushTitleAppointmentRejectedKu,
    patientPushBodyAppointmentRejectedKu(dateLabel),
  );
}

/// Kurdish body for bulk day closure (matches Cloud Function copy).
const String kClinicClosurePatientNotificationMessageKu =
    'ئاگاداری: نۆرینگە لە ڕێکەوتی {date} داخراوە، تکایە نۆرەیەکی نوێ وەربگرە.';

/// SMS / push stub (no gateway yet): clinic closed, date placeholder is [dateLabel] `yyyy/MM/dd`.
String clinicClosePatientNotificationStubMessageKu(String dateLabel) =>
    'نەخۆشی بەڕێز، نۆرەکەت بۆ ڕێکەوتی $dateLabel بەهۆی داخستنی کلینیکەوە ڕەتکرایەوە.';

/// Temporary stand-in until a real SMS/push gateway is wired; logs to console.
void sendPatientNotification(String patientId, String message) {
  final id = patientId.trim();
  if (id.isEmpty) return;
  debugPrint('[sendPatientNotification] patientId=$id\n$message');
}

String formatAppointmentDateForNotificationKu(Map<String, dynamic> data) {
  final raw = data[AppointmentFields.date];
  if (raw is Timestamp) {
    final d = raw.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
  final s = raw?.toString().trim() ?? '';
  return s.isEmpty ? '—' : s;
}

/// Display time for list tiles (prefers [RootNotificationFields.createdAt]).
Timestamp? notificationDisplayTime(Map<String, dynamic> data) {
  final c = data[RootNotificationFields.createdAt];
  if (c is Timestamp) return c;
  final t = data[RootNotificationFields.timestamp];
  if (t is Timestamp) return t;
  return null;
}

int _notificationTimeMs(Map<String, dynamic> data) {
  final t = notificationDisplayTime(data);
  return t?.millisecondsSinceEpoch ?? 0;
}

String _mergeDedupeKey(Map<String, dynamic> data, String docId) {
  final appt =
      (data[RootNotificationFields.appointmentId] ?? '').toString().trim();
  if (appt.isNotEmpty) return appt;
  return docId;
}

/// Creates patient-visible notification rows (one per recipient id so each
/// login alias matches `patientId` queries) and triggers FCM via Cloud Function.
Future<void> createPatientRootNotification({
  required Map<String, dynamic> appointmentData,
  required String appointmentDocId,
  required String message,
  String title = 'نۆرینگە',
  String type = 'appointment_cancelled',
  DoctorNotificationSnapshot doctor = const DoctorNotificationSnapshot(),
}) async {
  final keys = recipientKeysFromAppointmentData(appointmentData);
  if (keys.isEmpty) return;
  final dn = doctor.name.trim();
  final di = doctor.imageUrl.trim();
  final batch = FirebaseFirestore.instance.batch();
  for (final key in keys) {
    final ref =
        FirebaseFirestore.instance.collection(RootNotificationFields.collection).doc();
    batch.set(ref, {
      RootNotificationFields.patientId: key,
      RootNotificationFields.recipientKeys: [key],
      RootNotificationFields.message: message,
      RootNotificationFields.title: title,
      RootNotificationFields.createdAt: FieldValue.serverTimestamp(),
      RootNotificationFields.timestamp: FieldValue.serverTimestamp(),
      RootNotificationFields.status: 'unread',
      RootNotificationFields.appointmentId: appointmentDocId,
      RootNotificationFields.type: type,
      RootNotificationFields.doctorName: dn,
      RootNotificationFields.doctorImage: di,
    });
  }
  await batch.commit();
}

Query<Map<String, dynamic>> rootNotificationsForRecipientQuery(
  String recipientKey,
) {
  return FirebaseFirestore.instance
      .collection(RootNotificationFields.collection)
      .where(
        RootNotificationFields.patientId,
        isEqualTo: recipientKey,
      )
      .orderBy(RootNotificationFields.createdAt, descending: true)
      .limit(50);
}

/// Merges notifications for every login alias (uid vs phone doc id, etc.).
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    watchRootNotificationsForRecipientKeys(Set<String> keys) {
  final list = keys.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (list.isEmpty) {
    return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value(
      const [],
    );
  }
  if (list.length == 1) {
    return rootNotificationsForRecipientQuery(list.first).snapshots().map(
          (s) => s.docs,
        );
  }
  return Stream.multi((controller) {
    final latest = <String, QuerySnapshot<Map<String, dynamic>>>{};

    int compareDocs(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
    ) {
      final ma = _notificationTimeMs(a.data());
      final mb = _notificationTimeMs(b.data());
      return mb.compareTo(ma);
    }

    void emit() {
      final byDedupe =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snap in latest.values) {
        for (final d in snap.docs) {
          final data = d.data();
          final k = _mergeDedupeKey(data, d.id);
          final existing = byDedupe[k];
          if (existing == null ||
              _notificationTimeMs(data) > _notificationTimeMs(existing.data())) {
            byDedupe[k] = d;
          }
        }
      }
      final out = byDedupe.values.toList()..sort(compareDocs);
      controller.add(out);
    }

    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final k in list) {
      subs.add(
        rootNotificationsForRecipientQuery(k).snapshots().listen(
          (event) {
            latest[k] = event;
            emit();
          },
          onError: controller.addError,
        ),
      );
    }
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
  });
}

/// Whether this user has any unread notification (uses only the patientId+createdAt index).
Stream<bool> unreadRootNotificationsSnapshot(String recipientKey) {
  return FirebaseFirestore.instance
      .collection(RootNotificationFields.collection)
      .where(RootNotificationFields.patientId, isEqualTo: recipientKey)
      .orderBy(RootNotificationFields.createdAt, descending: true)
      .limit(40)
      .snapshots()
      .map(
        (snap) => snap.docs.any(
          (d) =>
              (d.data()[RootNotificationFields.status] ?? '').toString() ==
              'unread',
        ),
      );
}

/// One notification per distinct patient-day for clinic closure (avoids spam).
Stream<bool> watchHasUnreadRootNotificationAnyKey(Set<String> keys) {
  final list = keys.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (list.isEmpty) {
    return Stream<bool>.value(false);
  }
  return Stream.multi((controller) {
    final hasUnread = <String, bool>{};

    void emit() {
      controller.add(hasUnread.values.any((v) => v));
    }

    final subs = <StreamSubscription<bool>>[];
    for (final k in list) {
      hasUnread[k] = false;
      subs.add(
        unreadRootNotificationsSnapshot(k).listen(
          (unread) {
            hasUnread[k] = unread;
            emit();
          },
          onError: controller.addError,
        ),
      );
    }
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
  });
}
