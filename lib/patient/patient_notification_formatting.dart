import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';

var _patientTimeagoLocalesReady = false;

/// Registers [timeago] locales used by the notification list.
void ensurePatientNotificationTimeagoLocales() {
  if (_patientTimeagoLocalesReady) return;
  _patientTimeagoLocalesReady = true;
  timeago.setLocaleMessages('ku', timeago.KuMessages());
  timeago.setLocaleMessages('ar', timeago.ArMessages());
}

String formatPatientNotificationTimestamp(
  BuildContext context,
  DateTime? dt,
) {
  if (dt == null) return '';
  final s = S.of(context);
  final lang = AppLocaleScope.of(context).effectiveLanguage.storageCode;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final timePart = DateFormat.jm().format(dt);

  if (day == today) {
    return '${s.translate('patient_notif_time_today')}, $timePart';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == yesterday) {
    return '${s.translate('patient_notif_time_yesterday')}, $timePart';
  }

  final locale = switch (lang) {
    'ckb' => 'ku',
    'ar' => 'ar',
    _ => 'en',
  };
  if (now.difference(dt).inDays < 7) {
    return timeago.format(dt, locale: locale);
  }
  return DateFormat.yMMMd().add_jm().format(dt);
}
