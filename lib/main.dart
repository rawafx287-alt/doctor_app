import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// هاوردەکردنی لاپەڕە نوێیەکان لە فۆڵدەری baxerhatn_login
import 'baxerhatn_login/welcome.dart';
// هاوردەکردنی لاپەڕەکانی ناو فۆڵدەری nawarok
import 'nawarok/listidoctorakan.dart';
import 'nawarok/norakanimn.dart';
import 'nawarok/notifications.dart';
import 'nawarok/profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const DoctorApp());
}

class DoctorApp extends StatelessWidget {
  const DoctorApp({super.key});

  static const Color _deepNavy = Color(0xFF102A43);
  static const Color _slateBlue = Color(0xFF243B53);
  static const Color _clinicalTeal = Color(0xFF2CB1BC);
  static const Color _coolGray = Color(0xFF829AB1);
  static const Color _softText = Color(0xFFD9E2EC);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور بۆ پزیشکان',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _deepNavy,
        primaryColor: _clinicalTeal,
        colorScheme: const ColorScheme.dark(
          primary: _clinicalTeal,
          secondary: Color(0xFF55DDE0),
          surface: _slateBlue,
          onPrimary: _softText,
          onSecondary: _softText,
          onSurface: _softText,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _slateBlue,
          foregroundColor: _softText,
          elevation: 0,
        ),
        cardColor: _slateBlue,
        dividerColor: Color(0xFF334E68),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: _softText),
          bodyMedium: TextStyle(color: _softText),
          titleLarge: TextStyle(color: _softText, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(color: _softText),
        ),
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
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: DoctorApp._coolGray.withOpacity(0.35),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: DoctorApp._slateBlue,
          selectedItemColor: DoctorApp._clinicalTeal,
          unselectedItemColor: DoctorApp._coolGray,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'سەرەتا',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'نۆرەکانم',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'ئاگاداری',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'پڕۆفایل'),
          ],
        ),
      ),
    );
  }
}
