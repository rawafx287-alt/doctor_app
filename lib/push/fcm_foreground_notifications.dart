import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'fcm_cancellation_sync.dart';

/// Android channel id — must match
/// `com.google.firebase.messaging.default_notification_channel_id` in manifest.
const String kFcmAndroidChannelId = 'hr_nora_default';

/// Shown in system notification settings (Android).
const String kFcmAndroidChannelName = 'ئاگاداری نۆرە';

/// Shows lock-screen / heads-up style notifications while the app is in the
/// foreground (Android). iOS uses [FirebaseMessaging] presentation options.
class FcmForegroundNotifications {
  FcmForegroundNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inited = false;
  static int _id = 0;

  static Future<void> init() async {
    if (kIsWeb || _inited) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    const channel = AndroidNotificationChannel(
      kFcmAndroidChannelId,
      kFcmAndroidChannelName,
      description: 'ئاگاداری نۆرە و هەڵوەشاندنەوە',
      importance: Importance.high,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _inited = true;
  }

  /// Displays [message] as a system notification when the app is foregrounded.
  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    if (kIsWeb || !_inited) return;

    await syncLocalRemindersForRemoteCancellation(message);

    final n = message.notification;
    var title = (n?.title ?? '').trim();
    var body = (n?.body ?? '').trim();
    if (title.isEmpty) {
      title = (message.data['title'] ?? message.data['gcm.notification.title'] ?? '')
          .toString()
          .trim();
    }
    if (body.isEmpty) {
      body = (message.data['body'] ??
              message.data['message'] ??
              message.data['gcm.notification.body'] ??
              '')
          .toString()
          .trim();
    }
    if (title.isEmpty && body.isEmpty) return;

    final android = AndroidNotificationDetails(
      kFcmAndroidChannelId,
      kFcmAndroidChannelName,
      channelDescription: 'ئاگاداری نۆرە و هەڵوەشاندنەوە',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    _id = (_id + 1) & 0x7fffffff;
    await _plugin.show(
      id: _id,
      title: title.isEmpty ? kFcmAndroidChannelName : title,
      body: body.isEmpty ? null : body,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: iosDetails,
      ),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }
}
