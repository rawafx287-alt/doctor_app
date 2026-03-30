import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_navigation.dart';
import '../auth/phone_auth_config.dart';
import '../auth/phone_normalization.dart';
import '../locale/app_localizations.dart';
import '../patient/patient_home_screen.dart';
import 'forgot_password.dart';
import 'signup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscured = true;
  bool _isLoading = false;
  late final AnimationController _loadingPulseController;
  static const Color _text = Color(0xFFE7EEF7);
  static const Color _muted = Color(0xFFAEC0D8);
  /// Matches patient shell sky blue (e.g. `#B3E5FC` family) for loading indicator.
  static const Color _skyBlueLoading = Color(0xFF4FC3F7);

  static const String _kLoginCredentialError =
      'ژمارەی مۆبایل یان وشەی نهێنی هەڵەیە';

  @override
  void initState() {
    super.initState();
    _loadingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _loadingPulseController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return S.of(context).translate('validation_password_required');
    }
    return null;
  }

  /// Firestore may store `phone` as [String] or [int] depending on legacy data.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _lookupUserByPhone(
    String phoneDigits,
  ) async {
    final col = FirebaseFirestore.instance.collection('users');
    var snap = await col
        .where('phone', isEqualTo: phoneDigits)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    final asInt = int.tryParse(phoneDigits);
    if (asInt != null) {
      snap = await col.where('phone', isEqualTo: asInt).limit(1).get();
      if (snap.docs.isNotEmpty) return snap.docs.first;
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final v = normalizePhoneDigits(value ?? '');
    if (v.isEmpty) return S.of(context).translate('validation_phone_required');
    final digitsOnly = RegExp(r'^[0-9]+$');
    if (!digitsOnly.hasMatch(v)) {
      return S.of(context).translate('validation_phone_digits_only');
    }
    if (v.length != 11) {
      return S.of(context).translate('validation_phone_must_be_11');
    }
    return null;
  }

  void _showLoginCredentialError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _kLoginCredentialError,
          style: const TextStyle(fontFamily: 'KurdishFont'),
        ),
      ),
    );
  }

  static String _passwordStringFromFirestore(dynamic raw) {
    if (raw == null) return '';
    return raw.toString().trim();
  }

  /// Replaces the stack so home appears immediately (AuthGate stream can lag one frame).
  Future<void> _navigateToHomeAfterSignIn(User user) async {
    if (!mounted) return;
    final email = user.email ?? '';
    final Widget home;
    if (email.endsWith('@$kPhoneAuthEmailDomain')) {
      home = const PatientHomeScreen();
    } else {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      final roleHome = homeWidgetForUserData(snap.data() ?? {});
      if (roleHome == null) {
        await FirebaseAuth.instance.signOut();
        if (mounted) _showLoginCredentialError();
        return;
      }
      home = roleHome;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => home),
      (route) => false,
    );
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    _loadingPulseController.repeat(reverse: true);
    try {
      final phone = normalizePhoneDigits(_phoneController.text);
      final password = _passwordController.text.trim();

      Map<String, dynamic>? phoneDocData;
      var firestoreUsersReadable = false;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(phone)
            .get(const GetOptions(source: Source.server));
        firestoreUsersReadable = true;
        if (snap.exists) {
          phoneDocData = snap.data();
        }
      } on FirebaseException catch (e) {
        debugPrint('[Login] users/$phone read: code=${e.code}');
        if (e.code == 'permission-denied') {
          firestoreUsersReadable = false;
          phoneDocData = null;
        } else {
          rethrow;
        }
      }

      if (firestoreUsersReadable) {
        if (phoneDocData == null) {
          debugPrint('[Login] No Firestore doc users/$phone');
          _showLoginCredentialError();
          return;
        }
        final storedPw = _passwordStringFromFirestore(phoneDocData['password']);
        if (storedPw != password) {
          _showLoginCredentialError();
          return;
        }
      }

      try {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: phoneAuthEmail(phone),
          password: password,
        );
        final signedUser = cred.user;
        if (signedUser != null) {
          await _navigateToHomeAfterSignIn(signedUser);
        }
        return;
      } on FirebaseAuthException catch (e) {
        // ignore: avoid_print
        print(
          '[Login] FirebaseAuthException: code=${e.code} message=${e.message}',
        );
        debugPrint(
          '[Login] FirebaseAuthException: code=${e.code} message=${e.message}',
        );

        if (firestoreUsersReadable) {
          _showLoginCredentialError();
          return;
        }

        final legacy = await _lookupUserByPhone(phone);
        if (legacy == null) {
          debugPrint(
            '[Login] No Firestore profile for phone=$phone (doc or query)',
          );
          _showLoginCredentialError();
          return;
        }
        final legacyData = legacy.data();
        final email = (legacyData['email'] ?? '').toString().trim();
        if (email.isEmpty) {
          _showLoginCredentialError();
          return;
        }
        try {
          final credential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          final user = credential.user;
          if (user != null && user.uid != legacy.id) {
            debugPrint(
              '[Login] UID mismatch: Auth uid=${user.uid} vs profile id=${legacy.id}',
            );
            await FirebaseAuth.instance.signOut();
            _showLoginCredentialError();
          } else if (user != null) {
            await _navigateToHomeAfterSignIn(user);
          }
        } on FirebaseAuthException catch (e2) {
          // ignore: avoid_print
          print(
            '[Login] FirebaseAuthException (legacy): code=${e2.code} message=${e2.message}',
          );
          debugPrint(
            '[Login] FirebaseAuthException (legacy): code=${e2.code} message=${e2.message}',
          );
          _showLoginCredentialError();
        }
      }
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print(
        '[Login] FirebaseException: code=${e.code} message=${e.message}',
      );
      debugPrint('[Login] FirebaseException: code=${e.code} message=${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${S.of(context).translate('error_generic')} [${e.code}]',
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('[Login] Error: $e');
      debugPrint('[Login] Error: $e');
      debugPrint('[Login] Stack: $stackTrace');
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
      _loadingPulseController.stop();
      _loadingPulseController.reset();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false,
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
            textDirection: TextDirection.rtl,
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
                                maxLength: 11,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
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
            color: Colors.black.withValues(alpha: 0.38),
          ),
          Center(child: _buildLoginLoadingGlassCard()),
        ],
      ],
    );
  }

  /// Glassmorphic loading card: sky-blue progress + pulsing Kurdish “please wait” text.
  Widget _buildLoginLoadingGlassCard() {
    final pulse = CurvedAnimation(
      parent: _loadingPulseController,
      curve: Curves.easeInOut,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: _skyBlueLoading,
                  strokeWidth: 3.2,
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: Tween<double>(begin: 0.62, end: 1.0).animate(pulse),
                child: Text(
                  S.of(context).translate('splash_loading'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _text.withValues(alpha: 0.95),
                    fontFamily: 'KurdishFont',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
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
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: isPassword ? _isObscured : false,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: _text, fontFamily: 'KurdishFont'),
      decoration: InputDecoration(
        counterText: maxLength != null ? '' : null,
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
          onTap: _isLoading
              ? null
              : () async {
                  await HapticFeedback.lightImpact();
                  if (!mounted) return;
                  await _handleLogin();
                },
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
