import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('پڕۆفایلی من', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),
              
              // --- بەشی وێنەی پڕۆفایل ---
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2),
                      ),
                      child: const CircleAvatar(
                        radius: 60,
                        backgroundColor: Color(0xFF1D1E33),
                        child: Icon(Icons.person, size: 80, color: Colors.white),
                      ),
                    ),
                    // لێرەدا کێشەکە هەبوو، چاککرا بۆ Positioned
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              const Text('بەکارهێنەر', 
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('0750 XXX XX XX', style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 40),
              
              // --- لیستەکان ---
              _profileItem(Icons.person_outline, 'زانیارییە کەسییەکان'),
              _profileItem(Icons.history, 'مێژووی نۆرەکان'),
              _profileItem(Icons.notifications_none, 'ئاگادارکردنەوەکان'),
              _profileItem(Icons.language, 'گۆڕینی زمان'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Divider(color: Colors.white10),
              ),
              _profileItem(Icons.logout, 'چوونە دەرەوە', isLogout: true),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ویجێتێکی یاریدەدەر بۆ دروستکردنی لیستەکان بە یەک شێوە
  Widget _profileItem(IconData icon, String title, {bool isLogout = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: isLogout ? Colors.redAccent : Colors.blueAccent),
        title: Text(title, 
          style: TextStyle(color: isLogout ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
        onTap: () {
          // لێرەدا ئەکشنەکان دادەنرێت
        },
      ),
    );
  }
}