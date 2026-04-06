import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final FocusNode _firstNameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

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
  }

  @override
  void dispose() {
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _addressFocusNode.dispose();
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

  static const String _kPhoneMustBe11Digits =
      'پێویستە ژمارەی مۆبایل ١١ ژمارە بێت';
  static const String _kDuplicateAccountMessage =
      'ئەم ژمارەیە یان ئیمەیڵە پێشتر بەکارهاتووە';

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

  /// Returns `true` for success, `false` for wrong code, `null` for cancel.
  Future<bool?> _showDoctorSecurityDialog() async {
    if (!mounted) return null;
    final result = await showDialog<bool?>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => _DoctorSecurityDialogShell(
        child: _DoctorSecurityCodeDialog(requiredCode: _doctorActivationCode),
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

  void _goDoctorPendingSuccess() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegistrationSuccessPage(
              customMessage:
                  'تکایە چاوەڕێ بکە تا لەلایەن بەڕێوبەرەوە قبوڵ دەکرێیت',
            ),
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
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final duplicate = await _hasDuplicatePhoneOrEmail();
      if (duplicate) {
        if (mounted) _showSnackBar(_kDuplicateAccountMessage);
        return;
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

  /// Patient registration uses Firebase Auth synthetic phone-email login.
  /// Firestore document is saved under **uid** (not phone number).
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
        debugPrint('[SignUp] createUser: code=${e.code} message=${e.message}');
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
            final wrongPw =
                e2.code == 'wrong-password' || e2.code == 'invalid-credential';
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

      final uid = userCred.user?.uid ?? '';
      if (uid.isEmpty) {
        if (!mounted) return;
        _showSnackBar(S.of(context).translate('signup_err_generic'));
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(profilePayload, SetOptions(merge: true));
      profileSavedToFirestore = true;

      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _goRegistrationSuccess();
    } on FirebaseException catch (e) {
      debugPrint(
        '[SignUp] FirebaseException (Firestore): code=${e.code} message=${e.message}',
      );
      if (!linkedExistingAuthUser) {
        await _rollbackNewAuthUser(userCred?.user);
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
        'password': password,
        'address': _addressController.text.trim(),
        'role': 'Doctor',
        'specialty': (_doctorSpecialty ?? '').trim(),
        'status': 'pending',
        'isApproved': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      profileSavedToFirestore = true;

      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _goDoctorPendingSuccess();
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
    } catch (e) {
      debugPrint('[SignUp] Unexpected error: $e');
      if (!profileSavedToFirestore) {
        await _rollbackNewAuthUser(userCred?.user);
      }
      if (!mounted) return;
      _showSnackBar('${S.of(context).translate('signup_err_generic')}: $e');
    }
  }

  Future<bool> _hasDuplicatePhoneOrEmail() async {
    final users = FirebaseFirestore.instance.collection('users');
    final phone = normalizePhoneDigits(_phoneController.text);
    final emailRaw = _emailController.text.trim();
    final emailLower = emailRaw.toLowerCase();

    // 1) Phone in field (string / int legacy).
    var byPhone = await users.where('phone', isEqualTo: phone).limit(1).get();
    if (byPhone.docs.isNotEmpty) return true;
    final phoneInt = int.tryParse(phone);
    if (phoneInt != null) {
      byPhone = await users.where('phone', isEqualTo: phoneInt).limit(1).get();
      if (byPhone.docs.isNotEmpty) return true;
    }

    // 3) Email only when user entered one.
    if (emailRaw.isNotEmpty) {
      final byEmailExact = await users
          .where('email', isEqualTo: emailRaw)
          .limit(1)
          .get();
      if (byEmailExact.docs.isNotEmpty) return true;
      final byEmailLower = await users
          .where('email', isEqualTo: emailLower)
          .limit(1)
          .get();
      if (byEmailLower.docs.isNotEmpty) return true;
    }

    return false;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFFEBEE).withValues(alpha: 0.32),
                    const Color(0xFFC62828).withValues(alpha: 0.22),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFF8A80).withValues(alpha: 0.55),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFFCDD2),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontFamily: 'NRT',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFEBEE),
                        height: 1.35,
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: _SignUpBackground()),
          ),
          Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: Colors.transparent,
            appBar: _SignUpAppBar(onBack: () => Navigator.pop(context)),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: RepaintBoundary(
                child: Form(
                  key: _formKey,
                  // Validate on submit / focus loss — avoids work every keystroke.
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // No ShaderMask — gradient shaders repaint heavily during keyboard animation.
                      Text(
                        S.of(context).translate('sign_up_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'NRT',
                          color: Color(0xFFF1F5F9),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.85,
                          height: 1.25,
                          shadows: [
                            Shadow(
                              color: Color(0x4000BCD4),
                              blurRadius: 12,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        S.of(context).translate('sign_up_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NRT',
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleTile(
                              title: S.of(context).translate('role_patient'),
                              subtitle: S
                                  .of(context)
                                  .translate('role_patient_short'),
                              role: UserRole.patient,
                              icon: Icons.person_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRoleTile(
                              title: S.of(context).translate('role_doctor'),
                              subtitle: S
                                  .of(context)
                                  .translate('role_doctor_short'),
                              role: UserRole.doctor,
                              icon: Icons.medical_services_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _buildTextField(
                        controller: _firstNameController,
                        focusNode: _firstNameFocusNode,
                        nextFocusNode: _lastNameFocusNode,
                        label: S.of(context).translate('signup_first_name'),
                        icon: Icons.badge_outlined,
                        validator: _validateName,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _lastNameController,
                        focusNode: _lastNameFocusNode,
                        nextFocusNode: _phoneFocusNode,
                        label: S.of(context).translate('signup_last_name'),
                        icon: Icons.person_outline_rounded,
                        validator: _validateName,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        nextFocusNode: _emailFocusNode,
                        label: S.of(context).translate('signup_mobile'),
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 11,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        nextFocusNode: _isDoctor ? null : _passwordFocusNode,
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
                          onChanged: (v) =>
                              setState(() => _doctorSpecialty = v),
                          validator: (v) => v == null || v.isEmpty
                              ? S
                                    .of(context)
                                    .translate('validation_specialty_required')
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _buildTextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        nextFocusNode: _confirmPasswordFocusNode,
                        label: S.of(context).translate('password_hint_signup'),
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        isConfirmPassword: false,
                        englishPasswordOnly: true,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocusNode,
                        nextFocusNode: _addressFocusNode,
                        label: S.of(context).translate('password_confirm'),
                        icon: Icons.lock_person_outlined,
                        isPassword: true,
                        isConfirmPassword: true,
                        englishPasswordOnly: true,
                        validator: _validateConfirmPassword,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        key: _addressFieldKey,
                        controller: _addressController,
                        focusNode: _addressFocusNode,
                        label: S.of(context).translate('signup_address'),
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                        keyboardType: TextInputType.streetAddress,
                        validator: _validateAddress,
                      ),
                      const SizedBox(height: 28),
                      _buildRegisterButton(),
                    ],
                  ),
                ),
              ),
            ),
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
                        fontFamily: 'NRT',
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
        fontFamily: 'NRT',
        fontSize: 14,
        height: 1.25,
      ),
      floatingLabelStyle: const TextStyle(
        color: _muted,
        fontFamily: 'NRT',
        fontSize: 12,
        height: 1.15,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: _muted.withValues(alpha: 0.65),
        fontFamily: 'NRT',
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
        child: Container(
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
              Icon(icon, color: isSelected ? selectedColor : _muted, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? _text : _muted.withValues(alpha: 0.95),
                  fontFamily: 'NRT',
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
    Key? key,
    required TextEditingController controller,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isConfirmPassword = false,
    bool englishPasswordOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    final obscure = isConfirmPassword ? _obscureConfirm : _obscurePassword;

    final formatters = <TextInputFormatter>[
      if (englishPasswordOnly)
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9!@#$%^&*()_+-=]')),
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
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
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
    final decoration =
        (maxLength != null
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
            // Avoid per-field BackdropFilter (expensive during keyboard animations).
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
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
          textInputAction: nextFocusNode != null
              ? TextInputAction.next
              : (isPassword ? TextInputAction.done : TextInputAction.done),
          onFieldSubmitted: (_) {
            if (nextFocusNode != null) {
              FocusScope.of(context).requestFocus(nextFocusNode);
            } else {
              FocusScope.of(context).unfocus();
            }
          },
          style: const TextStyle(
            color: _text,
            fontFamily: 'NRT',
            fontWeight: FontWeight.w600,
          ),
          decoration: decoration,
          validator:
              validator ??
              (value) => value == null || value.trim().isEmpty
                  ? S.of(context).translate('validation_field_required')
                  : null,
        ),
      ],
    );
  }
}

/// Stable app bar: avoids rebuilding heavy [Scaffold] chrome logic inline with the form.
class _SignUpAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SignUpAppBar({required this.onBack});

  final VoidCallback onBack;

  static const Color _fg = Color(0xFFD9E2EC);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent.withValues(alpha: 0.2),
      elevation: 0,
      foregroundColor: _fg,
      leading: IconButton(
        icon: const Icon(Icons.arrow_forward_ios_rounded),
        onPressed: onBack,
      ),
    );
  }
}

class _SignUpBackground extends StatelessWidget {
  const _SignUpBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1330), Color(0xFF05070E), Color(0xFF020306)],
        ),
      ),
      child: const Stack(
        children: [
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
    // No ImageFilter blur — large blurs are expensive during keyboard/view inset changes.
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.35, 1.0],
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
                  filter: ImageFilter.blur(sigmaX: 5 * t, sigmaY: 5 * t),
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
                      fontFamily: 'NRT',
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
                      fontFamily: 'NRT',
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
          fontFamily: 'NRT',
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          isDense: false,
          labelText: hintText,
          labelStyle: TextStyle(
            color: mutedColor,
            fontFamily: 'NRT',
            fontSize: 14,
            height: 1.25,
          ),
          floatingLabelStyle: TextStyle(
            color: mutedColor,
            fontFamily: 'NRT',
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
            borderSide: BorderSide(color: focusColor, width: 0.5),
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
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.22),
                width: 0.5,
              ),
              foregroundColor: mutedColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              cancelText,
              style: const TextStyle(
                fontFamily: 'NRT',
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
                  fontFamily: 'NRT',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
