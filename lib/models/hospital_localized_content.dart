import '../locale/app_locale.dart';

/// Localized display name for a hospital document from `hospitals` collection.
String localizedHospitalName(Map<String, dynamic> data, HrNoraLanguage language) {
  String pick(String key) {
    final v = data[key];
    if (v == null) return '';
    return v.toString().trim();
  }

  final ku = pick('name_ku').isNotEmpty ? pick('name_ku') : pick('name');
  final ar = pick('name_ar');
  final en = pick('name_en');

  String forLang(HrNoraLanguage l) => switch (l) {
        HrNoraLanguage.ckb => ku,
        HrNoraLanguage.ar => ar,
        HrNoraLanguage.en => en,
      };

  final preferred = forLang(language);
  if (preferred.isNotEmpty) return preferred;
  if (ku.isNotEmpty) return ku;
  return pick('name');
}

/// Optional subtitle / about text for hospital detail.
String localizedHospitalDescription(Map<String, dynamic> data, HrNoraLanguage language) {
  String pick(String key) {
    final v = data[key];
    if (v == null) return '';
    return v.toString().trim();
  }

  final ku = pick('description_ku').isNotEmpty ? pick('description_ku') : pick('description');
  final ar = pick('description_ar');
  final en = pick('description_en');

  String forLang(HrNoraLanguage l) => switch (l) {
        HrNoraLanguage.ckb => ku,
        HrNoraLanguage.ar => ar,
        HrNoraLanguage.en => en,
      };

  final preferred = forLang(language);
  if (preferred.isNotEmpty) return preferred;
  if (ku.isNotEmpty) return ku;
  return pick('description');
}
