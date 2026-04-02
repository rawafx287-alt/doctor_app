import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../theme/patient_premium_theme.dart';

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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: kPatientSkyTop,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          foregroundColor: kPatientNavyText,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'زانیارییە کەسییەکان',
            style: patientBoldTextStyle(
              fontSize: 17,
              weight: FontWeight.w700,
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: DecoratedBox(
                        decoration: patientFrostedGlassDecoration(
                          borderRadius: 20,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                readOnly: true,
                                enabled: false,
                                textAlign: TextAlign.right,
                                style: patientBoldTextStyle(
                                  fontSize: 15,
                                  weight: FontWeight.w600,
                                  color: kPatientNavyText.withValues(alpha: 0.72),
                                ),
                                decoration: _inputDecoration(
                                  label: 'ناوی تەواو',
                                  icon: Icons.person_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                readOnly: true,
                                enabled: false,
                                textAlign: TextAlign.right,
                                keyboardType: TextInputType.phone,
                                style: patientBoldTextStyle(
                                  fontSize: 15,
                                  weight: FontWeight.w600,
                                  color: kPatientNavyText.withValues(alpha: 0.72),
                                ),
                                decoration: _inputDecoration(
                                  label: 'ژمارەی مۆبایل',
                                  icon: Icons.lock_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                readOnly: true,
                                enabled: false,
                                textAlign: TextAlign.right,
                                style: patientBoldTextStyle(
                                  fontSize: 15,
                                  weight: FontWeight.w600,
                                  color: kPatientNavyText.withValues(alpha: 0.72),
                                ),
                                decoration: _inputDecoration(
                                  label: 'Email',
                                  icon: Icons.alternate_email_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _idController,
                                readOnly: true,
                                enabled: false,
                                textAlign: TextAlign.right,
                                style: patientBoldTextStyle(
                                  fontSize: 15,
                                  weight: FontWeight.w600,
                                  color: kPatientNavyText.withValues(alpha: 0.72),
                                ),
                                decoration: _inputDecoration(
                                  label: 'ID',
                                  icon: Icons.badge_outlined,
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
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: kPatientNavyText.withValues(alpha: 0.55),
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
      filled: true,
      fillColor: const Color(0xFFECEFF1).withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: const Color(0xFFCFD8DC).withValues(alpha: 0.95),
          width: 0.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: const Color(0xFFCFD8DC).withValues(alpha: 0.95),
          width: 0.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.2),
      ),
    );
  }
}
