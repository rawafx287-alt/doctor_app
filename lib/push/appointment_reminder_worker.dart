import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'appointment_local_notifications.dart';

/// Background worker: every ~15 min checks upcoming bookings and triggers
/// instant notifications when entering the 3h/1h windows (best-effort).
///
/// This avoids relying only on alarm scheduling which may be delayed or blocked
/// on some devices.
class AppointmentReminderWorker {
  AppointmentReminderWorker._();

  static const String taskName = 'hr_nora_appt_reminder_poll';
  static const String _prefsKey = 'hr_nora_local_appt_reminders_v1';

  static Future<void> registerPeriodic() async {
    if (kIsWeb) return;
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
  }

  /// Save/update a booking for background reminders.
  static Future<void> upsertBooking({
    required String appointmentId,
    required DateTime appointmentTimeLocal,
    required String doctorName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey) ?? '[]';
    final list = (jsonDecode(raw) as List<dynamic>).cast<dynamic>();

    list.removeWhere((e) => e is Map && e['id'] == appointmentId);
    list.add({
      'id': appointmentId,
      'atMs': appointmentTimeLocal.millisecondsSinceEpoch,
      'doctor': doctorName,
      'notified3h': false,
      'notified1h': false,
    });

    await prefs.setString(_prefsKey, jsonEncode(list));
  }

  static Future<void> removeBooking(String appointmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey) ?? '[]';
    final list = (jsonDecode(raw) as List<dynamic>).cast<dynamic>();
    list.removeWhere((e) => e is Map && e['id'] == appointmentId);
    await prefs.setString(_prefsKey, jsonEncode(list));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

@pragma('vm:entry-point')
void appointmentReminderCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (kIsWeb) return true;

    // Ensure notifications + timezone are ready in the background isolate.
    await AppointmentLocalNotifications.init();
    await AppointmentLocalNotifications.ensureTimeZoneInitialized();

    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(AppointmentReminderWorker._prefsKey) ?? '[]';
    final list = (jsonDecode(raw) as List<dynamic>).cast<dynamic>();

    final nowTz = tz.TZDateTime.now(tz.local);
    final updated = <dynamic>[];

    for (final e in list) {
      if (e is! Map) continue;
      final id = (e['id'] ?? '').toString();
      final atMs = (e['atMs'] is num) ? (e['atMs'] as num).toInt() : null;
      final doctor = (e['doctor'] ?? '').toString();
      if (id.isEmpty || atMs == null) continue;

      final apptLocal = DateTime.fromMillisecondsSinceEpoch(atMs);
      final apptTz = tz.TZDateTime.from(apptLocal, tz.local);
      final until = apptTz.difference(nowTz);

      var n3 = e['notified3h'] == true;
      var n1 = e['notified1h'] == true;

      // If appointment is in the past, drop it.
      if (until.inSeconds <= 0) {
        continue;
      }

      // Trigger once when entering each window (best effort).
      if (!n3 && until <= const Duration(hours: 3)) {
        await _showImmediateReminder(
          id: (id.hashCode & 0x7fffffff),
          title: 'نۆرەکەت بیر نەچێت',
          body: '٣ کاتژمێری تر نۆرەت هەیە لای دکتۆر $doctor.',
        );
        n3 = true;
      }

      if (!n1 && until <= const Duration(hours: 1)) {
        await _showImmediateReminder(
          id: ((id.hashCode + 1) & 0x7fffffff),
          title: 'کاتى نۆرەکەت نزیک بووەوە',
          body: 'تەنها ١ کاتژمێر ماوە بۆ نۆرەکەت لای دکتۆر $doctor.',
        );
        n1 = true;
      }

      updated.add({
        'id': id,
        'atMs': atMs,
        'doctor': doctor,
        'notified3h': n3,
        'notified1h': n1,
      });
    }

    await prefs.setString(
      AppointmentReminderWorker._prefsKey,
      jsonEncode(updated),
    );
    return true;
  });
}

Future<void> _showImmediateReminder({
  required int id,
  required String title,
  required String body,
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  // Background isolate may not share plugin initialization with UI isolate.
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await plugin.initialize(
    settings: const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ),
  );
  const channel = AndroidNotificationChannel(
    'high_importance_channel',
    'HR Nora — Appointment reminders',
    description: '3h and 1h appointment reminders',
    importance: Importance.max,
    playSound: true,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  const android = AndroidNotificationDetails(
    'high_importance_channel',
    'HR Nora — Appointment reminders',
    channelDescription: '3h and 1h appointment reminders',
    importance: Importance.max,
    priority: Priority.high,
  );
  const ios = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(android: android, iOS: ios),
  );
}

