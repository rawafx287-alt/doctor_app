import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Dedupes logs across [StreamBuilder] rebuilds.
final Set<String> _firestoreIndexLogSignatures = <String>{};

/// Prints any Firebase Console link embedded in a Firestore error (for composite indexes).
///
/// Look for lines starting with `=== Firestore index URL` in **Run** / **Debug console**.
void logFirestoreIndexHelpOnce(
  Object? error, {
  required String tag,
  String? expectedCompositeIndexHint,
}) {
  if (error == null) return;
  final signature = '$tag::${error.toString()}';
  if (_firestoreIndexLogSignatures.contains(signature)) return;
  _firestoreIndexLogSignatures.add(signature);
  if (_firestoreIndexLogSignatures.length > 80) {
    _firestoreIndexLogSignatures.clear();
  }

  if (expectedCompositeIndexHint != null) {
    debugPrint('=== Expected index for this query ($tag) ===');
    debugPrint(expectedCompositeIndexHint);
  }

  final full = error.toString();
  // Firestore embeds a one-click index link (no spaces in URL).
  final urlRe = RegExp(
    r'https://console\.firebase\.google\.com\S+',
    caseSensitive: false,
  );
  final urls = urlRe.allMatches(full).map((m) => m.group(0)!).toList();

  if (urls.isNotEmpty) {
    for (final raw in urls) {
      final url = raw.replaceAll(RegExp(r'[\)\.,;]+$'), '');
      debugPrint('=== Firestore index URL ($tag) ===');
      debugPrint(url);
      debugPrint('=== end index URL (tap/copy in IDE console) ===');
    }
  } else {
    debugPrint('=== Firestore error ($tag) — no URL in message ===');
    if (error is FirebaseException) {
      debugPrint('code=${error.code} plugin=${error.plugin}');
      debugPrint('message=${error.message}');
    }
    debugPrint('toString=$full');
  }
}
