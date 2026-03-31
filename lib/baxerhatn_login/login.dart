import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_panel/admin_dashboard.dart';
import '../doctor/doctor_home_screen.dart';
import '../auth/phone_normalization.dart';
import '../auth/doctor_session_cache.dart';
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
  bool _loadingControllerDisposed = false;
  late final AnimationController _loadingPulseController;
  static const Color _text = Color(0xFFE7EEF7);
  static const Color _muted = Color(0xFFAEC0D8);
  /// Matches patient shell sky blue (e.g. `#B3E5FC` family) for loading indicator.
  static const Color _skyBlueLoading = Color(0xFF4FC3F7);

  static const String _kLoginCredentialError =
      'ژمارەی مۆبایل یان وشەی نهێنی هەڵەیە';
  static const String _kPendingApprovalError =
      'هێشتا لەلایەن بەڕێوەبەرەوە قبوڵ نەکراوی، تکایە چاوەڕێ بکە';

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
    _loadingControllerDisposed = true;
    _loadingPulseController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _stopLoadingAnimationSafe() {
    if (!mounted || _loadingControllerDisposed) return;
    if (_loadingPulseController.isAnimating) {
      _loadingPulseController.stop();
    }
    _loadingPulseController.reset();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return S.of(context).translate('validation_password_required');
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
    _showPremiumErrorSnackBar(_kLoginCredentialError);
  }

  void _showPendingApprovalError() =>
      _showPremiumErrorSnackBar(_kPendingApprovalError);

  void _showPremiumErrorSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
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
                        fontFamily: 'KurdishFont',
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

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() => _isLoading = true);
    _loadingPulseController.repeat(reverse: true);
    try {
      final phoneText = normalizePhoneDigits(_phoneController.text.trim()).trim();
      final passwordText = _passwordController.text.trim();

      // Direct Firestore verification: phone + password.
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneText)
          .where('password', isEqualTo: passwordText)
          .get(const GetOptions(source: Source.server));

      if (snap.docs.isEmpty) {
        _showLoginCredentialError();
        return;
      }

      final matchedDocs = snap.docs;
      final doctorMatches = matchedDocs.where((d) {
        final role = (d.data()['role'] ?? '').toString().trim().toLowerCase();
        return role == 'doctor';
      }).toList();
      final adminMatches = matchedDocs.where((d) {
        final role = (d.data()['role'] ?? '').toString().trim().toLowerCase();
        return role == 'admin';
      }).toList();
      final userMatches = matchedDocs.where((d) {
        final role = (d.data()['role'] ?? '').toString().trim().toLowerCase();
        return role.isEmpty || role == 'user' || role == 'patient';
      }).toList();

      if (!mounted) return;
      _stopLoadingAnimationSafe();

      // Role separation: apply approval check ONLY for doctors.
      if (doctorMatches.isNotEmpty) {
        QueryDocumentSnapshot<Map<String, dynamic>>? approvedDoctorDoc;
        for (final doctorDoc in doctorMatches) {
          final m = doctorDoc.data();
          final status = (m['status'] ?? '').toString().toLowerCase().trim();
          final legacyApproved = m['isApproved'] == true;
          if (status == 'approved' || legacyApproved) {
            approvedDoctorDoc = doctorDoc;
            break;
          }
        }
        if (approvedDoctorDoc == null) {
          _showPendingApprovalError();
          return;
        }
        // Auto-sync legacy records: if isApproved=true but status not synced, repair it.
        final approvedDoctorData = approvedDoctorDoc.data();
        final currentStatus =
            (approvedDoctorData['status'] ?? '').toString().toLowerCase().trim();
        if (currentStatus != 'approved') {
          await approvedDoctorDoc.reference.update({
            'status': 'approved',
          });
        }
        await DoctorSessionCache.saveDoctorRefId(approvedDoctorDoc.id);
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const DoctorHomeScreen()),
          (route) => false,
        );
        return;
      }

      if (adminMatches.isNotEmpty) {
        await DoctorSessionCache.clearDoctorRefId();
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AdminDashboard()),
          (route) => false,
        );
        return;
      }

      if (userMatches.isNotEmpty || matchedDocs.isNotEmpty) {
        await DoctorSessionCache.clearDoctorRefId();
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const PatientHomeScreen()),
          (route) => false,
        );
        return;
      }
    } on FirebaseException catch (e) {
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
      if (mounted && !_loadingControllerDisposed) {
        _stopLoadingAnimationSafe();
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                                                builder: (context) =>
                                                    const ForgotPasswordScreen(),
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
                                            style: TextStyle(
                                              color: _muted.withValues(alpha: 0.9),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute<void>(
                                                  builder: (context) =>
                                                      const SignUpScreen(),
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
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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

  /// Glassmorphic loading card: centered, text-free professional loader.
  Widget _buildLoginLoadingGlassCard() {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: _skyBlueLoading,
                strokeWidth: 2,
              ),
            ),
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
