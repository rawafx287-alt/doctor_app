import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local (on-device) reminders for upcoming appointments.
///
/// Schedules 2 notifications per booking:
/// - 3 hours before
/// - 1 hour before
class AppointmentLocalNotifications {
  AppointmentLocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'HR Nora — Appointment reminders';

  /// Optional hook so UI can show a friendly message.
  static void Function(String message)? onUserWarning;

  static Future<void> init() async {
    if (kIsWeb || _inited) return;

    await ensureTimeZoneInitialized();

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
      _channelId,
      _channelName,
      description: '3h and 1h appointment reminders',
      importance: Importance.max,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _inited = true;
  }

  /// Must be called before any [zonedSchedule] calls.
  /// Safe to call multiple times.
  static Future<void> ensureTimeZoneInitialized() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('DEBUG: Local timezone set to $name');
    } catch (e) {
      debugPrint('DEBUG: Timezone init fallback: $e');
      // Fall back to default TZ (still schedules; may be slightly off on some devices).
    }
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    if (!_inited) await init();

    // Android 13+ requires runtime notifications permission.
    final st = await Permission.notification.status;
    if (!st.isGranted) {
      await Permission.notification.request();
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> scheduleTwoAlerts({
    required String appointmentId,
    required DateTime appointmentTimeLocal,
    required String doctorName,
  }) async {
    if (kIsWeb) return;
    if (!_inited) await init();

    // User-requested debug line:
    // ignore: avoid_print
    print('DEBUG: Notification requested for ${DateTime.now()}');

    // Ensure permissions are granted (Android 13+).
    await requestPermissions();

    // CRITICAL: always compute using the phone's local timezone clock.
    final nowTz = tz.TZDateTime.now(tz.local);
    final apptTz = tz.TZDateTime.from(appointmentTimeLocal, tz.local);
    final untilAppt = apptTz.difference(nowTz);
    final t3Tz = apptTz.subtract(const Duration(hours: 3));
    final t1Tz = apptTz.subtract(const Duration(hours: 1));

    debugPrint(
      'DEBUG: scheduleTwoAlerts appt=$appointmentId nowTz=$nowTz apptTz=$apptTz t-3h=$t3Tz t-1h=$t1Tz',
    );

    final ids = _idsForAppointment(appointmentId);

    // Clear any previous schedules for the same appointment.
    await _plugin.cancel(id: ids.threeHourId);
    await _plugin.cancel(id: ids.oneHourId);
    // If appointment is less than 1 hour away → send instant reminder instead.
    if (untilAppt.inSeconds > 0 && untilAppt < const Duration(hours: 1)) {
      await _showInstant(
        id: ids.oneHourId,
        title: 'نۆرەکەت نزیکە!',
        body: 'تەنها ${untilAppt.inMinutes} خولەک ماوە بۆ نۆرەکەت لای دکتۆر $doctorName.',
      );
      return;
    }

    // If appointment is less than 3 hours away → schedule only the 1-hour reminder.
    if (untilAppt.inSeconds > 0 && untilAppt < const Duration(hours: 3)) {
      if (t1Tz.isAfter(nowTz)) {
        await _scheduleAt(
          id: ids.oneHourId,
          whenTz: t1Tz,
          title: 'کاتى نۆرەکەت نزیک بووەوە',
          body: 'تەنها ١ کاتژمێر ماوە بۆ نۆرەکەت لای دکتۆر $doctorName.',
        );
      }
      return;
    }

    if (t3Tz.isAfter(nowTz)) {
      await _scheduleAt(
        id: ids.threeHourId,
        whenTz: t3Tz,
        title: 'نۆرەکەت بیر نەچێت',
        body: '٣ کاتژمێری تر نۆرەت هەیە لای دکتۆر $doctorName.',
      );
    }
    if (t1Tz.isAfter(nowTz)) {
      await _scheduleAt(
        id: ids.oneHourId,
        whenTz: t1Tz,
        title: 'کاتى نۆرەکەت نزیک بووەوە',
        body: 'تەنها ١ کاتژمێر ماوە بۆ نۆرەکەت لای دکتۆر $doctorName.',
      );
    }
  }

  static Future<void> cancelAppointmentAlerts(String appointmentId) async {
    if (kIsWeb) return;
    if (!_inited) await init();
    final ids = _idsForAppointment(appointmentId);
    await _plugin.cancel(id: ids.threeHourId);
    await _plugin.cancel(id: ids.oneHourId);
  }

  /// Clears every local notification scheduled/shown by this plugin (use only when
  /// the server payload has no [appointmentId] but clearly indicates cancellation).
  static Future<void> cancelAllReminders() async {
    if (kIsWeb) return;
    if (!_inited) await init();
    await _plugin.cancelAll();
  }

  /// Debug helper: schedules a notification after [delay].
  static Future<void> scheduleTestAfter({
    Duration delay = const Duration(seconds: 5),
  }) async {
    if (kIsWeb) return;
    if (!_inited) await init();
    final whenTz = tz.TZDateTime.now(tz.local).add(delay);
    const id = 987654321;
    await _plugin.cancel(id: id);
    await _scheduleAt(
      id: id,
      whenTz: whenTz,
      title: 'Test',
      body: 'This is a test notification.',
    );
  }

  /// Debug helper: shows a notification immediately using `.show()`.
  static Future<void> showTestNow() async {
    if (kIsWeb) return;
    if (!_inited) await init();
    const id = 987654322;
    await _plugin.cancel(id: id);

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '3h and 1h appointment reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: id,
      title: 'Test (now)',
      body: 'This is an immediate test notification.',
      notificationDetails: const NotificationDetails(android: android, iOS: ios),
    );
  }

  static Future<void> _scheduleAt({
    required int id,
    required tz.TZDateTime whenTz,
    required String title,
    required String body,
  }) async {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '3h and 1h appointment reminders',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: const DefaultStyleInformation(true, true),
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final mode = AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final scheduled = whenTz;
      // User-requested debug line:
      // ignore: avoid_print
      print('DEBUG: Scheduling notification for: ${scheduled.toString()}');
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: NotificationDetails(android: android, iOS: ios),
        androidScheduleMode: mode,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: whenTz,
          notificationDetails: NotificationDetails(android: android, iOS: ios),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        // No user warning here: we intentionally prefer non-exact scheduling.
        return;
      }
      rethrow;
    }
  }

  static Future<void> _showInstant({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    if (!_inited) await init();
    await _plugin.cancel(id: id);

    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '3h and 1h appointment reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
    );
  }

  // NOTE: We intentionally prefer non-exact scheduling to avoid the Android 12+
  // exact alarm permission requirement. Keep this method out unless we add an
  // explicit user setting for "high precision reminders".

  static _ApptNotifIds _idsForAppointment(String appointmentId) {
    final base = _fnv1a32(appointmentId) & 0x7fffffff;
    return _ApptNotifIds(base, (base + 1) & 0x7fffffff);
  }

  /// Stable 32-bit FNV-1a hash (platform-independent).
  static int _fnv1a32(String s) {
    const int prime = 16777619;
    var hash = 2166136261;
    for (final c in s.codeUnits) {
      hash ^= c;
      hash = (hash * prime) & 0xffffffff;
    }
    return hash;
  }
}

class _ApptNotifIds {
  const _ApptNotifIds(this.threeHourId, this.oneHourId);
  final int threeHourId;
  final int oneHourId;
}

