import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/phone_auth_config.dart';
import '../auth/phone_normalization.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../specialty_categories.dart';
import 'registration_success_page.dart';

enum UserRole { patient, doctor }

/// Email/password registration: [createUserWithEmailAndPassword], Firestore `users` doc.
/// Doctor role requires a security code dialog at role selection time.
/// User stays signed in; [Navigator.pop] dismisses this route so [AuthGate] shows home.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _addressFieldKey =
      GlobalKey<FormFieldState<String>>();
  final FocusNode _emailFocusNode = FocusNode();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
<<<<<<< HEAD
<<<<<<< HEAD
  final TextEditingController _verificationCodeController =
      TextEditingController();
=======
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
=======
  final TextEditingController _confirmPasswordController = TextEditingController();
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af

  UserRole _selectedRole = UserRole.patient;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _doctorSpecialty;

  static const Color _teal = Color(0xFF42A5F5);
  static const Color _roleBlue = Color(0xFF42A5F5);
  static const Color _roleGreen = Color(0xFF66BB6A);
  static const Color _text = Color(0xFFD9E2EC);
  static const Color _muted = Color(0xFF829AB1);

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onEmailFocusChanged);
  }

  void _onEmailFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onEmailFocusChanged);
    _emailFocusNode.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isDoctor => _selectedRole == UserRole.doctor;
  Color get _primaryRoleColor => _isDoctor ? _roleBlue : _roleGreen;

  /// Doctor registration dialog; treat as UX gate only—enforce rules in backend for real security.
  static const String _doctorActivationCode = 'HR64';

  /// Requires `@` and a domain ending in `.com` (case-insensitive).
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.com$',
    caseSensitive: false,
  );

  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  String? _validateEmail(String? value) {
    if (!_isDoctor) return null;
    final s = S.of(context);
    final v = value?.trim() ?? '';
    if (v.isEmpty) return s.translate('validation_email_required');
    if (!_emailRegex.hasMatch(v)) {
      // Do not show "invalid format" while the field is focused (still typing).
      if (_emailFocusNode.hasFocus) return null;
      return s.translate('validation_email_invalid');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final s = S.of(context);
    final v = value ?? '';
    if (v.isEmpty) return s.translate('validation_password_required');
    if (v.length < 8) return s.translate('validation_password_short');
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final s = S.of(context);
    final v = (value ?? '').trim();
    if (v.isEmpty) return s.translate('validation_password_required');
    if (v != _passwordController.text.trim()) {
      return s.translate('validation_password_mismatch');
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return S.of(context).translate('validation_name_required');
    }
    return null;
  }

  static const String _kPhoneMustBe11Digits = 'پێویستە ژمارەی مۆبایل ١١ ژمارە بێت';

  String? _validatePhone(String? value) {
    final s = S.of(context);
    final v = normalizePhoneDigits(value ?? '');
    if (v.isEmpty) return s.translate('validation_phone_required');
    if (!_digitsOnly.hasMatch(v)) {
      return s.translate('validation_phone_digits_only');
    }
    if (v.length != 11) {
      return _kPhoneMustBe11Digits;
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (!_isDoctor) return null;
    if (value == null || value.trim().isEmpty) {
      return S.of(context).translate('validation_address_required');
    }
    return null;
  }

  Future<void> _onRoleSelected(UserRole role) async {
    if (_isLoading) return;
    if (role == _selectedRole) return;

    if (role == UserRole.patient) {
      setState(() {
        _selectedRole = UserRole.patient;
        _doctorSpecialty = null;
      });
      return;
    }

    final result = await _showDoctorSecurityDialog();
    if (!mounted) return;

    if (result == true) {
      setState(() => _selectedRole = UserRole.doctor);
      return;
    }

    setState(() {
      _selectedRole = UserRole.patient;
      _doctorSpecialty = null;
    });
    if (result == false) {
      _showSnackBar(S.of(context).translate('signup_doctor_security_wrong'));
    }
  }

  Future<void> _onSignUpPressed() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _registerWithFirebase();
  }

<<<<<<< HEAD
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

=======
  /// Returns `true` for success, `false` for wrong code, `null` for cancel.
  Future<bool?> _showDoctorSecurityDialog() async {
    if (!mounted) return null;
    final result = await showDialog<bool?>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => _DoctorSecurityDialogShell(
        child: _DoctorSecurityCodeDialog(
          requiredCode: _doctorActivationCode,
        ),
      ),
    );
    if (!mounted) return null;
    return result;
  }

  Future<void> _rollbackNewAuthUser(User? user) async {
    if (user == null) return;
    try {
      await user.delete();
    } catch (_) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
  }

  void _goRegistrationSuccess() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegistrationSuccessPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  Future<void> _registerWithFirebase() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      if (!_isDoctor) {
        await _registerPatientPhoneKeyed();
      } else {
        await _registerDoctorWithEmail();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

<<<<<<< HEAD
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
=======
  /// Phone = Firestore doc id; Firebase Auth uses [phoneAuthEmail].
  /// If Auth already has this phone email, signs in and [SetOptions.merge] writes Firestore.
  Future<void> _registerPatientPhoneKeyed() async {
    UserCredential? userCred;
    var profileSavedToFirestore = false;
    var linkedExistingAuthUser = false;
    try {
      final phone = normalizePhoneDigits(_phoneController.text);
      final password = _passwordController.text.trim();
      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final fullName = '$first $last'.trim();
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af

      final profilePayload = <String, dynamic>{
        'phone': phone,
        'password': password,
        'role': 'patient',
        'fullName': fullName.isEmpty ? first : fullName,
      };

      try {
        userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: phoneAuthEmail(phone),
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        debugPrint(
          '[SignUp] createUser: code=${e.code} message=${e.message}',
        );
        if (e.code == 'email-already-in-use') {
          try {
            userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: phoneAuthEmail(phone),
              password: password,
            );
            linkedExistingAuthUser = true;
          } on FirebaseAuthException catch (e2) {
            debugPrint(
              '[SignUp] signIn (existing auth): code=${e2.code} message=${e2.message}',
            );
            if (!mounted) return;
            final s = S.of(context);
            final wrongPw = e2.code == 'wrong-password' ||
                e2.code == 'invalid-credential';
            _showSnackBar(
              wrongPw
                  ? s.translate('auth_err_wrong_credential')
                  : '${s.translate('signup_err_email_in_use')} (${e2.code})',
            );
            return;
          }
        } else {
          if (!mounted) return;
          final s = S.of(context);
          String msg = s.translate('signup_err_generic');
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
          return;
        }
      }

      if (userCred.user == null) {
        if (!mounted) return;
        _showSnackBar(S.of(context).translate('signup_err_generic'));
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(phone)
          .set(profilePayload, SetOptions(merge: true));
      profileSavedToFirestore = true;

      if (!mounted) return;
<<<<<<< HEAD

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
=======
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _goRegistrationSuccess();
    } on FirebaseException catch (e) {
      debugPrint(
        '[SignUp] FirebaseException (Firestore): code=${e.code} message=${e.message}',
      );
      if (!linkedExistingAuthUser) {
        await _rollbackNewAuthUser(userCred?.user);
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af
      }
      if (!mounted) return;
      _showSnackBar(
        '${S.of(context).translate('signup_err_firestore')} (${e.code})',
      );
    } catch (e) {
      debugPrint('[SignUp] Unexpected error: $e');
      if (!profileSavedToFirestore && !linkedExistingAuthUser) {
        await _rollbackNewAuthUser(userCred?.user);
      }
      if (!mounted) return;
      _showSnackBar('${S.of(context).translate('signup_err_generic')}: $e');
    }
  }

  Future<void> _registerDoctorWithEmail() async {
    UserCredential? userCred;
    var profileSavedToFirestore = false;
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCred.user;
      if (user == null) throw Exception('User ID is null');

      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final fullName = '$first $last'.trim();
      final phone = normalizePhoneDigits(_phoneController.text);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': first,
        'lastName': last,
        'fullName': fullName.isEmpty ? first : fullName,
        'email': email,
        'phone': phone,
        'address': _addressController.text.trim(),
        'role': 'Doctor',
        'specialty': (_doctorSpecialty ?? '').trim(),
        'isApproved': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      profileSavedToFirestore = true;

      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _goRegistrationSuccess();
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[SignUp] FirebaseAuthException: code=${e.code} message=${e.message}',
      );
      if (!mounted) return;
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
      debugPrint(
        '[SignUp] FirebaseException (Firestore): code=${e.code} message=${e.message}',
      );
      await _rollbackNewAuthUser(userCred?.user);
      if (!mounted) return;
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
      debugPrint('[SignUp] Unexpected error: $e');
      if (!profileSavedToFirestore) {
        await _rollbackNewAuthUser(userCred?.user);
      }
      if (!mounted) return;
      _showSnackBar('${S.of(context).translate('signup_err_generic')}: $e');
<<<<<<< HEAD
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
    } finally {
      if (mounted) setState(() => _isLoading = false);
=======
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent.withValues(alpha: 0.2),
        elevation: 0,
        foregroundColor: _text,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
<<<<<<< HEAD
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
=======
        child: Stack(
          children: [
            _buildBackground(),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color(0xFFE2E8F0),
                      ],
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    );
                  },
                  child: Text(
                    S.of(context).translate('sign_up_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.vazirmatn(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.85,
                      height: 1.25,
                      shadows: [
                        Shadow(
                          color: Colors.cyan.withValues(alpha: 0.5),
                          blurRadius: 15,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  S.of(context).translate('sign_up_subtitle'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.vazirmatn(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
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
                  controller: _firstNameController,
                  label: S.of(context).translate('signup_first_name'),
                  icon: Icons.badge_outlined,
                  validator: _validateName,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _lastNameController,
                  label: S.of(context).translate('signup_last_name'),
                  icon: Icons.person_outline_rounded,
                  validator: _validateName,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _phoneController,
                  label: S.of(context).translate('signup_mobile'),
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 11,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
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
                  isConfirmPassword: false,
                  englishPasswordOnly: true,
                  validator: _validatePassword,
                ),
<<<<<<< HEAD
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
=======
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: S.of(context).translate('password_confirm'),
                  icon: Icons.lock_person_outlined,
                  isPassword: true,
                  isConfirmPassword: true,
                  englishPasswordOnly: true,
                  validator: _validateConfirmPassword,
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  key: _addressFieldKey,
                  controller: _addressController,
                  label: S.of(context).translate('signup_address'),
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                  keyboardType: TextInputType.streetAddress,
                  validator: _validateAddress,
                  onChanged: (_) =>
                      _addressFieldKey.currentState?.validate(),
                ),
                const SizedBox(height: 28),
                _buildRegisterButton(),
              ],
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1330), Color(0xFF05070E), Color(0xFF020306)],
        ),
      ),
      child: Stack(
        children: const [
          _SignBgBlob(
            alignment: Alignment(-1.0, -0.75),
            size: 240,
            color: Color(0xFF29B6F6),
          ),
          _SignBgBlob(
            alignment: Alignment(1.0, -0.35),
            size: 200,
            color: Color(0xFF7C4DFF),
          ),
          _SignBgBlob(
            alignment: Alignment(0.15, 0.95),
            size: 240,
            color: Color(0xFF66BB6A),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _primaryRoleColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isLoading
              ? null
              : () async {
                  await HapticFeedback.lightImpact();
                  if (!mounted) return;
                  await _onSignUpPressed();
                },
          child: SizedBox(
            height: 56,
            child: Center(
              child: _isLoading
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
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
    bool alignLabelWithHint = false,
    bool multiline = false,
  }) {
    return InputDecoration(
      alignLabelWithHint: alignLabelWithHint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      isDense: false,
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(
        color: _muted,
        fontFamily: 'KurdishFont',
        fontSize: 14,
        height: 1.25,
      ),
      floatingLabelStyle: const TextStyle(
        color: _muted,
        fontFamily: 'KurdishFont',
        fontSize: 12,
        height: 1.15,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: _muted.withValues(alpha: 0.65),
        fontFamily: 'KurdishFont',
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.10),
      contentPadding: multiline
          ? const EdgeInsets.fromLTRB(14, 22, 14, 18)
          : const EdgeInsets.fromLTRB(14, 18, 14, 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x40FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x90FFFFFF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
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
    final selectedColor = role == UserRole.doctor ? _roleBlue : _roleGreen;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : () => _onRoleSelected(role),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? selectedColor : const Color(0x40FFFFFF),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                icon,
                color: isSelected ? selectedColor : _muted,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? _text : _muted.withValues(alpha: 0.95),
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
    Key? key,
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isConfirmPassword = false,
    bool englishPasswordOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
<<<<<<< HEAD
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
=======
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    final obscure = isConfirmPassword ? _obscureConfirm : _obscurePassword;

    final formatters = <TextInputFormatter>[
      if (englishPasswordOnly)
        FilteringTextInputFormatter.allow(
          RegExp(r'[a-zA-Z0-9!@#$%^&*()_+-=]'),
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af
        ),
      ...?inputFormatters,
    ];

    final baseDecoration = _fieldDecoration(
      alignLabelWithHint: maxLines > 1,
      multiline: maxLines > 1,
      labelText: label,
      prefixIcon: Icon(icon, color: _primaryRoleColor),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _muted,
              ),
              onPressed: () => setState(() {
                if (isConfirmPassword) {
                  _obscureConfirm = !_obscureConfirm;
                } else {
                  _obscurePassword = !_obscurePassword;
                }
              }),
            )
          : null,
    );
    final decoration = (maxLength != null
            ? baseDecoration.copyWith(counterText: '')
            : baseDecoration)
        .copyWith(
      // Glass blur sits behind the field; keep field fill transparent so labels aren't clipped.
      fillColor: Colors.transparent,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
<<<<<<< HEAD
                onPressed: () => setState(() => _isObscured = !_isObscured),
              )
            : null,
      ),
      validator: validator ??
          (value) => value == null || value.trim().isEmpty
              ? S.of(context).translate('validation_field_required')
              : null,
>>>>>>> 4d879aa05e50f5d2db3a2e7c6a92215aa64c62e6
=======
              ),
            ),
          ),
        ),
        TextFormField(
          key: key,
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword && obscure,
          keyboardType: keyboardType,
          maxLines: isPassword ? 1 : maxLines,
          maxLength: maxLength,
          inputFormatters: formatters.isEmpty ? null : formatters,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          style: const TextStyle(
            color: _text,
            fontFamily: 'KurdishFont',
            fontWeight: FontWeight.w600,
          ),
          decoration: decoration,
          validator: validator ??
              (value) => value == null || value.trim().isEmpty
                  ? S.of(context).translate('validation_field_required')
                  : null,
        ),
      ],
    );
  }
}

