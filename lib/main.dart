import 'package:flutter/material.dart';
// هاوردەکردنی لاپەڕە نوێیەکان لە فۆڵدەری baxerhatn_login
import 'baxerhatn_login/welcome.dart';
// هاوردەکردنی لاپەڕەکانی ناو فۆڵدەری nawarok
import 'nawarok/listidoctorakan.dart';
import 'nawarok/norakanimn.dart';
import 'nawarok/notifications.dart';
import 'nawarok/profile.dart';

void main() {
  runApp(const DoctorApp());
}

class DoctorApp extends StatelessWidget {
  const DoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور بۆ پزیشکان',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        primaryColor: Colors.blueAccent,
      ),
      // ئەپەکە لێرەوە دەستپێدەکات
      home: const WelcomeScreen(), 
    );
  }
}

// ئەم کڵاسە بەرپرسە لە بەڕێوەبردنی شریتی خوارەوە (Bottom Navigation)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ListiDoctorakanScreen(),
    const NorekaniMinScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFF1D1E33),
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'سەرەتا'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'نۆرەکانم'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'ئاگاداری'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'پڕۆفایل'),
          ],
        ),
      ),
    );
  }
}