import 'package:flutter/material.dart';
import 'login.dart'; // چونکە هەردووکیان لە یەک فۆڵدەرن

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ١. وێنەی پشتێنە (Background)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                    'https://img.freepik.com/free-photo/doctor-offering-medical-teleconsultation_23-2149329007.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // ٢. داپۆشینی وێنەکە بە ڕەنگی تاریک (Overlay)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  const Color(0xFF0A0E21).withOpacity(0.95),
                ],
              ),
            ),
          ),
          
          // ٣. ناوەڕۆکی لاپەڕەکە
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تەندروستیت\nلای ئێمە گرنگە',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'باشترین پزیشکەکان لێرەن، بە ئاسانی نۆرە بگرە و کاتەکانت ڕێکبخە.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),
                
                // دوگمەی دەستپێکردن
                TweenAnimationBuilder(
                  duration: const Duration(seconds: 1),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: child,
                    );
                  },
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 10,
                      shadowColor: Colors.blueAccent.withOpacity(0.5),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'دەستپێبکە',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}