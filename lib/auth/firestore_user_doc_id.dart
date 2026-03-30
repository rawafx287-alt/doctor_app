import 'package:firebase_auth/firebase_auth.dart';

import 'phone_auth_config.dart';

/// Firestore `users` document id: phone-keyed accounts use [phoneAuthEmail] → doc id = phone.
String firestoreUserDocId(User? user) {
  if (user == null) return '';
  final email = user.email ?? '';
  if (email.endsWith('@$kPhoneAuthEmailDomain')) {
    return email.split('@').first;
  }
  return user.uid;
}