class _SignBgBlob extends StatelessWidget {
  const _SignBgBlob({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 58, sigmaY: 58),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.30),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blurred + dimmed backdrop behind the security code dialog.
class _DoctorSecurityDialogShell extends StatelessWidget {
  const _DoctorSecurityDialogShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 5 * t,
                    sigmaY: 5 * t,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.5 * t),
                  ),
                ),
              ),
            ),
            Center(child: child),
          ],
        );
      },
    );
  }
}

/// Owns [TextEditingController] so it is disposed with the dialog route (avoids
/// `_dependents.isEmpty` if the controller is disposed while the overlay is closing).
class _DoctorSecurityCodeDialog extends StatefulWidget {
  const _DoctorSecurityCodeDialog({required this.requiredCode});

  final String requiredCode;

  @override
  State<_DoctorSecurityCodeDialog> createState() =>
      _DoctorSecurityCodeDialogState();
}

class _DoctorSecurityCodeDialogState extends State<_DoctorSecurityCodeDialog> {
  static const Color _teal = Color(0xFF42A5F5);
  static const Color _text = Color(0xFFE6EEF8);
  static const Color _muted = Color(0xFFB7C6DA);
  static const Color _warning = Colors.redAccent;

  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeWith(bool value) {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(value);
  }

  void _onSubmit() {
    if (_controller.text.trim() == widget.requiredCode) {
      _closeWith(true);
    } else {
      _closeWith(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final rawWarning = s.translate('signup_doctor_security_warning').trim();
    final warningBody = rawWarning.startsWith('ئاگاداری:')
        ? rawWarning.substring('ئاگاداری:'.length).trim()
        : rawWarning;
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                // Very subtle inner-edge pop for glass depth.
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.06),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.translate('signup_doctor_security_title'),
                    style: const TextStyle(
                      fontFamily: 'KurdishFont',
                      color: _text,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DoctorWarningText(
                    body: warningBody,
                    color: _warning.withValues(alpha: 0.92),
                  ),
                  const SizedBox(height: 18),
                  _DoctorCodeInput(
                    controller: _controller,
                    hintText: s.translate('signup_doctor_security_hint'),
                    textColor: _text,
                    mutedColor: _muted,
                    focusColor: _teal,
                  ),
                  const SizedBox(height: 18),
                  _DoctorDialogActions(
                    cancelText: s.translate('action_cancel'),
                    confirmText: s.translate('signup_doctor_security_confirm'),
                    onCancel: () => _closeWith(false),
                    onConfirm: _onSubmit,
                    mutedColor: _muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorWarningText extends StatelessWidget {
  const _DoctorWarningText({required this.body, required this.color});

  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final warningColor = Colors.orangeAccent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: warningColor.withValues(alpha: 0.28),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_rounded,
                  size: 18,
                  color: warningColor.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'KurdishFont',
                      color: warningColor.withValues(alpha: 0.95),
                      fontSize: 13,
                      height: 1.6,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: 'ئاگاداری: ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: warningColor.withValues(alpha: 1),
                        ),
                      ),
                      TextSpan(
                        text: body,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

class _DoctorCodeInput extends StatelessWidget {
  const _DoctorCodeInput({
    required this.controller,
    required this.hintText,
    required this.textColor,
    required this.mutedColor,
    required this.focusColor,
  });

  final TextEditingController controller;
  final String hintText;
  final Color textColor;
  final Color mutedColor;
  final Color focusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: textColor,
          fontFamily: 'KurdishFont',
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          isDense: false,
          labelText: hintText,
          labelStyle: TextStyle(
            color: mutedColor,
            fontFamily: 'KurdishFont',
            fontSize: 14,
            height: 1.25,
          ),
          floatingLabelStyle: TextStyle(
            color: mutedColor,
            fontFamily: 'KurdishFont',
            fontSize: 12,
            height: 1.15,
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.14),
              width: 0.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.16),
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: focusColor,
              width: 0.5,
            ),
          ),
        ),
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
      ),
    );
  }
}

class _DoctorDialogActions extends StatelessWidget {
  const _DoctorDialogActions({
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    required this.mutedColor,
  });

  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.22), width: 0.5),
              foregroundColor: mutedColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              cancelText,
              style: const TextStyle(
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFF42A5F5)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmText,
                style: const TextStyle(
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
>>>>>>> bf4ff3fc27ca74901219c29d1a5c61dde168d1af
    );
  }
}
