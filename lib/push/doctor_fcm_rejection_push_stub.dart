/// Web / non-`dart:io` — FCM via service account is not supported.
Future<void> sendDoctorRejectionPushWithServiceAccountJson({
  required String serviceAccountJson,
  required Set<String> recipientKeys,
  required String title,
  required String body,
  required String appointmentId,
  required String type,
}) async {}
