import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'appointment_local_notifications.dart';
import 'appointment_reminder_worker.dart';

/// Data [type] values that mean the patient's appointment is gone — drop local reminders.
const Set<String> kRemoteCancellationTypes = {
  'appointment_cancelled',
  'clinic_closed',
  'doctor_day_closed',
};

bool _isRemoteCancellationType(String raw) {
  final t = raw.trim().toLowerCase();
  return kRemoteCancellationTypes.contains(t);
}

/// Cancels local 3h/1h reminders (and WorkManager fallback state) when a remote
/// push indicates the appointment was cancelled by staff or the clinic.
Future<void> syncLocalRemindersForRemoteCancellation(RemoteMessage message) async {
  if (kIsWeb) return;
  final data = message.data;
  final type = (data['type'] ?? '').toString();
  final appointmentId = (data['appointmentId'] ?? '').toString().trim();

  if (!_isRemoteCancellationType(type)) return;

  await AppointmentLocalNotifications.ensureTimeZoneInitialized();
  await AppointmentLocalNotifications.init();

  if (appointmentId.isNotEmpty) {
    await AppointmentLocalNotifications.cancelAppointmentAlerts(appointmentId);
    await AppointmentReminderWorker.removeBooking(appointmentId);
  } else {
    await AppointmentLocalNotifications.cancelAllReminders();
    await AppointmentReminderWorker.clearAll();
  }
}
