import 'package:firebase_auth/firebase_auth.dart';

import '../auth/firestore_user_doc_id.dart';
import '../auth/patient_session_cache.dart';
import '../auth/phone_auth_config.dart';
import '../auth/phone_normalization.dart';

/// Keys that may appear in [AppointmentFields.patientId] / [userId] for this login.
Set<String> patientRecipientKeysForUser(User user) {
  final phoneIds = <String>{};
  final authPhone = normalizePhoneDigits((user.phoneNumber ?? '').trim());
  if (authPhone.isNotEmpty) phoneIds.add(authPhone);
  final email = (user.email ?? '').trim();
  if (email.endsWith('@$kPhoneAuthEmailDomain')) {
    final p = normalizePhoneDigits(email.split('@').first);
    if (p.isNotEmpty) phoneIds.add(p);
  }
  final ids = <String>{
    user.uid.trim(),
    firestoreUserDocId(user).trim(),
    ...phoneIds,
  };
  ids.removeWhere((e) => e.isEmpty);
  return ids;
}

/// Same aliases as [MyAppointmentsScreen] queries — use for root [notifications].
Future<Set<String>> resolvePatientRecipientKeys() async {
  final user = FirebaseAuth.instance.currentUser;
  final ids = <String>{};
  final cached = (await PatientSessionCache.readPatientRefId() ?? '').trim();
  if (cached.isNotEmpty) ids.add(cached);
  if (user != null) {
    ids.addAll(patientRecipientKeysForUser(user));
  }
  ids.removeWhere((e) => e.isEmpty);
  return ids;
}
