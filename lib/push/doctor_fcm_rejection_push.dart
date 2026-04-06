import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../firestore/root_notifications_firestore.dart';
import 'doctor_fcm_rejection_push_stub.dart'
    if (dart.library.io) 'doctor_fcm_rejection_push_io.dart'
        as doctor_fcm_io;

/// Doctor-side FCM v1 send when a slot is rejected (uses [service-account.json]
/// in app assets + package:googleapis [FirebaseCloudMessagingApi]).
///
/// **Security:** Shipping a service-account key inside the app exposes full
/// Firebase/GCP access to reverse engineers. Prefer Cloud Functions for production.
class DoctorFcmRejectionPush {
  DoctorFcmRejectionPush._();

  static const _assetPaths = [
    'assets/service-account.json',
    'service-account.json',
  ];

  /// Loads the service account from the asset bundle, then sends one FCM message
  /// per device token found on each recipient user doc (`fcmTokens` / `fcmToken`).
  static Future<void> sendForDoctorReject({
    required Map<String, dynamic> appointmentData,
    required String appointmentDocId,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    String? jsonStr;
    for (final path in _assetPaths) {
      try {
        jsonStr = await rootBundle.loadString(path);
        break;
      } catch (_) {
        continue;
      }
    }
    if (jsonStr == null || jsonStr.isEmpty) {
      debugPrint(
        '[DoctorFcm] No service-account.json in bundle (optional). '
        'Add assets/service-account.json and list it in pubspec.yaml to enable client FCM v1.',
      );
      return;
    }

    final keys = recipientKeysFromAppointmentData(appointmentData);
    if (keys.isEmpty) return;

    await doctor_fcm_io.sendDoctorRejectionPushWithServiceAccountJson(
      serviceAccountJson: jsonStr,
      recipientKeys: keys,
      title: title,
      body: body,
      appointmentId: appointmentDocId,
      type: 'appointment_cancelled',
    );
  }
}
