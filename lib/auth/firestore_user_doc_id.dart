import 'package:firebase_auth/firebase_auth.dart';

import 'phone_auth_config.dart';

/// Firestore `users` document id: phone-keyed accounts use [phoneAuthEmail] → doc id = phone.
/// If the synthetic email has an empty local part, falls back to [User.uid].
String firestoreUserDocId(User? user) {
  if (user == null) return '';
  final email = user.email ?? '';
  if (email.endsWith('@$kPhoneAuthEmailDomain')) {
    final local = email.split('@').first.trim();
    if (local.isNotEmpty) return local;
  }
  return user.uid;
}
