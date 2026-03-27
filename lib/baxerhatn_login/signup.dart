import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app_rtl.dart';
import '../auth/auth_gate.dart';
import '../patient/patient_home_screen.dart';
import '../specialty_categories.dart';

enum UserRole { patient, doctor }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.patient;
  bool _isObscured = true;
  bool _isLoading = false;
  String? _doctorSpecialty;

  static const Color _bg = Color(0xFF0A0E21);
  static const Color _surface = Color(0xFF1D1E33);
  static const Color _teal = Color(0xFF42A5F5);
  static const Color _text = Color(0xFFD9E2EC);
  static const Color _muted = Color(0xFF829AB1);

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isDoctor => _selectedRole == UserRole.doctor;

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'ئیمەیڵ پێویستە';
    if (!_emailRegex.hasMatch(v)) return 'ئیمەیڵەکە دروست نییە';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'وشەی نهێنی پێویستە';
    if (v.length < 6) return 'وشەی نهێنی لانیکەم ٦ پیت بێت';
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'ناو پێویستە';
    return null;
  }

  Future<void> _onSignUpPressed() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) return;

    setState(() => _isLoading = true);

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception('User ID is null');

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': '',
        'role': _isDoctor ? 'Doctor' : 'Patient',
        'specialty': _isDoctor ? (_doctorSpecialty ?? '').trim() : '',
        'isApproved': _isDoctor ? false : true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      if (_isDoctor) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const DoctorPendingApprovalScreen(),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const PatientHomeScreen(),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'هەڵەیەک ڕوویدا';
      if (e.code == 'email-already-in-use') msg = 'ئەم ئیمەیڵە پێشتر بەکارهاتووە';
      if (e.code == 'invalid-email') msg = 'ئیمەیڵەکە دروست نییە';
      if (e.code == 'weak-password') msg = 'وشەی نهێنی لانیکەم ٦ پیت بێت';
      if (e.code == 'network-request-failed') msg = 'ئینتەرنێتەکەت تاقیکەرەوە';
      _showSnackBar('$msg (${e.code})');
    } on FirebaseException catch (e) {
      _showSnackBar('هەڵەی Firebase (${e.code})');
    } catch (e) {
      _showSnackBar('هەڵەیەک ڕوویدا: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'KurdishFont')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _text,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: kRtlTextDirection,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'دروستکردنی هەژمار',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'KurdishFont',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ڕۆڵی خۆت هەڵبژێرە',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontFamily: 'KurdishFont',
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleTile(
                        title: 'من نەخۆشم',
                        subtitle: 'Patient',
                        role: UserRole.patient,
                        icon: Icons.person_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoleTile(
                        title: 'من پزیشکم',
                        subtitle: 'Doctor',
                        role: UserRole.doctor,
                        icon: Icons.medical_services_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _buildTextField(
                  controller: _fullNameController,
                  label: 'ناوی تەواو',
                  icon: Icons.person_outline_rounded,
                  validator: _validateName,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _emailController,
                  label: 'ئیمەیڵ',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 14),
                if (_isDoctor) ...[
                  KurdishDoctorSpecialtyDropdown(
                    value: _doctorSpecialty,
                    accentColor: _teal,
                    onChanged: (v) => setState(() => _doctorSpecialty = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'پسپۆڕی هەڵبژێرە لە لیستەکە' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                _buildTextField(
                  controller: _passwordController,
                  label: 'وشەی نهێنی (لانیکەم ٦ پیت)',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: const Color(0xFF102A43),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _onSignUpPressed,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text(
                          'تۆماربوون',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTile({
    required String title,
    required String subtitle,
    required UserRole role,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _selectedRole = role;
          if (role == UserRole.patient) _doctorSpecialty = null;
        }),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _teal : Colors.white12,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                icon,
                color: isSelected ? _teal : _muted,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? _text : _muted,
                  fontFamily: 'KurdishFont',
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _isObscured,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: _text,
        fontFamily: 'KurdishFont',
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted, fontFamily: 'KurdishFont'),
        hintStyle: const TextStyle(color: _muted),
        prefixIcon: Icon(icon, color: _teal),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _muted,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              )
            : null,
      ),
      validator: validator ??
          (value) => value == null || value.trim().isEmpty ? 'ئەم خانەیە پڕ بکەرەوە' : null,
    );
  }
}
