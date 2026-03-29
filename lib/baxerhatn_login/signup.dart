import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../auth/auth_gate.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
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
<<<<<<< HEAD
  final TextEditingController _verificationCodeController =
      TextEditingController();
=======
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6

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
    final s = S.of(context);
    final v = value?.trim() ?? '';
    if (v.isEmpty) return s.translate('validation_email_required');
    if (!_emailRegex.hasMatch(v)) return s.translate('validation_email_invalid');
    return null;
  }

  String? _validatePassword(String? value) {
    final s = S.of(context);
    final v = value ?? '';
    if (v.isEmpty) return s.translate('validation_password_required');
    if (v.length < 6) return s.translate('validation_password_short');
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return S.of(context).translate('validation_name_required');
    }
    return null;
  }

  Future<void> _onSignUpPressed() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) return;

<<<<<<< HEAD
    if (_isDoctor &&
        _verificationCodeController.text.trim() != _doctorActivationCode) {
      setState(() {
        _doctorCodeError = 'کۆدەکە هەڵەیە، پەیوەندی بە بەڕێوەبەر بکە';
      });
      return;
    }

    setState(() {
      _doctorCodeError = null;
      _isLoading = true;
    });
=======
    setState(() => _isLoading = true);
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

<<<<<<< HEAD
      // 1. دروستکردنی ئەکاونت لە Authentication
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
=======
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6

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
<<<<<<< HEAD
          MaterialPageRoute(
            builder: (context) => const OtpVerificationScreen(),
          ),
=======
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
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
        );
      }
    } on FirebaseAuthException catch (e) {
      final s = S.of(context);
      String msg = s.translate('signup_err_generic');
      if (e.code == 'email-already-in-use') {
        msg = s.translate('signup_err_email_in_use');
      }
      if (e.code == 'invalid-email') {
        msg = s.translate('validation_email_invalid');
      }
      if (e.code == 'weak-password') {
        msg = s.translate('validation_password_short');
      }
      if (e.code == 'network-request-failed') {
        msg = s.translate('auth_err_network');
      }
      _showSnackBar('$msg (${e.code})');
    } on FirebaseException catch (e) {
      _showSnackBar(
        '${S.of(context).translate('signup_err_firestore')} (${e.code})',
      );
<<<<<<< HEAD
      String msg = 'هەڵەیەک ڕوویدا';
      if (e.code == 'email-already-in-use') {
        msg = 'ئەم ئیمەیڵە پێشتر بەکارهاتووە';
      }
      if (e.code == 'invalid-email') msg = 'ئیمەیڵەکە هەڵەیە';
      if (e.code == 'weak-password') msg = 'وشەی نهێنی لاوازە (لانیکەم ٦ پیت)';
      if (e.code == 'network-request-failed') msg = 'ئینتەرنێتەکەت تاقیکەرەوە';

      _showSnackBar("$msg (${e.code})");
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'FIREBASE GENERAL ERROR -> plugin: ${e.plugin}, code: ${e.code}, message: ${e.message}',
      );
      debugPrint('FIREBASE STACKTRACE -> $stackTrace');
      _showSnackBar('هەڵەی Firebase ڕوویدا (${e.code})');
    } catch (e) {
      debugPrint('GENERAL ERROR TYPE: ${e.runtimeType}');
      debugPrint('GENERAL ERROR VALUE: $e');

      _showSnackBar('هەڵەیەک ڕوویدا: $e');
=======
    } catch (e) {
      _showSnackBar('${S.of(context).translate('signup_err_generic')}: $e');
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
<<<<<<< HEAD
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'KurdishFont'),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: kRtlTextDirection,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: const Text(
            'سەرکەوتوو بوو',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'داواکارییەکەت نێردرا. چاوەڕێی قبوڵکردنی بەڕێوەبەر بە.',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('باشە'),
            ),
          ],
        ),
=======
        content: Text(message, style: const TextStyle(fontFamily: 'KurdishFont')),
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
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
        textDirection: AppLocaleScope.of(context).textDirection,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
<<<<<<< HEAD
                const Text(
                  'دروستکردنی هەژمار',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Role Selection
=======
                Text(
                  S.of(context).translate('sign_up_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'KurdishFont',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  S.of(context).translate('sign_up_subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontFamily: 'KurdishFont',
                  ),
                ),
                const SizedBox(height: 22),
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleTile(
<<<<<<< HEAD
                        'نەخۆش',
                        UserRole.patient,
                        Icons.person,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildRoleTile(
                        'پزیشک',
                        UserRole.doctor,
                        Icons.medical_services,
=======
                        title: S.of(context).translate('role_patient'),
                        subtitle: S.of(context).translate('role_patient_short'),
                        role: UserRole.patient,
                        icon: Icons.person_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoleTile(
                        title: S.of(context).translate('role_doctor'),
                        subtitle: S.of(context).translate('role_doctor_short'),
                        role: UserRole.doctor,
                        icon: Icons.medical_services_rounded,
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
                      ),
                    ),
                  ],
                ),
<<<<<<< HEAD

                const SizedBox(height: 20),
                _buildTextField(
                  _fullNameController,
                  'ناوی تەواو',
                  Icons.person_outline,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _emailController,
                  'ئیمەیڵ',
                  Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _phoneController,
                  'ژمارەی تەلەفۆن',
                  Icons.phone_android,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _specialtyController,
                  _isDoctor ? 'پسپۆڕی' : 'پسپۆڕی (ئارەزوومەندانە)',
                  Icons.local_hospital,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  _passwordController,
                  'وشەی نهێنی',
                  Icons.lock_outline,
                  isPassword: true,
                ),

                if (_isDoctor) ...[
                  const SizedBox(height: 15),
                  _buildTextField(
                    _verificationCodeController,
                    'کۆدی چالاککردن',
                    Icons.verified_user,
                  ),
                  if (_doctorCodeError != null)
                    Text(
                      _doctorCodeError!,
                      style: const TextStyle(color: Colors.red),
                    ),
=======
                const SizedBox(height: 22),
                _buildTextField(
                  controller: _fullNameController,
                  label: S.of(context).translate('full_name'),
                  icon: Icons.person_outline_rounded,
                  validator: _validateName,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _emailController,
                  label: S.of(context).translate('email'),
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
                    validator: (v) => v == null || v.isEmpty
                        ? S.of(context).translate('validation_specialty_required')
                        : null,
                  ),
                  const SizedBox(height: 14),
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
                ],
                _buildTextField(
                  controller: _passwordController,
                  label: S.of(context).translate('password_hint_signup'),
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
<<<<<<< HEAD
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
=======
                    backgroundColor: _teal,
                    foregroundColor: const Color(0xFF102A43),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
                    ),
                  ),
                  onPressed: _isLoading ? null : _onSignUpPressed,
                  child: _isLoading
<<<<<<< HEAD
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'تۆماربوون',
                          style: TextStyle(fontSize: 18, color: Colors.white),
=======
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Text(
                          S.of(context).translate('register'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'KurdishFont',
                          ),
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildRoleTile(String label, UserRole role, IconData icon) {
    bool isSelected = _selectedRole == role;
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white10,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white,
              ),
            ),
          ],
=======
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
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
=======
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _isObscured,
      keyboardType: keyboardType,
<<<<<<< HEAD
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: const Color(0xFF1D1E33),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              )
            : null,
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'ئەم خانەیە پڕ بکەرەوە' : null,
=======
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
          (value) => value == null || value.trim().isEmpty
              ? S.of(context).translate('validation_field_required')
              : null,
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
    );
  }
}
