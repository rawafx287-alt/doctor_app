import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_navigation.dart';
import 'forgot_password.dart';
import 'signup.dart';
import '../app_rtl.dart';

String _kurdishAuthErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'ئیمەیڵەکە دروست نییە';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'ئیمەیڵ یان وشەی نهێنی هەڵەیە، تکایە دووبارە هەوڵ بدەرەوە';
    case 'user-disabled':
      return 'ئەم هەژمارە ناچالاک کراوە';
    case 'too-many-requests':
      return 'هەوڵی زۆر، دواتر تاقی بکەرەوە';
    case 'network-request-failed':
      return 'پەیوەندی ئینتەرنێتەکەت تاقیکەرەوە';
    default:
      return 'هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە';
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showBackButton = true});

  /// When false (e.g. root [AuthGate]), hides back — nothing to pop.
  final bool showBackButton;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscured = true; // بۆ شاردنەوە و پیشاندانی وشەی نهێنی
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

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
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Directionality(
        textDirection: kRtlTextDirection,
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
                onPressed: _isLoading ? null : _handleLogin,
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
  Future<void> _handleLogin() async {
    final emailOrPhone = _contactController.text.trim();
    final password = _passwordController.text.trim();
    if (emailOrPhone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تکایە زانیارییەکان پڕ بکەرەوە',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailOrPhone,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw FirebaseAuthException(code: 'user-null');

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هەژمار نەدۆزرایەوە', style: TextStyle(fontFamily: 'KurdishFont')),
          ),
        );
        return;
      }

      final data = doc.data() ?? {};
      if (!mounted) return;
      await navigateAfterLogin(context, data);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = _kurdishAuthErrorMessage(e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontFamily: 'KurdishFont')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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