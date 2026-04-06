import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import 'patient_booking_form_result.dart';

const Color _kDeepPanel = Color(0xFF0A1628);
const List<String> _kBloodGroups = [
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
];

const List<String> _kCityAreas = [
  'هەولێر',
  'سلێمانی',
  'دهۆک',
  'کەرکووک',
  'بەغداد',
  'مووسڵ',
  'ڕانیە',
  'هەڵەبجە',
  'ئاکرێ',
  'زاخۆ',
  'دیکە',
];

/// Modern glass booking form opened from [BookingSummaryScreen] («دووپاتکردنەوەی نۆرە»).
class BookingDetailsPage extends StatefulWidget {
  const BookingDetailsPage({
    super.key,
    required this.doctorDisplayName,
    required this.dateLocal,
    required this.slotTimeLabelEn,
  });

  final String doctorDisplayName;
  final DateTime dateLocal;
  /// First free slot label using English numerals (e.g. 9:00 AM).
  final String slotTimeLabelEn;

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _blood;
  String? _city;
  bool _male = true;

  static final _digitsOnly = FilteringTextInputFormatter.digitsOnly;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  TextStyle get _labelStyle => TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: kStaffLuxGold.withValues(alpha: 0.92),
      );

  TextStyle get _inputStyle => TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: Colors.white.withValues(alpha: 0.94),
      );

  Widget _glassShell({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: _kDeepPanel.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kStaffLuxGold.withValues(alpha: 0.5),
              width: 1.05,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: child,
        ),
      ),
    );
  }

  Widget _labeledField({
    required String label,
    required Widget field,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        _glassShell(child: field),
      ],
    );
  }

  void _submit() {
    final s = S.of(context);
    if (!_formKey.currentState!.validate()) return;
    if ((_blood ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('booking_form_blood_required'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
      return;
    }
    final age = int.tryParse(_ageCtrl.text.trim());
    if (age == null || age < 1 || age > 130) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('booking_form_age_required'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
      return;
    }

    final phone = staffDigitsToEnglishAscii(_phoneCtrl.text.trim());
    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('booking_form_phone_required'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
      return;
    }

    final result = PatientBookingFormResult(
      fullName: _nameCtrl.text.trim(),
      age: age,
      bloodGroup: _blood!,
      phoneDigits: phone,
      isMale: _male,
      medicalNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      cityArea: (_city ?? '').trim().isEmpty ? null : _city,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dateEn = DateFormat.yMMMEd('en_US').format(widget.dateLocal);

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: kStaffShellGradientBottom,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              color: kStaffLuxGold.withValues(alpha: 0.95),
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: s.translate('tooltip_back'),
          ),
          title: Text(
            s.translate('booking_details_title'),
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: kStaffLuxGold.withValues(alpha: 0.98),
            ),
          ),
          centerTitle: true,
        ),
        body: DecoratedBox(
          decoration: kStaffShellGradientDecoration,
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  kToolbarHeight + MediaQuery.paddingOf(context).top + 6,
                  18,
                  24,
                ),
                children: [
                  Text(
                    widget.doctorDisplayName.trim().isEmpty
                        ? s.translate('doctor_default')
                        : widget.doctorDisplayName.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      '$dateEn · ${widget.slotTimeLabelEn}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: kStaffLuxGold.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _labeledField(
                    label: s.translate('booking_form_full_name'),
                    field: TextFormField(
                      controller: _nameCtrl,
                      style: _inputStyle,
                      decoration: _inputDecoration(
                        icon: Icons.person_rounded,
                        hint: s.translate('booking_form_full_name_hint'),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return s.translate('booking_form_name_required');
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: s.translate('booking_form_age'),
                    field: TextFormField(
                      controller: _ageCtrl,
                      style: _inputStyle,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_digitsOnly],
                      decoration: _inputDecoration(
                        icon: Icons.cake_rounded,
                        hint: '25',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return s.translate('booking_form_age_required');
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 1 || n > 130) {
                          return s.translate('booking_form_age_required');
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: s.translate('booking_form_blood'),
                    field: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _blood,
                          hint: Text(
                            s.translate('booking_form_blood_hint'),
                            style: _inputStyle.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                          iconEnabledColor: kStaffLuxGold,
                          dropdownColor: const Color(0xFF132F4C),
                          items: _kBloodGroups
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Directionality(
                                    textDirection: ui.TextDirection.ltr,
                                    child: Text(
                                      e,
                                      style: _inputStyle,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _blood = v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: s.translate('booking_form_phone'),
                    field: TextFormField(
                      controller: _phoneCtrl,
                      style: _inputStyle,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_digitsOnly],
                      maxLength: 11,
                      decoration: _inputDecoration(
                        icon: Icons.phone_rounded,
                        hint: '0750…',
                      ).copyWith(counterText: ''),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return s.translate('booking_form_phone_required');
                        }
                        final d = staffDigitsToEnglishAscii(v.trim());
                        if (d.length < 8) {
                          return s.translate('booking_form_phone_required');
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(s.translate('booking_form_gender'), style: _labelStyle),
                  const SizedBox(height: 8),
                  _genderToggle(s),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: s.translate('booking_form_medical_notes'),
                    field: TextFormField(
                      controller: _notesCtrl,
                      style: _inputStyle,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _inputDecoration(
                        icon: Icons.medical_information_rounded,
                        hint: s.translate('booking_form_medical_hint'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _labeledField(
                    label: s.translate('booking_form_city'),
                    field: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _city,
                          hint: Text(
                            s.translate('booking_form_city_hint'),
                            style: _inputStyle.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                          iconEnabledColor: kStaffLuxGold,
                          dropdownColor: const Color(0xFF132F4C),
                          items: _kCityAreas
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e, style: _inputStyle),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _city = v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: const Color(0xFF16A34A),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _submit,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            s.translate('booking_form_submit'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.white,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hint,
  }) {
    return InputDecoration(
      border: InputBorder.none,
      icon: Icon(icon, color: kStaffLuxGold.withValues(alpha: 0.85), size: 22),
      hintText: hint,
      hintStyle: _inputStyle.copyWith(
        color: Colors.white.withValues(alpha: 0.38),
      ),
      errorStyle: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFFFAB91),
        fontSize: 11.5,
      ),
    );
  }

  Widget _genderToggle(AppLocalizations loc) {
    Widget chip({
      required bool male,
      required String text,
    }) {
      final on = _male == male;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _male = male),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: on
                    ? kStaffLuxGold.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: on
                      ? kStaffLuxGold.withValues(alpha: 0.9)
                      : kStaffLuxGold.withValues(alpha: 0.28),
                  width: on ? 1.4 : 1,
                ),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: on
                      ? kStaffLuxGoldLight
                      : Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(male: true, text: loc.translate('booking_form_gender_male')),
        const SizedBox(width: 12),
        chip(male: false, text: loc.translate('booking_form_gender_female')),
      ],
    );
  }
}
