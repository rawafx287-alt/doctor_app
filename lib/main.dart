import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'bootstrap/ensure_shared_preferences_registered.dart';
import 'firebase_options.dart';
import 'package:flutter_application_1/nawarok/listidoctorakan.dart';
import 'package:flutter_application_1/nawarok/notifications.dart';
import 'package:flutter_application_1/nawarok/profile.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'locale/app_locale.dart';
import 'locale/app_localizations.dart';
import 'splash_screen.dart';
import 'theme/hr_nora_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureSharedPreferencesRegistered();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final localeController = LocaleController();
  await localeController.load();
  runApp(HrNoraAppRoot(localeController: localeController));
}

class HrNoraAppRoot extends StatelessWidget {
  const HrNoraAppRoot({super.key, required this.localeController});

  final LocaleController localeController;

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
    final baseTheme = ThemeData(
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
    );
    final kurdishTextTheme = GoogleFonts.notoSansArabicTextTheme(
      baseTheme.textTheme,
    ).apply(
      bodyColor: HrNoraColors.textSoft,
      displayColor: HrNoraColors.textSoft,
    );

    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'HR Nora',
          locale: localeController.materialLocale,
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return AppLocaleScope(
              notifier: localeController,
              child: Directionality(
                textDirection: localeController.textDirection,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          theme: baseTheme.copyWith(
        textTheme: kurdishTextTheme,
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
      },
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
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_filled),
              label: S.of(context).translate('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.notifications),
              label: S.of(context).translate('notifications'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: S.of(context).translate('profile'),
            ),
          ],
        ),
      ),
    );
  }
}
