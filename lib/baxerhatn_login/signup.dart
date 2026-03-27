import 'package:flutter/material.dart';
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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();

  UserRole _selectedRole = UserRole.patient;
  bool _isObscured = true;
  String? _doctorCodeError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  bool get _isDoctor => _selectedRole == UserRole.doctor;

  void _onSignUpPressed() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) return;

    if (_isDoctor && _verificationCodeController.text.trim() != _doctorActivationCode) {
      setState(() {
        _doctorCodeError = 'کۆدەکە هەڵەیە، پەیوەندی بە بەڕێوەبەر بکە';
      });
      return;
    }

    setState(() {
      _doctorCodeError = null;
    });

    if (_isDoctor) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            title: const Text(
              'داواکاری نێردرا',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'داواکارییەکەت نێردرا. تکایە چاوەڕێ بکە تا لەلایەن بەڕێوەبەرەوە ئەکاونتەکەت قبوڵ دەکرێت',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'باشە',
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OtpVerificationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'دروستکردنی هەژمار',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'زانیارییەکانی خوارەوە پڕ بکەرەوە بۆ دروستکردنی هەژمارێکی نوێ.',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 22),
                const Text(
                  'ڕۆڵ هەڵبژێرە',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleTile(
                        label: 'نەخۆش',
                        role: UserRole.patient,
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildRoleTile(
                        label: 'پزیشک',
                        role: UserRole.doctor,
                        icon: Icons.medical_services_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildTextField(
                  controller: _fullNameController,
                  hint: 'ناوی تەواو',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'تکایە ناوی تەواو بنووسە';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _emailController,
                  hint: 'ئیمەیڵ',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'تکایە ئیمەیڵ بنووسە';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _phoneController,
                  hint: 'ژمارەی تەلەفۆن',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'تکایە ژمارەی تەلەفۆن بنووسە';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'وشەی نهێنی',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'تکایە وشەی نهێنی بنووسە';
                    }
                    if (value.length < 6) {
                      return 'وشەی نهێنی دەبێت لانیکەم ٦ پیت بێت';
                    }
                    return null;
                  },
                ),
                if (_isDoctor) ...[
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _verificationCodeController,
                    hint: 'کۆدی چالاککردن',
                    icon: Icons.verified_user_outlined,
                    validator: (value) {
                      if (_isDoctor && (value == null || value.trim().isEmpty)) {
                        return 'تکایە کۆدی چالاککردن بنووسە';
                      }
                      return null;
                    },
                  ),
                  if (_doctorCodeError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _doctorCodeError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _onSignUpPressed,
                  child: const Text(
                    'تۆماربوون',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'هەژمارت هەیە؟ ',
                      style: TextStyle(color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'بچۆ ژوورەوە',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTile({
    required String label,
    required UserRole role,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _selectedRole = role;
          _doctorCodeError = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white10,
            width: isSelected ? 1.4 : 1,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? _isObscured : false,
        style: const TextStyle(color: Colors.white),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _isObscured = !_isObscured;
                    });
                  },
                  icon: Icon(
                    _isObscured ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
