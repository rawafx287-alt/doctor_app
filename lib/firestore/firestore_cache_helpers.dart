import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper: cache-first read to reduce Firestore "Read" cost and improve speed.
///
/// کورتە:
/// - سەرەتا هەوڵ دەدەین لە `Source.cache` بخوێنین (خێراتر و بەکەمترین خەرج).
/// - ئەگەر لە کاشدا نەبوو/هەڵە هات، دواتر لە `Source.server` دەخوێنین.
Future<DocumentSnapshot<Map<String, dynamic>>> getDocCacheFirst(
  DocumentReference<Map<String, dynamic>> ref,
) async {
  try {
    final cached = await ref.get(const GetOptions(source: Source.cache));
    if (cached.exists) return cached;
  } catch (_) {
    // کاش ڕەنگە بەردەست نەبێت (سەرەتا/دەرهێنان/تێکچوون). دواتر سێرڤەر.
  }
  return ref.get(const GetOptions(source: Source.server));
}

/// Cache-first query: tries cache, then server.
///
/// تێبینی: ئەمە بەکارهێنە بۆ ئەو لیستەکانەی کە ریل‌تایم پێویست ناکەن.
Future<QuerySnapshot<Map<String, dynamic>>> getQueryCacheFirst(
  Query<Map<String, dynamic>> query,
) async {
  try {
    final cached = await query.get(const GetOptions(source: Source.cache));
    if (cached.docs.isNotEmpty) return cached;
  } catch (_) {}
  return query.get(const GetOptions(source: Source.server));
}

