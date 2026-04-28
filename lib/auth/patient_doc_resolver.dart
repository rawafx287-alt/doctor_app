import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firestore/firestore_cache_helpers.dart';
import 'firestore_user_doc_id.dart';
import 'phone_auth_config.dart';
import 'phone_normalization.dart';

Future<String?> resolvePatientUserDocId(User? user) async {
  if (user == null) return null;
  final users = FirebaseFirestore.instance.collection('users');

  final phoneCandidates = <String>{};
  final rawAuthPhone = (user.phoneNumber ?? '').trim();
  final normalizedAuthPhone = normalizePhoneDigits(rawAuthPhone);
  if (normalizedAuthPhone.isNotEmpty) {
    phoneCandidates.add(normalizedAuthPhone);
  }
  final email = (user.email ?? '').trim();
  if (email.endsWith('@$kPhoneAuthEmailDomain')) {
    final p = normalizePhoneDigits(email.split('@').first);
    if (p.isNotEmpty) phoneCandidates.add(p);
  }

  final idCandidates = <String>{
    ...phoneCandidates,
    firestoreUserDocId(user).trim(),
    user.uid.trim(),
  }..removeWhere((e) => e.isEmpty);

  for (final id in idCandidates) {
    // کەمکردنەوەی خوێندنەوەکان: سەرەتا لە کاش بخوێنەوە، ئەگەر نەبوو لە سێرڤەر.
    final doc = await getDocCacheFirst(users.doc(id));
    if (doc.exists) return id;
  }

  for (final phone in phoneCandidates) {
    // لەم شوێنەدا ریل‌تایم پێویست نییە؛ کاش→سێرڤەر بۆ کەمکردنەوەی "Read".
    final byStr = await getQueryCacheFirst(
      users.where('phone', isEqualTo: phone).limit(1),
    );
    if (byStr.docs.isNotEmpty) return byStr.docs.first.id;

    final asInt = int.tryParse(phone);
    if (asInt != null) {
      final byInt = await getQueryCacheFirst(
        users.where('phone', isEqualTo: asInt).limit(1),
      );
      if (byInt.docs.isNotEmpty) return byInt.docs.first.id;
    }
  }

  return null;
}
