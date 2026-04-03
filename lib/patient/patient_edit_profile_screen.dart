import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../theme/patient_premium_theme.dart';

/// Thin metallic rim — same spec as [PatientDoctorCard] (0.8 px stroke).
const LinearGradient _kPersonalInfoSilverBorderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF0F0F0),
    Color(0xFFD1D1D1),
    Color(0xFFE0E0E0),
  ],
  stops: [0.0, 0.48, 1.0],
);

const Color _kPersonalInfoGold = Color(0xFFD4AF37);
const Color _kPersonalInfoGoldBronze = Color(0xFFB8860B);
const Color _kPersonalInfoGoldBg = Color(0xFFFFF4D6);
const Color _kPersonalInfoHeaderInk = Color(0xFF0D2137);

/// Edit patient [fullName] and [phone] in Firestore [users].
class PatientEditProfileScreen extends StatefulWidget {
  const PatientEditProfileScreen({super.key});

  @override
  State<PatientEditProfileScreen> createState() =>
      _PatientEditProfileScreenState();
}

class _PatientEditProfileScreenState extends State<PatientEditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _idController = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _idFocus = FocusNode();

  bool _loading = true;

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onFocusChanged);
    _phoneFocus.addListener(_onFocusChanged);
    _emailFocus.addListener(_onFocusChanged);
    _idFocus.addListener(_onFocusChanged);
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    final docId = user?.uid.trim() ?? '';
    if (docId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final data = snap.data() ?? const <String, dynamic>{};

      final dbName = (data['fullName'] ?? '').toString().trim();
      final dbPhone = (data['phone'] ?? '').toString().trim();
      final dbEmail = (data['email'] ?? '').toString().trim();

      final authName = (user?.displayName ?? '').trim();
      final authPhone = (user?.phoneNumber ?? '').trim();
      final authEmail = (user?.email ?? '').trim();

      _nameController.text = dbName.isNotEmpty
          ? dbName
          : (authName.isNotEmpty ? authName : '—');
      _phoneController.text = dbPhone.isNotEmpty
          ? dbPhone
          : (authPhone.isNotEmpty ? authPhone : '—');
      _emailController.text = dbEmail.isNotEmpty
          ? dbEmail
          : (authEmail.isNotEmpty ? authEmail : '—');
      _idController.text = docId.isNotEmpty ? docId : '—';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChanged);
    _phoneFocus.removeListener(_onFocusChanged);
    _emailFocus.removeListener(_onFocusChanged);
    _idFocus.removeListener(_onFocusChanged);
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _idFocus.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idController.dispose();
    super.dispose();
  }

  static const BorderRadius _miniCardRadius = BorderRadius.all(
    Radius.circular(16),
  );

  Widget _goldIconBadge(IconData icon) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _kPersonalInfoGoldBg.withValues(alpha: 0.88),
            border: Border.all(
              color: _kPersonalInfoGold.withValues(alpha: 0.28),
              width: 0.75,
            ),
          ),
          child: Icon(
            icon,
            size: 21,
            color: _kPersonalInfoGoldBronze,
          ),
        ),
      ),
    );
  }

  Widget _miniCardField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: _miniCardRadius,
        border: Border.all(
          color: focused
              ? _kPersonalInfoGold.withValues(alpha: 0.82)
              : const Color(0xFFCFD8DC).withValues(alpha: 0.55),
          width: focused ? 1.35 : 0.9,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _kPersonalInfoGoldBronze.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: _kPersonalInfoGold.withValues(alpha: 0.12),
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
        controller: controller,
        focusNode: focusNode,
        readOnly: true,
        showCursor: false,
        enableInteractiveSelection: true,
        textAlign: TextAlign.right,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: kPatientNavyText.withValues(alpha: 0.82),
        ),
        decoration: InputDecoration(
          labelText: label,
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
            color: _kPersonalInfoGoldBronze.withValues(alpha: 0.92),
          ),
          prefixIcon: _goldIconBadge(icon),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 58,
            minHeight: 48,
          ),
          isDense: false,
          contentPadding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
          filled: false,
          border: OutlineInputBorder(
            borderRadius: _miniCardRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: _miniCardRadius,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: _miniCardRadius,
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: _miniCardRadius,
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageRtl = AppLocaleScope.of(context).textDirection == TextDirection.rtl;

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: kPatientSkyTop,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.94),
          foregroundColor: _kPersonalInfoHeaderInk,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(
            color: _kPersonalInfoHeaderInk,
            size: 22,
          ),
          leading: IconButton(
            icon: Icon(
              pageRtl
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'زانیارییە کەسییەکان',
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 17.5,
              color: _kPersonalInfoHeaderInk,
              letterSpacing: 0.2,
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: _kPersonalInfoSilverBorderGradient,
                        boxShadow: [
                          BoxShadow(
                            color: kPatientDeepBlue.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
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
                                const Color(0xFFE3F2FD).withValues(alpha: 0.72),
                                kPatientSkyTop.withValues(alpha: 0.42),
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _miniCardField(
                                  controller: _nameController,
                                  focusNode: _nameFocus,
                                  label: 'ناوی تەواو',
                                  icon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 14),
                                _miniCardField(
                                  controller: _phoneController,
                                  focusNode: _phoneFocus,
                                  label: 'ژمارەی مۆبایل',
                                  icon: Icons.lock_rounded,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 14),
                                _miniCardField(
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  label: 'Email',
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),
                                _miniCardField(
                                  controller: _idController,
                                  focusNode: _idFocus,
                                  label: 'ID',
                                  icon: Icons.badge_outlined,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
