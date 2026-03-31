/// Shared phone handling for sign-up / login so Firestore `phone` queries match.
String normalizePhoneDigits(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final buf = StringBuffer();
  for (final unit in trimmed.runes) {
    final ch = String.fromCharCode(unit);
    // Arabic-Indic → Latin (٠١٢٣٤٥٦٧٨٩)
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const latin = '0123456789';
    final idx = arabic.indexOf(ch);
    if (idx >= 0) {
      buf.write(latin[idx]);
      continue;
    }
    // Eastern Arabic-Indic (Persian) ۰۱۲۳۴۵۶۷۸۹
    const eastern = '۰۱۲۳۴۵۶۷۸۹';
    final j = eastern.indexOf(ch);
    if (j >= 0) {
      buf.write(latin[j]);
      continue;
    }
    if (ch.contains(RegExp(r'[0-9]'))) buf.write(ch);
  }
  return buf.toString();
}
