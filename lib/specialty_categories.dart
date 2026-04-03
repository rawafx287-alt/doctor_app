import 'package:flutter/material.dart';

import 'locale/app_localizations.dart';
import 'theme/patient_premium_theme.dart';

/// One doctor specialty: [translationKey] for [S.of(context).translate];
/// [firestoreValue] must match `users.specialty` in Firestore (Sorani label).
class DoctorSpecialtyDef {
  const DoctorSpecialtyDef({
    required this.translationKey,
    required this.firestoreValue,
  });

  final String translationKey;
  final String firestoreValue;
}

/// Patient home “all specialties” chip — not stored in Firestore.
const String kPatientSpecialtyAllKey = 'specialties_all';

/// Ordered list — [firestoreValue] must stay in sync with existing doctor data.
const List<DoctorSpecialtyDef> kDoctorSpecialtyDefinitions = [
  DoctorSpecialtyDef(translationKey: 'dentist_specialty', firestoreValue: 'ددان'),
  DoctorSpecialtyDef(translationKey: 'cardiology_specialty', firestoreValue: 'دڵ'),
  DoctorSpecialtyDef(translationKey: 'orthopedics_specialty', firestoreValue: 'فەقەڕات'),
  DoctorSpecialtyDef(translationKey: 'pediatrics_specialty', firestoreValue: 'منداڵان'),
  DoctorSpecialtyDef(
    translationKey: 'ent_specialty',
    firestoreValue: 'قورگ و لوت و گوێ',
  ),
  DoctorSpecialtyDef(translationKey: 'ophthalmology_specialty', firestoreValue: 'چاو'),
  DoctorSpecialtyDef(
    translationKey: 'dermatology_specialty',
    firestoreValue: 'پێست و جوانکاری',
  ),
  DoctorSpecialtyDef(
    translationKey: 'neurology_specialty',
    firestoreValue: 'دەمار و مێشک',
  ),
  DoctorSpecialtyDef(
    translationKey: 'obgyn_specialty',
    firestoreValue: 'ژنان و منداڵبوون',
  ),
  DoctorSpecialtyDef(
    translationKey: 'gastroenterology_specialty',
    firestoreValue: 'هەناوی',
  ),
];

/// Kurdish values saved in Firestore (same order as [kDoctorSpecialtyDefinitions]).
List<String> get kDoctorSpecialtyOptions =>
    kDoctorSpecialtyDefinitions.map((d) => d.firestoreValue).toList();

/// Firestore value → translation key (for migrating UI only).
String? specialtyFirestoreToKey(String firestoreValue) {
  final t = firestoreValue.trim();
  for (final d in kDoctorSpecialtyDefinitions) {
    if (d.firestoreValue == t) return d.translationKey;
  }
  return null;
}

/// Localized label for a stored `users.specialty` value; unknown values returned as-is.
String translatedSpecialtyForFirestore(BuildContext context, String firestoreValue) {
  final key = specialtyFirestoreToKey(firestoreValue);
  if (key == null) return firestoreValue;
  return S.of(context).translate(key);
}

/// Translation keys for patient home chips: “all” + each specialty.
List<String> get patientSpecialtyFilterCategoryKeys => [
      kPatientSpecialtyAllKey,
      ...kDoctorSpecialtyDefinitions.map((d) => d.translationKey),
    ];

/// Icons for filter chips; [kPatientSpecialtyAllKey] or each [translationKey].
IconData iconForSpecialtyCategoryKey(String categoryKey) {
  if (categoryKey == kPatientSpecialtyAllKey) {
    return Icons.apps_rounded;
  }
  switch (categoryKey) {
    case 'dentist_specialty':
      return Icons.medical_services_rounded;
    case 'cardiology_specialty':
      return Icons.favorite_rounded;
    case 'orthopedics_specialty':
      return Icons.accessibility_new_rounded;
    case 'pediatrics_specialty':
      return Icons.child_care_rounded;
    case 'ent_specialty':
      return Icons.hearing_rounded;
    case 'ophthalmology_specialty':
      return Icons.visibility_rounded;
    case 'dermatology_specialty':
      return Icons.spa_rounded;
    case 'neurology_specialty':
      return Icons.psychology_rounded;
    case 'obgyn_specialty':
      return Icons.pregnant_woman_rounded;
    case 'gastroenterology_specialty':
      return Icons.restaurant_rounded;
    default:
      return Icons.medical_services_rounded;
  }
}

/// Shared dropdown for doctor specialty (signup / profile / admin). RTL-friendly.
class KurdishDoctorSpecialtyDropdown extends StatelessWidget {
  const KurdishDoctorSpecialtyDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.accentColor = const Color(0xFF42A5F5),
    this.fillColor = const Color(0xFF1D1E33),
    this.useKurdishFont = true,
    this.dense = false,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final Color accentColor;
  final Color fillColor;
  final bool useKurdishFont;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textStyle = TextStyle(
      color: const Color(0xFFD9E2EC),
      fontFamily: useKurdishFont ? kPatientPrimaryFont : null,
      fontSize: dense ? 15 : 16,
      fontWeight: FontWeight.bold,
    );
    return DropdownButtonFormField<String>(
      initialValue: value != null && kDoctorSpecialtyOptions.contains(value) ? value : null,
      isExpanded: true,
      alignment: AlignmentDirectional.centerEnd,
      icon: Icon(Icons.arrow_drop_down_rounded, color: accentColor),
      dropdownColor: const Color(0xFF1D1E33),
      style: textStyle,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: false,
        labelText: s.translate('dropdown_specialty_label'),
        labelStyle: TextStyle(
          color: const Color(0xFF829AB1),
          fontFamily: useKurdishFont ? kPatientPrimaryFont : null,
          fontSize: dense ? 13 : 14,
          height: 1.25,
        ),
        floatingLabelStyle: TextStyle(
          color: const Color(0xFF829AB1),
          fontFamily: useKurdishFont ? kPatientPrimaryFont : null,
          fontSize: dense ? 11.5 : 12,
          height: 1.15,
          fontWeight: FontWeight.bold,
        ),
        hintText: s.translate('dropdown_specialty_hint'),
        hintStyle: TextStyle(
          color: const Color(0xFF829AB1).withValues(alpha: 0.85),
          fontFamily: useKurdishFont ? kPatientPrimaryFont : null,
        ),
        prefixIcon: Icon(Icons.local_hospital_rounded, color: accentColor),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 14 : 15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 14 : 15),
          borderSide: const BorderSide(color: Color(0x40FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 14 : 15),
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.85), width: 1.2),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          14,
          dense ? 18 : 20,
          14,
          dense ? 14 : 16,
        ),
      ),
      items: kDoctorSpecialtyDefinitions
          .map(
            (d) => DropdownMenuItem<String>(
              value: d.firestoreValue,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  s.translate(d.translationKey),
                  textAlign: TextAlign.start,
                  style: textStyle,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
