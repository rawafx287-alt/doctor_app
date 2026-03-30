import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../specialty_categories.dart';

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
  final TextEditingController _confirmPasswordController = TextEditingController();

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
    final v = value ?? '';
    if (v.isEmpty) return s.translate('validation_password_required');
    if (v != _passwordController.text) {
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

  String? _validatePhone(String? value) {
    final s = S.of(context);
    final v = value?.trim() ?? '';
    if (v.isEmpty) return s.translate('validation_phone_required');
    if (!_digitsOnly.hasMatch(v)) {
      return s.translate('validation_phone_digits_only');
    }
    return null;
  }

  String? _validateAddress(String? value) {
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
        child: _DoctorSecurityCodeDialog(
          requiredCode: _doctorActivationCode,
        ),
      ),
    );
    if (!mounted) return null;
    return result;
  }

  Future<void> _registerWithFirebase() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCred.user;
      if (user == null) throw Exception('User ID is null');

      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final fullName = '$first $last'.trim();
      final phone = _phoneController.text.trim();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': first,
        'lastName': last,
        'fullName': fullName.isEmpty ? first : fullName,
        'email': email,
        'phone': phone,
        'address': _addressController.text.trim(),
        'role': _isDoctor ? 'Doctor' : 'Patient',
        'specialty': _isDoctor ? (_doctorSpecialty ?? '').trim() : '',
        'isApproved': _isDoctor ? false : true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      // Signed in; defer pop until after this frame so routes/InheritedWidgets settle.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.microtask(() {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
        });
      });
    } on FirebaseAuthException catch (e) {
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
      if (!mounted) return;
      _showSnackBar(
        '${S.of(context).translate('signup_err_firestore')} (${e.code})',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('${S.of(context).translate('signup_err_generic')}: $e');
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
        child: Stack(
          children: [
            _buildBackground(),
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleTile(
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
                      ),
                    ),
                  ],
                ),
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _confirmPasswordController,
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
          onTap: _isLoading ? null : _onSignUpPressed,
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
  }) {
    return InputDecoration(
      alignLabelWithHint: alignLabelWithHint,
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: _muted, fontFamily: 'KurdishFont'),
      hintStyle: TextStyle(
        color: _muted.withValues(alpha: 0.65),
        fontFamily: 'KurdishFont',
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.10),
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
        ),
      ),
    );
  }

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
        ),
      ...?inputFormatters,
    ];

    final baseDecoration = _fieldDecoration(
      alignLabelWithHint: maxLines > 1,
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
    final decoration = maxLength != null
        ? baseDecoration.copyWith(counterText: '')
        : baseDecoration;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: TextFormField(
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
  static const Color _surface = Color(0xFF1D1E33);
  static const Color _bg = Color(0xFF0A0E21);
  static const Color _teal = Color(0xFF42A5F5);
  static const Color _text = Color(0xFFD9E2EC);
  static const Color _muted = Color(0xFF829AB1);

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
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: AlertDialog(
        backgroundColor: _surface,
        title: Text(
          s.translate('signup_doctor_security_title'),
          style: const TextStyle(
            fontFamily: 'KurdishFont',
            color: _text,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.translate('signup_doctor_security_warning'),
                style: TextStyle(
                  fontFamily: 'KurdishFont',
                  color: _muted.withValues(alpha: 0.95),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                style: const TextStyle(
                  color: _text,
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: s.translate('signup_doctor_security_hint'),
                  labelStyle: const TextStyle(
                    color: _muted,
                    fontFamily: 'KurdishFont',
                  ),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: _teal,
                      width: 1.5,
                    ),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _closeWith(false),
            child: Text(
              s.translate('action_cancel'),
              style: const TextStyle(
                color: _muted,
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _onSubmit,
            child: Text(
              s.translate('signup_doctor_security_confirm'),
              style: const TextStyle(
                color: _teal,
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
