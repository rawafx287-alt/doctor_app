import '../locale/app_locale.dart';

/// Reads `baseKey_ku`, `baseKey_ar`, `baseKey_en` from Firestore doctor/user maps.
///
/// Order: current [language] → Kurdish (`_ku`) → [legacyKeys] in order.
/// Empty strings are skipped.
String localizedDoctorField(
  Map<String, dynamic> data,
  HrNoraLanguage language, {
  required String baseKey,
  List<String> legacyKeys = const [],
}) {
  String pick(String key) {
    final v = data[key];
    if (v == null) return '';
    final s = v.toString().trim();
    return s;
  }

  final ku = pick('${baseKey}_ku');
  final ar = pick('${baseKey}_ar');
  final en = pick('${baseKey}_en');

  String forLang(HrNoraLanguage l) => switch (l) {
        HrNoraLanguage.ckb => ku,
        HrNoraLanguage.ar => ar,
        HrNoraLanguage.en => en,
      };

  final preferred = forLang(language);
  if (preferred.isNotEmpty) return preferred;
  if (ku.isNotEmpty) return ku;
  for (final k in legacyKeys) {
    final p = pick(k);
    if (p.isNotEmpty) return p;
  }
  return '';
}

/// Display name for the current app [language] (patient or doctor UI).
String localizedDoctorFullName(Map<String, dynamic> data, HrNoraLanguage language) {
  return localizedDoctorField(
    data,
    language,
    baseKey: 'fullName',
    legacyKeys: const ['fullName'],
  );
}

/// Hospital / clinic line for patient doctor cards and details.
/// Prefers explicit [`hospitalName`] (doctor profile «ناوی نەخۆشخانە»), then localized `hospital_name_*`.
String localizedDoctorHospitalName(
  Map<String, dynamic> data,
  HrNoraLanguage language,
) {
  final direct = (data['hospitalName'] ?? '').toString().trim();
  if (direct.isNotEmpty) return direct;
  return localizedDoctorField(
    data,
    language,
    baseKey: 'hospital_name',
    legacyKeys: const ['clinicName'],
  );
}

/// Prefer Kurdish stored name for appointments / legacy fields.
String canonicalDoctorNameForStorage(Map<String, dynamic> data) {
  final ku = (data['fullName_ku'] ?? '').toString().trim();
  if (ku.isNotEmpty) return ku;
  return (data['fullName'] ?? '').toString().trim();
}

/// Lowercase blob of all name fields for search.
String doctorNameSearchBlob(Map<String, dynamic> data) {
  const keys = ['fullName', 'fullName_ku', 'fullName_ar', 'fullName_en'];
  return keys
      .map((k) => (data[k] ?? '').toString().toLowerCase().trim())
      .where((s) => s.isNotEmpty)
      .join(' ');
}
