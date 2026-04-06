import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/fcm/v1.dart' as fcm_api;
import 'package:googleapis_auth/auth_io.dart';

/// Sends FCM v1 messages using OAuth2 from a Firebase service-account JSON and
/// the generated [fcm_api.FirebaseCloudMessagingApi] client (package:googleapis).
Future<void> sendDoctorRejectionPushWithServiceAccountJson({
  required String serviceAccountJson,
  required Set<String> recipientKeys,
  required String title,
  required String body,
  required String appointmentId,
  required String type,
}) async {
  final map =
      jsonDecode(serviceAccountJson) as Map<String, dynamic>? ?? <String, dynamic>{};
  final projectId = (map['project_id'] ?? '').toString().trim();
  if (projectId.isEmpty) {
    debugPrint('[DoctorFcm] service-account.json: missing project_id');
    return;
  }

  final creds = ServiceAccountCredentials.fromJson(map);
  final client = await clientViaServiceAccount(
    creds,
    [fcm_api.FirebaseCloudMessagingApi.firebaseMessagingScope],
  );

  try {
    final tokens = await _collectDeviceTokens(recipientKeys);
    if (tokens.isEmpty) {
      debugPrint('[DoctorFcm] No device tokens for $recipientKeys');
      return;
    }

    final api = fcm_api.FirebaseCloudMessagingApi(client);
    final parent = 'projects/$projectId';

    for (final token in tokens) {
      final req = fcm_api.SendMessageRequest(
        message: fcm_api.Message(
          token: token,
          notification: fcm_api.Notification(title: title, body: body),
          data: {
            'type': type,
            'appointmentId': appointmentId,
            'title': title,
            'body': body,
          },
          android: fcm_api.AndroidConfig(priority: 'HIGH'),
          apns: fcm_api.ApnsConfig(
            payload: <String, Object?>{
              'aps': <String, Object?>{
                'sound': 'default',
              },
            },
          ),
        ),
      );
      try {
        await api.projects.messages.send(req, parent);
      } catch (e, st) {
        debugPrint('[DoctorFcm] FCM send error: $e\n$st');
      }
    }
  } finally {
    client.close();
  }
}

Future<Set<String>> _collectDeviceTokens(Set<String> keys) async {
  final tokens = <String>{};
  for (final id in keys) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) continue;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(trimmed).get();
    final data = doc.data() ?? {};
    final map = data['fcmTokens'];
    if (map is Map) {
      for (final k in map.keys) {
        final s = k.toString();
        if (s.length > 20) tokens.add(s);
      }
    }
    final legacy = data['fcmToken']?.toString();
    if (legacy != null && legacy.length > 20) tokens.add(legacy);
  }
  return tokens;
}
