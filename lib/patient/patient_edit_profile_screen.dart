import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../theme/patient_premium_theme.dart';

const Color _kPersonalInfoGold = Color(0xFFD4AF37);
const Color _kPersonalInfoHeaderInk = Color(0xFF0D2137);
const Color _kPersonalInfoBorderGrey = Color(0xFFE2E8F0);
const Color _kPersonalInfoPrimaryBlue = Color(0xFF1976D2);

/// Edit patient personal info in Firestore `users`.
class PatientEditProfileScreen extends StatefulWidget {
  const PatientEditProfileScreen({super.key});

  @override
  State<PatientEditProfileScreen> createState() =>
      _PatientEditProfileScreenState();
}

class _PatientEditProfileScreenState extends State<PatientEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  final _nameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();

  bool _loading = true;
  bool _saving = false;

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onFocusChanged);
    _passwordFocus.addListener(_onFocusChanged);
    _emailFocus.addListener(_onFocusChanged);
    _addressFocus.addListener(_onFocusChanged);
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
      final dbEmail = (data['email'] ?? '').toString().trim();
      final dbPhone = (data['phone'] ?? '').toString().trim();
      final dbAddress = (data['address'] ?? '').toString().trim();

      final authName = (user?.displayName ?? '').trim();
      final authPhone = (user?.phoneNumber ?? '').trim();
      final authEmail = (user?.email ?? '').trim();

      _nameController.text = dbName.isNotEmpty
          ? dbName
          : authName;
      // Password is never loaded from Firestore.
      _passwordController.text = '';
      // "Email or phone" field: prefer email; fallback to phone; fallback to auth.
      final contact = dbEmail.isNotEmpty
          ? dbEmail
          : (dbPhone.isNotEmpty
              ? dbPhone
              : (authEmail.isNotEmpty ? authEmail : authPhone));
      _emailController.text = contact;
      _addressController.text = dbAddress;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChanged);
    _passwordFocus.removeListener(_onFocusChanged);
    _emailFocus.removeListener(_onFocusChanged);
    _addressFocus.removeListener(_onFocusChanged);
    _nameFocus.dispose();
    _passwordFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  static const BorderRadius _fieldRadius = BorderRadius.all(
    Radius.circular(16),
  );

  Widget _miniCardField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    final focused = focusNode.hasFocus;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: kPatientNavyText.withValues(alpha: 0.9),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: kPatientNavyText.withValues(alpha: 0.58),
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: kPatientPrimaryFont,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: _kPersonalInfoPrimaryBlue.withValues(alpha: 0.92),
        ),
        // RTL: keep the icon visually on the right.
        suffixIcon: Icon(
          icon,
          size: 20,
          color: focused
              ? _kPersonalInfoPrimaryBlue
              : kPatientNavyText.withValues(alpha: 0.55),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        border: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(color: _kPersonalInfoBorderGrey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(
            color: _kPersonalInfoBorderGrey.withValues(alpha: 0.95),
            width: 1,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(color: _kPersonalInfoPrimaryBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.9)),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: _fieldRadius,
          borderSide: BorderSide(color: Colors.redAccent, width: 1.4),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final user = FirebaseAuth.instance.currentUser;
    final docId = user?.uid.trim() ?? '';
    if (docId.isEmpty) return;

    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final contact = _emailController.text.trim();
      final address = _addressController.text.trim();
      final password = _passwordController.text.trim();

      final contactLooksEmail = contact.contains('@');
      final update = <String, dynamic>{
        'fullName': name,
        if (contactLooksEmail) 'email': contact else 'phone': contact,
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('users').doc(docId).set(
            update,
            SetOptions(merge: true),
          );

      if (password.isNotEmpty && user != null) {
        try {
          await user.updatePassword(password);
        } catch (_) {
          // If re-auth is required, we still keep Firestore changes.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'نەتوانرا وشەی نهێنی بگۆڕدرێت (پێویستە دووبارە بچیتە ژوورەوە).',
                  style: TextStyle(fontFamily: kPatientPrimaryFont),
                ),
              ),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'گۆڕانکارییەکان پاشکەوت کران',
              style: TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
        Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.55),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _miniCardField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              label: 'ناوی تەواو',
                              icon: Icons.person_outline_rounded,
                              validator: (v) {
                                if ((v ?? '').trim().isEmpty) {
                                  return 'تکایە ناوی تەواوت بنووسە';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _miniCardField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              label: 'وشەی نهێنی',
                              icon: Icons.lock_rounded,
                              obscureText: true,
                            ),
                            const SizedBox(height: 14),
                            _miniCardField(
                              controller: _emailController,
                              focusNode: _emailFocus,
                              label: 'ئیمەیڵ یان ژمارەی مۆبایل',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if ((v ?? '').trim().isEmpty) {
                                  return 'تکایە ئیمەیڵ یان ژمارەی مۆبایل بنووسە';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _miniCardField(
                              controller: _addressController,
                              focusNode: _addressFocus,
                              label: 'ناونیشان',
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.streetAddress,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  backgroundColor: Colors.transparent,
                                  shadowColor:
                                      _kPersonalInfoGold.withValues(alpha: 0.28),
                                  elevation: 0,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        _kPersonalInfoGoldLight(),
                                        _kPersonalInfoGold,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'پاشکەوتکردنی گۆڕانکارییەکان',
                                            style: TextStyle(
                                              fontFamily: kPatientPrimaryFont,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15.5,
                                              color: Colors.white,
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
        ),
      ),
    );
  }
}

Color _kPersonalInfoGoldLight() => const Color(0xFFF6E7A6);
