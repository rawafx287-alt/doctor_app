import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';
import 'patient_booking_form_result.dart';

/// Darker premium shell (below staff gradient — deeper base).
const Color _kPremiumBase = Color(0xFF050A12);
const Color _kPremiumPanel = Color(0xFF0A1420);
const double _kFieldRadius = 13.0;

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

  static const TextStyle _labelInFieldStyle = TextStyle(
    fontFamily: kPatientPrimaryFont,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 1.2,
    color: Color(0xFFE8D5A3),
  );

  TextStyle get _inputStyle => TextStyle(
    fontFamily: kPatientPrimaryFont,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: Colors.white.withValues(alpha: 0.94),
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    required String label,
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    final gold = kStaffLuxGold.withValues(alpha: 0.42);
    final goldFocus = kStaffLuxGold.withValues(alpha: 0.78);
    return InputDecoration(
      isDense: false,
      alignLabelWithHint: alignLabelWithHint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelText: label,
      labelStyle: _labelInFieldStyle,
      floatingLabelStyle: _labelInFieldStyle.copyWith(
        fontSize: 12.5,
        color: kStaffLuxGoldLight.withValues(alpha: 0.95),
      ),
      hintText: hint,
      hintStyle: _inputStyle.copyWith(
        color: Colors.white.withValues(alpha: 0.35),
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: kStaffLuxGold.withValues(alpha: 0.82),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      filled: true,
      fillColor: _kPremiumPanel.withValues(alpha: 0.65),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kFieldRadius),
        borderSide: BorderSide(color: gold, width: 0.85),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kFieldRadius),
        borderSide: BorderSide(color: gold, width: 0.85),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kFieldRadius),
        borderSide: BorderSide(color: goldFocus, width: 1.05),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kFieldRadius),
        borderSide: const BorderSide(color: Color(0xFFE57373), width: 0.9),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kFieldRadius),
        borderSide: const BorderSide(color: Color(0xFFFFAB91), width: 1.0),
      ),
      errorStyle: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFFFCCBC),
        fontSize: 11.5,
      ),
    );
  }

  void _submit() {
    final s = S.of(context);
    if (!_formKey.currentState!.validate()) return;
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
      medicalNotes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      cityArea: (_city ?? '').trim().isEmpty ? null : _city,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dateEn = DateFormat.yMMMEd('en_US').format(widget.dateLocal);
    final doctorName = widget.doctorDisplayName.trim().isEmpty
        ? s.translate('doctor_default')
        : widget.doctorDisplayName.trim();
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF02050A),
                      kStaffShellGradientTop,
                      kStaffShellGradientMid,
                      kStaffShellGradientBottom,
                    ],
                    stops: [0.0, 0.22, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: true,
            body: Form(
              key: _formKey,
              child: NestedScrollView(
                floatHeaderSlivers: true,
                physics: const BouncingScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverOverlapAbsorber(
                      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                        context,
                      ),
                      sliver: SliverAppBar(
                        pinned: true,
                        floating: true,
                        snap: true,
                        stretch: true,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        backgroundColor: _kPremiumBase.withValues(alpha: 0.94),
                        surfaceTintColor: Colors.transparent,
                        expandedHeight: 132,
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: kStaffLuxGold.withValues(alpha: 0.95),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: s.translate('tooltip_back'),
                        ),
                        // When collapsed: doctor name stays in the toolbar (smooth handoff from header).
                        title: Text(
                          doctorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.96),
                          ),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          collapseMode: CollapseMode.parallax,
                          stretchModes: const [StretchMode.zoomBackground],
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(
                                        0xFF0A1628,
                                      ).withValues(alpha: 0.96),
                                      _kPremiumBase.withValues(alpha: 0.88),
                                    ],
                                  ),
                                ),
                              ),
                              SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    14,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        doctorName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                          height: 1.25,
                                          color: Colors.white.withValues(
                                            alpha: 0.94,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Directionality(
                                        textDirection: ui.TextDirection.ltr,
                                        child: Text(
                                          '$dateEn · ${widget.slotTimeLabelEn}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: kPatientPrimaryFont,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: kStaffLuxGold.withValues(
                                              alpha: 0.82,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: Builder(
                  builder: (context) {
                    return CustomScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        SliverOverlapInjector(
                          handle:
                              NestedScrollView.sliverOverlapAbsorberHandleFor(
                                context,
                              ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            4,
                            20,
                            24 + keyboardBottom,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _nameCtrl,
                                  style: _inputStyle,
                                  decoration: _fieldDecoration(
                                    icon: Icons.person_rounded,
                                    label: s.translate(
                                      'booking_form_full_name',
                                    ),
                                    hint: s.translate(
                                      'booking_form_full_name_hint',
                                    ),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return s.translate(
                                        'booking_form_name_required',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _ageCtrl,
                                  style: _inputStyle,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [_digitsOnly],
                                  decoration: _fieldDecoration(
                                    icon: Icons.cake_rounded,
                                    label: s.translate('booking_form_age'),
                                    hint: '25',
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return s.translate(
                                        'booking_form_age_required',
                                      );
                                    }
                                    final n = int.tryParse(v.trim());
                                    if (n == null || n < 1 || n > 130) {
                                      return s.translate(
                                        'booking_form_age_required',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: _blood,
                                  isExpanded: true,
                                  decoration: _fieldDecoration(
                                    icon: Icons.bloodtype_rounded,
                                    label: s.translate('booking_form_blood'),
                                    hint: s.translate(
                                      'booking_form_blood_hint',
                                    ),
                                  ),
                                  dropdownColor: const Color(0xFF132F4C),
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: kStaffLuxGold.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                  style: _inputStyle,
                                  items: _kBloodGroups
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Directionality(
                                            textDirection: ui.TextDirection.ltr,
                                            child: Text(e, style: _inputStyle),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() => _blood = v),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return s.translate(
                                        'booking_form_blood_required',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _phoneCtrl,
                                  style: _inputStyle,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [_digitsOnly],
                                  maxLength: 11,
                                  decoration: _fieldDecoration(
                                    icon: Icons.phone_rounded,
                                    label: s.translate('booking_form_phone'),
                                    hint: '0750…',
                                  ).copyWith(counterText: ''),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return s.translate(
                                        'booking_form_phone_required',
                                      );
                                    }
                                    final d = staffDigitsToEnglishAscii(
                                      v.trim(),
                                    );
                                    if (d.length < 8) {
                                      return s.translate(
                                        'booking_form_phone_required',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  s.translate('booking_form_gender'),
                                  style: _labelInFieldStyle.copyWith(
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _GenderChips(
                                  isMale: _male,
                                  maleLabel: s.translate(
                                    'booking_form_gender_male',
                                  ),
                                  femaleLabel: s.translate(
                                    'booking_form_gender_female',
                                  ),
                                  onChanged: (male) =>
                                      setState(() => _male = male),
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _notesCtrl,
                                  style: _inputStyle,
                                  minLines: 3,
                                  maxLines: 5,
                                  decoration: _fieldDecoration(
                                    icon: Icons.medical_information_rounded,
                                    label: s.translate(
                                      'booking_form_medical_notes',
                                    ),
                                    hint: s.translate(
                                      'booking_form_medical_hint',
                                    ),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: _city,
                                  isExpanded: true,
                                  decoration: _fieldDecoration(
                                    icon: Icons.location_city_rounded,
                                    label: s.translate('booking_form_city'),
                                    hint: s.translate('booking_form_city_hint'),
                                  ),
                                  dropdownColor: const Color(0xFF132F4C),
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: kStaffLuxGold.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                  style: _inputStyle,
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
                                const SizedBox(height: 32),
                                Material(
                                  color: const Color(0xFF16A34A),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    _kFieldRadius,
                                  ),
                                  child: InkWell(
                                    onTap: _submit,
                                    borderRadius: BorderRadius.circular(
                                      _kFieldRadius,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Male / Female — selectable cards with clear active state (no full-screen setState churn).
class _GenderChips extends StatelessWidget {
  const _GenderChips({
    required this.isMale,
    required this.maleLabel,
    required this.femaleLabel,
    required this.onChanged,
  });

  final bool isMale;
  final String maleLabel;
  final String femaleLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderChipCard(
            selected: isMale,
            icon: Icons.male_rounded,
            label: maleLabel,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _GenderChipCard(
            selected: !isMale,
            icon: Icons.female_rounded,
            label: femaleLabel,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _GenderChipCard extends StatelessWidget {
  const _GenderChipCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gold = kStaffLuxGold.withValues(alpha: selected ? 0.95 : 0.35);
    final bg = selected
        ? kStaffLuxGold.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.05);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bg,
            border: Border.all(color: gold, width: selected ? 1.35 : 0.85),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kStaffLuxGold.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected
                    ? kStaffLuxGoldLight
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
