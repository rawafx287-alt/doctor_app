import 'package:firebase_core/firebase_core.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bootstrap/ensure_shared_preferences_registered.dart';
import 'firebase_options.dart';
import 'package:flutter_application_1/nawarok/listidoctorakan.dart';
import 'package:flutter_application_1/nawarok/notifications.dart';
import 'package:flutter_application_1/nawarok/profile.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'locale/app_locale.dart';
import 'locale/app_localizations.dart';
import 'splash_screen.dart';
// Auth routing: [AuthGate] listens to FirebaseAuth.instance.authStateChanges;
// patient login also uses Navigator.pushAndRemoveUntil to [PatientHomeScreen] for instant UI.
import 'theme/app_fonts.dart';
import 'theme/hr_nora_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  ensureSharedPreferencesRegistered();
  // Android: place `google-services.json` in `android/app/` (see Firebase console).
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
    const appFont = kAppFontFamily;
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: kAppFontFamily,
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
      appBarTheme: AppBarTheme(
        backgroundColor: HrNoraColors.primaryDeep,
        foregroundColor: HrNoraColors.textSoft,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kAppFontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: HrNoraColors.textSoft,
        ),
      ),
      cardColor: HrNoraColors.primaryDeep,
      dividerColor: const Color(0xFF334E68),
    );
    final appTextTheme = baseTheme.textTheme
        .apply(
          fontFamily: appFont,
          bodyColor: HrNoraColors.textSoft,
          displayColor: HrNoraColors.textSoft,
        )
        .copyWith(
          displayLarge: baseTheme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          displayMedium: baseTheme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          displaySmall: baseTheme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleSmall: baseTheme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          theme: baseTheme.copyWith(
        textTheme: appTextTheme,
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
  static const Color _mainBgTop = Colors.white;
  static const Color _mainBgBottom = Color(0xFFE3F2FD);

  final List<Widget> _screens = [
    const ListiDoctorakanScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_mainBgBottom, _mainBgTop],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(
                color: HrNoraColors.textMuted.withValues(alpha: 0.25),
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
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedItemColor: const Color(0xFF1565C0),
            unselectedItemColor: HrNoraColors.textMuted,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const FaIcon(FontAwesomeIcons.house, size: 20),
                activeIcon: const FaIcon(FontAwesomeIcons.house, size: 21),
                label: S.of(context).translate('home'),
              ),
              BottomNavigationBarItem(
                icon: const FaIcon(FontAwesomeIcons.bell, size: 20),
                activeIcon: const FaIcon(FontAwesomeIcons.solidBell, size: 21),
                label: S.of(context).translate('notifications'),
              ),
              BottomNavigationBarItem(
                icon: const FaIcon(FontAwesomeIcons.user, size: 20),
                activeIcon: const FaIcon(FontAwesomeIcons.solidUser, size: 21),
                label: S.of(context).translate('profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
