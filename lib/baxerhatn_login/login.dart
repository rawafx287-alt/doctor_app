import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_navigation.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import 'forgot_password.dart';
import 'signup.dart';

String _authErrorMessage(BuildContext context, String code) {
  final s = S.of(context);
  switch (code) {
    case 'invalid-email':
      return s.translate('auth_err_invalid_email');
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return s.translate('auth_err_wrong_credential');
    case 'user-disabled':
      return s.translate('auth_err_user_disabled');
    case 'too-many-requests':
      return s.translate('auth_err_too_many_requests');
    case 'network-request-failed':
      return s.translate('auth_err_network');
    default:
      return s.translate('auth_err_generic');
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscured = true;
  bool _isLoading = false;
  static const Color _text = Color(0xFFE7EEF7);
  static const Color _muted = Color(0xFFAEC0D8);

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return S.of(context).translate('validation_password_required');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return S.of(context).translate('validation_phone_required');
    final digitsOnly = RegExp(r'^[0-9]+$');
    if (!digitsOnly.hasMatch(v)) {
      return S.of(context).translate('validation_phone_digits_only');
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text;
      final byPhone = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (byPhone.docs.isEmpty) {
        throw FirebaseAuthException(code: 'user-not-found');
      }
      final data = byPhone.docs.first.data();
      final email = (data['email'] ?? '').toString().trim();
      if (email.isEmpty) {
        throw FirebaseAuthException(code: 'invalid-email');
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-null');

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              S.of(context).translate('account_not_found'),
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
        return;
      }

      final userData = doc.data() ?? {};
      if (!mounted) return;
      await navigateAfterLogin(context, userData);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = _authErrorMessage(context, e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontFamily: 'KurdishFont')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_generic'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: widget.showBackButton,
            leading: widget.showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: _text),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                  )
                : null,
          ),
          body: Directionality(
            textDirection: AppLocaleScope.of(context).textDirection,
            child: Stack(
              children: [
                _buildBackground(),
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildHeader(),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: _buildGlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildInputField(
                                controller: _phoneController,
                                icon: Icons.phone_iphone_outlined,
                                label: S.of(context).translate('signup_mobile'),
                                keyboardType: TextInputType.phone,
                                validator: _validatePhone,
                              ),
                              const SizedBox(height: 14),
                              _buildInputField(
                                controller: _passwordController,
                                icon: Icons.lock_outline_rounded,
                                label: S.of(context).translate('hint_password'),
                                validator: _validatePassword,
                                isPassword: true,
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) => const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    S.of(context).translate('forgot_password'),
                                    style: TextStyle(
                                      color: _muted.withValues(alpha: 0.95),
                                      fontFamily: 'KurdishFont',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildLoginButton(),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    S.of(context).translate('no_account'),
                                    style: TextStyle(color: _muted.withValues(alpha: 0.9)),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (context) => const SignUpScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      S.of(context).translate('sign_up'),
                                      style: const TextStyle(
                                        color: Color(0xFFCFD9EA),
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'KurdishFont',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading) ...[
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.45),
          ),
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ],
      ],
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08152F), Color(0xFF020305)],
        ),
      ),
      child: Stack(
        children: const [
          _BgBlob(alignment: Alignment(-1.0, -0.85), size: 220, color: Color(0xFF1DE9B6)),
          _BgBlob(alignment: Alignment(0.95, -0.45), size: 210, color: Color(0xFF40C4FF)),
          _BgBlob(alignment: Alignment(0.1, 0.95), size: 240, color: Color(0xFF7C4DFF)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 6),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: const Icon(
            Icons.local_hospital_outlined,
            size: 42,
            color: Color(0xFFD7E6F8),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          S.of(context).translate('login'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _text,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            fontFamily: 'KurdishFont',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.of(context).translate('login_subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _muted.withValues(alpha: 0.9),
            fontSize: 14,
            fontFamily: 'KurdishFont',
          ),
        ),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: isPassword ? _isObscured : false,
      style: const TextStyle(color: _text, fontFamily: 'KurdishFont'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted, fontSize: 14),
        hintText: label,
        hintStyle: const TextStyle(color: _muted, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFE4EEF9), size: 21),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility_off : Icons.visibility,
                  color: _muted,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1.1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildLoginButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF26C6DA), Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isLoading ? null : _handleLogin,
          child: SizedBox(
            height: 54,
            child: Center(
              child: Text(
                S.of(context).translate('sign_in'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'KurdishFont',
                  color: Colors.white.withValues(alpha: _isLoading ? 0.65 : 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BgBlob extends StatelessWidget {
  const _BgBlob({
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
          imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
