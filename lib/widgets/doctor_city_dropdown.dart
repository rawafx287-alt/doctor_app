import 'package:flutter/material.dart';

import '../locale/app_localizations.dart';
import '../models/doctor_profile_fields.dart';
import '../theme/patient_premium_theme.dart';

/// City selector for doctor signup and profile (`users.city` in Firestore).
class DoctorCityDropdown extends StatelessWidget {
  const DoctorCityDropdown({
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
    final lineHeight = dense ? 1.42 : 1.32;
    final textStyle = TextStyle(
      color: const Color(0xFFD9E2EC),
      fontFamily: useKurdishFont ? kPatientPrimaryFont : null,
      fontSize: dense ? 14.5 : 16,
      height: lineHeight,
      fontWeight: FontWeight.bold,
    );
    final items = doctorCityDropdownItems(value);
    final effectiveValue =
        value != null && items.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      isExpanded: true,
      alignment: AlignmentDirectional.centerEnd,
      icon: Icon(Icons.arrow_drop_down_rounded, color: accentColor),
      dropdownColor: const Color(0xFF1D1E33),
      style: textStyle,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: false,
        labelText: s.translate('dropdown_city_label'),
        labelStyle: TextStyle(
          color: const Color(0xFF829AB1),
          fontFamily: useKurdishFont ? kPatientPrimaryFont : null,
          fontSize: dense ? 13 : 14,
          height: dense ? 1.38 : 1.28,
        ),
        floatingLabelStyle: TextStyle(
          color: const Color(0xFF829AB1),
          fontFamily: useKurdishFont ? kPatientPrimaryFont : null,
          fontSize: dense ? 11.5 : 12,
          height: dense ? 1.35 : 1.22,
          fontWeight: FontWeight.bold,
        ),
        hintText: s.translate('dropdown_city_hint'),
        hintStyle: TextStyle(
          color: const Color(0xFF829AB1).withValues(alpha: 0.85),
          fontFamily: useKurdishFont ? kPatientPrimaryFont : null,
          fontSize: dense ? 14 : 15,
          height: dense ? 1.42 : 1.32,
        ),
        prefixIcon: Icon(Icons.location_city_rounded, color: accentColor),
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
          borderSide: BorderSide(
            color: accentColor.withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          14,
          dense ? 20 : 20,
          14,
          dense ? 18 : 16,
        ),
      ),
      items: items
          .map(
            (city) => DropdownMenuItem<String>(
              value: city,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  city,
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
