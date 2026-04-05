import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'appointment_queries.dart';

/// Top-level [notifications] collection — patient apps listen with
/// `arrayContains` on [RootNotificationFields.recipientKeys].
abstract final class RootNotificationFields {
  static const String collection = 'notifications';

  /// Firestore user doc ids that should receive this row (patientId, userId, …).
  static const String recipientKeys = 'recipientKeys';

  /// Primary [AppointmentFields.patientId] for rules/debugging.
  static const String patientId = 'patientId';

  static const String message = 'message';
  static const String title = 'title';

  /// Server time; used for ordering (composite index with [recipientKeys]).
  static const String timestamp = 'timestamp';

  /// `unread` | `read`
  static const String status = 'status';

  static const String appointmentId = 'appointmentId';
  static const String type = 'type';
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

/// Kurdish body for bulk day closure (matches Cloud Function copy).
const String kClinicClosurePatientNotificationMessageKu =
    'ئاگاداری: نۆرینگە لە ڕێکەوتی {date} داخراوە، تکایە نۆرەیەکی نوێ وەربگرە.';

String formatAppointmentDateForNotificationKu(Map<String, dynamic> data) {
  final raw = data[AppointmentFields.date];
  if (raw is Timestamp) {
    final d = raw.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
  final s = raw?.toString().trim() ?? '';
  return s.isEmpty ? '—' : s;
}

/// Creates a patient-visible notification row and triggers server FCM via
/// [onNotificationCreated] Cloud Function.
Future<void> createPatientRootNotification({
  required Map<String, dynamic> appointmentData,
  required String appointmentDocId,
  required String message,
  String title = 'نۆرینگە',
  String type = 'appointment_cancelled',
}) async {
  final keys = recipientKeysFromAppointmentData(appointmentData);
  if (keys.isEmpty) return;
  final pid =
      (appointmentData[AppointmentFields.patientId] ?? '').toString().trim();
  await FirebaseFirestore.instance
      .collection(RootNotificationFields.collection)
      .add({
    RootNotificationFields.recipientKeys: keys.toList(),
    RootNotificationFields.patientId: pid.isNotEmpty ? pid : keys.first,
    RootNotificationFields.message: message,
    RootNotificationFields.title: title,
    RootNotificationFields.timestamp: FieldValue.serverTimestamp(),
    RootNotificationFields.status: 'unread',
    RootNotificationFields.appointmentId: appointmentDocId,
    RootNotificationFields.type: type,
  });
}

Query<Map<String, dynamic>> rootNotificationsForRecipientQuery(
  String recipientKey,
) {
  return FirebaseFirestore.instance
      .collection(RootNotificationFields.collection)
      .where(
        RootNotificationFields.recipientKeys,
        arrayContains: recipientKey,
      )
      .orderBy(RootNotificationFields.timestamp, descending: true)
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
      final ta = a.data()[RootNotificationFields.timestamp];
      final tb = b.data()[RootNotificationFields.timestamp];
      final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
      final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
      return mb.compareTo(ma);
    }

    void emit() {
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snap in latest.values) {
        for (final d in snap.docs) {
          byId[d.id] = d;
        }
      }
      final out = byId.values.toList()..sort(compareDocs);
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

Stream<QuerySnapshot<Map<String, dynamic>>> unreadRootNotificationsSnapshot(
  String recipientKey,
) {
  return FirebaseFirestore.instance
      .collection(RootNotificationFields.collection)
      .where(RootNotificationFields.recipientKeys, arrayContains: recipientKey)
      .where(RootNotificationFields.status, isEqualTo: 'unread')
      .limit(1)
      .snapshots();
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

    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final k in list) {
      hasUnread[k] = false;
      subs.add(
        unreadRootNotificationsSnapshot(k).listen(
          (snap) {
            hasUnread[k] = snap.docs.isNotEmpty;
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
