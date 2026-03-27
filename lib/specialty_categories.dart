import 'package:flutter/material.dart';

/// Filter label for “all doctors” in patient home — not stored as `specialty` in Firestore.
const String kPatientSpecialtyAllLabel = 'هەمووی';

/// Kurdish specialty labels — must match Firestore `users.specialty` exactly.
const List<String> kDoctorSpecialtyOptions = [
  'ددان',
  'دڵ',
  'فەقەڕات',
  'منداڵان',
  'قورگ و لوت و گوێ',
  'چاو',
  'پێست و جوانکاری',
  'دەمار و مێشک',
  'ژنان و منداڵبوون',
  'هەناوی',
];

/// Horizontal filter chips: “all” plus every doctor specialty.
List<String> get patientSpecialtyFilterCategories => [
      kPatientSpecialtyAllLabel,
      ...kDoctorSpecialtyOptions,
    ];

/// Icon for patient filter row / display; [kPatientSpecialtyAllLabel] shows “all” icon.
IconData iconForSpecialtyCategory(String category) {
  if (category == kPatientSpecialtyAllLabel) {
    return Icons.apps_rounded;
  }
  switch (category) {
    case 'ددان':
      return Icons.medical_services_rounded;
    case 'دڵ':
      return Icons.favorite_rounded;
    case 'فەقەڕات':
      return Icons.accessibility_new_rounded;
    case 'منداڵان':
      return Icons.child_care_rounded;
    case 'قورگ و لوت و گوێ':
      return Icons.hearing_rounded;
    case 'چاو':
      return Icons.visibility_rounded;
    case 'پێست و جوانکاری':
      return Icons.spa_rounded;
    case 'دەمار و مێشک':
      return Icons.psychology_rounded;
    case 'ژنان و منداڵبوون':
      return Icons.pregnant_woman_rounded;
    case 'هەناوی':
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
    final textStyle = TextStyle(
      color: const Color(0xFFD9E2EC),
      fontFamily: useKurdishFont ? 'KurdishFont' : null,
      fontSize: dense ? 15 : 16,
      fontWeight: FontWeight.w600,
    );
    return DropdownButtonFormField<String>(
      value: value != null && kDoctorSpecialtyOptions.contains(value) ? value : null,
      isExpanded: true,
      alignment: AlignmentDirectional.centerEnd,
      icon: Icon(Icons.arrow_drop_down_rounded, color: accentColor),
      dropdownColor: const Color(0xFF1D1E33),
      style: textStyle,
      decoration: InputDecoration(
        labelText: 'لیستی هەڵبژاردن',
        labelStyle: TextStyle(
          color: const Color(0xFF829AB1),
          fontFamily: useKurdishFont ? 'KurdishFont' : null,
          fontSize: dense ? 13 : 14,
        ),
        hintText: 'پسپۆڕی هەڵبژێرە',
        hintStyle: TextStyle(
          color: const Color(0xFF829AB1).withOpacity(0.85),
          fontFamily: useKurdishFont ? 'KurdishFont' : null,
        ),
        prefixIcon: Icon(Icons.local_hospital_rounded, color: accentColor),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dense ? 14 : 15),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: dense ? 14 : 16,
        ),
      ),
      items: kDoctorSpecialtyOptions
          .map(
            (e) => DropdownMenuItem<String>(
              value: e,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  e,
                  textAlign: TextAlign.right,
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
