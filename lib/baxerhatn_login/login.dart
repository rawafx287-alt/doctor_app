import 'package:flutter/material.dart';
import '../main.dart'; // بۆ ئەوەی دوای لۆگین بچێت بۆ شاشەی سەرەکی
import 'forgot_password.dart';
import 'signup.dart';
import '../admin_panel/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscured = true; // بۆ شاردنەوە و پیشاندانی وشەی نهێنی
  static const String _adminEmail = 'admin@nur.com';
  static const String _adminPassword = 'admin123';

  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'بچۆ ژوورەوە',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'تکایە زانیارییەکانت بنووسە بۆ بەردەوامبوون',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 50),

              // خانەی ژمارەی مۆبایل
              _buildTextField(
                controller: _contactController,
                hint: 'ئیمەیڵ یان ژمارەی مۆبایل',
                icon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // خانەی وشەی نهێنی
              _buildTextField(
                controller: _passwordController,
                hint: 'وشەی نهێنی',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'وشەی نهێنیت لەبیرچووە؟',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // دوگمەی چوونە ژوورەوە
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 5,
                ),
                onPressed: () {
                  final contact = _contactController.text.trim();
                  final password = _passwordController.text;
                  if (contact == _adminEmail && password == _adminPassword) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminDashboard()),
                      (route) => false,
                    );
                    return;
                  }
                  // گواستنەوە بۆ شاشەی سەرەکی و سڕینەوەی لاپەڕەکانی پێشوو
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'چوونە ژوورەوە',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              
              const SizedBox(height: 25),
              
              // دروستکردنی هەژمار
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('هەژمارت نییە؟ ', style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'هەژمار دروست بکە',
                      style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ویجێتێکی یاریدەدەر بۆ دروستکردنی TextField بە شێوەیەکی ڕێک
  Widget _buildTextField({
    TextEditingController? controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscured : false,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isObscured ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscured = !_isObscured;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}