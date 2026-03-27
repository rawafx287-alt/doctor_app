import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login.dart';
import 'otp_verification.dart';

enum UserRole { patient, doctor }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const String _doctorActivationCode = 'NUR77';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();

  UserRole _selectedRole = UserRole.patient;
  bool _isObscured = true;
  String? _doctorCodeError;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _passwordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  bool get _isDoctor => _selectedRole == UserRole.doctor;

  Future<void> _onSignUpPressed() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) return;

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

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // 1. دروستکردنی ئەکاونت لە Authentication
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception('User ID is null');

      // 2. خەزنکردنی زانیارییەکان لە Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _isDoctor ? 'Doctor' : 'Patient',
        'specialty': _isDoctor ? _specialtyController.text.trim() : '',
        'isApproved': _isDoctor ? false : true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      if (_isDoctor) {
        _showSuccessDialog();
        await FirebaseAuth.instance.signOut();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OtpVerificationScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FIREBASE AUTH ERROR -> code: ${e.code}, message: ${e.message}, email: ${e.email}, credential: ${e.credential}',
      );
      String msg = 'هەڵەیەک ڕوویدا';
      if (e.code == 'email-already-in-use')
        msg = 'ئەم ئیمەیڵە پێشتر بەکارهاتووە';
      if (e.code == 'invalid-email') msg = 'ئیمەیڵەکە هەڵەیە';
      if (e.code == 'weak-password') msg = 'وشەی نهێنی لاوازە (لانیکەم ٦ پیت)';
      if (e.code == 'network-request-failed') msg = 'ئینتەرنێتەکەت تاقیکەرەوە';

      _showSnackBar(msg + " (${e.code})");
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
        textDirection: TextDirection.rtl,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
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
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleTile(
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
                      ),
                    ),
                  ],
                ),

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
                ],

                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _isLoading ? null : _onSignUpPressed,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'تۆماربوون',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _isObscured,
      keyboardType: keyboardType,
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
    );
  }
}
