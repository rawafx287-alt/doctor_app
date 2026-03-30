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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscured = true;
  bool _isLoading = false;

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.com$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final s = S.of(context);
    final v = value?.trim() ?? '';
    if (v.isEmpty) return s.translate('validation_email_required');
    if (!_emailRegex.hasMatch(v)) return s.translate('validation_email_invalid');
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return S.of(context).translate('validation_password_required');
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      // Values from the email / password fields above (چوونە ژوورەوە).
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-null');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
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

      final data = doc.data() ?? {};
      if (!mounted) return;
      await navigateAfterLogin(context, data);
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
          backgroundColor: const Color(0xFF0A0E21),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: widget.showBackButton,
            leading: widget.showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                  )
                : null,
          ),
          body: Directionality(
            textDirection: AppLocaleScope.of(context).textDirection,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const SizedBox(height: 20),
                Text(
                  S.of(context).translate('login'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  S.of(context).translate('login_subtitle'),
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 50),
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
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
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 5,
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: Text(
                    S.of(context).translate('sign_in'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(
                        alpha: _isLoading ? 0.65 : 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      S.of(context).translate('no_account'),
                      style: const TextStyle(color: Colors.grey),
                    ),
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
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isLoading) ...[
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.45),
          ),
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: Colors.white),
        validator: _validateEmail,
        decoration: InputDecoration(
          labelText: S.of(context).translate('hint_email_login'),
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          hintText: S.of(context).translate('hint_email_login'),
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.email_outlined,
              color: Colors.blueAccent, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _isObscured,
        validator: _validatePassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: S.of(context).translate('hint_password'),
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          hintText: S.of(context).translate('hint_password'),
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: Colors.blueAccent, size: 22),
          suffixIcon: IconButton(
            icon: Icon(
              _isObscured ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () => setState(() => _isObscured = !_isObscured),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
