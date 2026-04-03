import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../theme/patient_premium_theme.dart';

/// Thin metallic rim — same as [PatientEditProfileScreen] (0.8 px stroke).
const LinearGradient _kSilverBorderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF0F0F0),
    Color(0xFFD1D1D1),
    Color(0xFFE0E0E0),
  ],
  stops: [0.0, 0.48, 1.0],
);

const Color _kGold = Color(0xFFD4AF37);
const Color _kGoldBronze = Color(0xFFB8860B);
const Color _kGoldBg = Color(0xFFFFF4D6);

const BorderRadius _kMiniCardRadius = BorderRadius.all(Radius.circular(16));

/// Secretary: pick a doctor and edit `users.{doctorUid}.hospitalName` (patient cards).
class SecretaryClinicSettingsScreen extends StatefulWidget {
  const SecretaryClinicSettingsScreen({super.key});

  @override
  State<SecretaryClinicSettingsScreen> createState() =>
      _SecretaryClinicSettingsScreenState();
}

class _SecretaryClinicSettingsScreenState
    extends State<SecretaryClinicSettingsScreen> {
  String? _pickedDoctorId;
  final TextEditingController _hospitalController = TextEditingController();
  final FocusNode _hospitalFocus = FocusNode();

  bool _loadingDoctor = false;
  bool _saving = false;

  void _onHospitalFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _hospitalFocus.addListener(_onHospitalFocusChanged);
  }

  @override
  void dispose() {
    _hospitalFocus.removeListener(_onHospitalFocusChanged);
    _hospitalFocus.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  static String _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final t = (data[k] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  Future<void> _loadHospitalForDoctor(String doctorId) async {
    final id = doctorId.trim();
    if (id.isEmpty) return;
    setState(() => _loadingDoctor = true);
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(id).get();
      final data = snap.data() ?? const <String, dynamic>{};
      var h = (data['hospitalName'] ?? '').toString().trim();
      if (h.isEmpty) {
        h = _firstNonEmpty(data, ['hospital_name_ku', 'clinicName']);
      }
      if (mounted) _hospitalController.text = h;
    } finally {
      if (mounted) setState(() => _loadingDoctor = false);
    }
  }

  Future<void> _save() async {
    final s = S.of(context);
    final id = _pickedDoctorId?.trim() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('master_calendar_pick_doctor'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(id).set(
        {'hospitalName': _hospitalController.text.trim()},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_saved_ok'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _goldIconBadge(IconData icon) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _kGoldBg.withValues(alpha: 0.88),
            border: Border.all(
              color: _kGold.withValues(alpha: 0.28),
              width: 0.75,
            ),
          ),
          child: Icon(
            icon,
            size: 21,
            color: _kGoldBronze,
          ),
        ),
      ),
    );
  }

  Widget _hospitalMiniCardField() {
    final loc = S.of(context);
    final focused = _hospitalFocus.hasFocus;
    final rtl = AppLocaleScope.of(context).textDirection == TextDirection.rtl;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: _kMiniCardRadius,
        border: Border.all(
          color: focused
              ? _kGold.withValues(alpha: 0.82)
              : const Color(0xFFCFD8DC).withValues(alpha: 0.55),
          width: focused ? 1.35 : 0.9,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _kGoldBronze.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: _kGold.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: kPatientDeepBlue.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: TextFormField(
        controller: _hospitalController,
        focusNode: _hospitalFocus,
        textAlign: rtl ? TextAlign.right : TextAlign.left,
        textInputAction: TextInputAction.done,
        maxLines: 2,
        style: TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: kPatientNavyText.withValues(alpha: 0.82),
        ),
        decoration: InputDecoration(
          labelText: loc.translate('doctor_field_hospital_display_simple'),
          labelStyle: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: kPatientNavyText.withValues(alpha: 0.52),
          ),
          floatingLabelStyle: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: _kGoldBronze.withValues(alpha: 0.92),
          ),
          prefixIcon: _goldIconBadge(Icons.apartment_rounded),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 58,
            minHeight: 48,
          ),
          contentPadding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
          filled: false,
          border: OutlineInputBorder(
            borderRadius: _kMiniCardRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: _kMiniCardRadius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: _kMiniCardRadius,
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          title: Text(
            s.translate('secretary_clinic_settings_title'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
          actions: [
            IconButton(
              tooltip: s.translate('tooltip_logout'),
              onPressed: () => performAppLogout(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'Doctor')
                      .where('isApproved', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const LinearProgressIndicator(minHeight: 2);
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Text(
                        s.translate('master_calendar_no_doctors'),
                        style: const TextStyle(
                          color: Color(0xFF829AB1),
                          fontFamily: 'NRT',
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _pickedDoctorId != null &&
                              docs.any((d) => d.id == _pickedDoctorId)
                          ? _pickedDoctorId
                          : null,
                      dropdownColor: const Color(0xFF1D1E33),
                      iconEnabledColor: _kGoldBronze,
                      decoration: InputDecoration(
                        labelText: s.translate('master_calendar_pick_doctor'),
                        labelStyle: const TextStyle(
                          color: Color(0xFF829AB1),
                          fontFamily: 'NRT',
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1D1E33),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _kGold.withValues(alpha: 0.35),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _kGold.withValues(alpha: 0.28),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _kGoldBronze.withValues(alpha: 0.65),
                            width: 1.2,
                          ),
                        ),
                      ),
                      items: docs
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                localizedDoctorFullName(
                                  d.data(),
                                  AppLocaleScope.of(context).effectiveLanguage,
                                ),
                                style: const TextStyle(
                                  fontFamily: 'NRT',
                                  color: Color(0xFFD9E2EC),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        setState(() => _pickedDoctorId = v);
                        if (v != null) await _loadHospitalForDoctor(v);
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: _pickedDoctorId == null
                    ? Center(
                        child: Text(
                          s.translate('master_calendar_pick_doctor'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'NRT',
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_loadingDoctor)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _kGoldBronze,
                                    ),
                                  ),
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: _kSilverBorderGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: kPatientDeepBlue.withValues(alpha: 0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(0.8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(19.2),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.96),
                                        const Color(0xFFE3F2FD)
                                            .withValues(alpha: 0.72),
                                        kPatientSkyTop.withValues(alpha: 0.42),
                                      ],
                                      stops: const [0.0, 0.55, 1.0],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      18,
                                      18,
                                      20,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          s.translate(
                                            'secretary_clinic_settings_card_hint',
                                          ),
                                          style: TextStyle(
                                            fontFamily: kPatientPrimaryFont,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5,
                                            color: kPatientNavyText
                                                .withValues(alpha: 0.55),
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        _hospitalMiniCardField(),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                          onPressed:
                                              _saving ? null : _save,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _kGoldBronze,
                                            foregroundColor:
                                                const Color(0xFF102A43),
                                            disabledBackgroundColor:
                                                _kGoldBronze.withValues(
                                              alpha: 0.45,
                                            ),
                                            minimumSize: const Size(
                                              double.infinity,
                                              50,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: _saving
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    color: Color(0xFF102A43),
                                                  ),
                                                )
                                              : Text(
                                                  s.translate(
                                                    'profile_save_changes',
                                                  ),
                                                  style: const TextStyle(
                                                    fontFamily: 'NRT',
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                        ),
                                      ],
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
          ),
        ),
      ),
    );
  }
}
