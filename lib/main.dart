import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'splash_screen.dart';
import 'theme/hr_nora_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final baseButtons = ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HR Nora',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: HrNoraColors.scaffoldDark,
        primaryColor: HrNoraColors.primary,
        colorScheme: ColorScheme.dark(
          primary: HrNoraColors.primary,
          onPrimary: Colors.white,
          secondary: HrNoraColors.accentLight,
          onSecondary: const Color(0xFF0D1B2A),
          surface: HrNoraColors.primaryDeep,
          onSurface: HrNoraColors.textSoft,
          error: const Color(0xFFEF4444),
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: HrNoraColors.primaryDeep,
          foregroundColor: HrNoraColors.textSoft,
          elevation: 0,
          centerTitle: false,
        ),
        cardColor: HrNoraColors.primaryDeep,
        dividerColor: const Color(0xFF334E68),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: HrNoraColors.textSoft),
          bodyMedium: TextStyle(color: HrNoraColors.textSoft),
          titleLarge: TextStyle(
            color: HrNoraColors.textSoft,
            fontWeight: FontWeight.w600,
          ),
          labelLarge: TextStyle(color: HrNoraColors.textSoft),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: baseButtons.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return HrNoraColors.primary.withValues(alpha: 0.38);
              }
              return HrNoraColors.primary;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            overlayColor: WidgetStateProperty.all(
              Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: baseButtons.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return HrNoraColors.primary.withValues(alpha: 0.38);
              }
              return HrNoraColors.primary;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: baseButtons.copyWith(
            foregroundColor: WidgetStateProperty.all(HrNoraColors.accentLight),
            side: WidgetStateProperty.all(
              BorderSide(
                color: HrNoraColors.accentLight.withValues(alpha: 0.65),
                width: 1.2,
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: HrNoraColors.accentLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: HrNoraColors.primary,
          foregroundColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: HrNoraColors.accentLight,
        ),
      ),
      home: const SplashScreen(),
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
              color: HrNoraColors.textMuted.withValues(alpha: 0.35),
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
          backgroundColor: HrNoraColors.primaryDeep,
          selectedItemColor: HrNoraColors.accentLight,
          unselectedItemColor: HrNoraColors.textMuted,
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
