import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bootstrap/ensure_shared_preferences_registered.dart';
import 'firebase_options.dart';
import 'package:flutter_application_1/nawarok/listidoctorakan.dart';
import 'package:flutter_application_1/nawarok/profile.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'locale/app_locale.dart';
import 'patient/my_appointments_screen.dart';
import 'push/fcm_foreground_notifications.dart';
import 'push/firebase_messaging_background.dart';
import 'push/patient_push_registration.dart';
import 'splash_screen.dart';
// Auth routing: [AuthGate] listens to FirebaseAuth.instance.authStateChanges;
// patient login also uses Navigator.pushAndRemoveUntil to [PatientHomeScreen] for instant UI.
import 'theme/app_fonts.dart';
import 'theme/hr_nora_colors.dart';
import 'theme/staff_premium_theme.dart';

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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FcmForegroundNotifications.init();
    await PatientPushRegistration.promptNotificationPermissionOnFirstLaunch();
    FirebaseMessaging.onMessage.listen(
      FcmForegroundNotifications.showFromRemoteMessage,
    );
  }
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
          supportedLocales: const [Locale('en'), Locale('ar')],
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
                foregroundColor: WidgetStateProperty.all(
                  HrNoraColors.accentLight,
                ),
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
/// Patient shell: three equal tabs (home / notifications / profile), no center FAB.
/// Doctor shell with the gold schedule button between Profile and Appointments is
/// [DoctorHomeScreen] (`lib/doctor/doctor_home_screen.dart`).
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PatientPushRegistration.registerForCurrentUser();
    });
  }

  int _currentIndex = 0;
  static const Color _mainBgTop = Colors.white;
  static const Color _mainBgBottom = Color(0xFFE3F2FD);

  // Bottom nav order: Home, Search, (Center) Appointments, Chat, Profile.
  final List<Widget> _screens = const [
    ListiDoctorakanScreen(),
    _MainSearchPlaceholderScreen(),
    _MainAppointmentsHostScreen(),
    _MainChatPlaceholderScreen(),
    ProfileScreen(),
  ];

  Widget _buildFloatingMainBottomNav(BuildContext context) {
    const Color barColor = Color(0xFF111827);
    const Color tealColor = Color(0xFF1FD1B6);

    double getIndicatorX(int index) {
      final isRtl = Directionality.of(context) == TextDirection.rtl;
      // Precise alignment for the teal circle behind icons
      final positions = {0: -0.84, 1: -0.42, 3: 0.42, 4: 0.84};
      double x = positions[index] ?? 0.0;
      return isRtl ? -x : x;
    }

    Widget navItem(int index, IconData icon, String label) {
      bool isSelected = _currentIndex == index;
      return Expanded(
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white30,
                  size: isSelected ? 28 : 24,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white30,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 90,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Moving Indicator
          if (_currentIndex != 2)
            AnimatedAlign(
              duration: const Duration(milliseconds: 500),
              curve: Curves.bounceOut,
              alignment: Alignment(getIndicatorX(_currentIndex), 0),
              child: Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tealColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Row(
            children: [
              navItem(0, Icons.home_rounded, 'سەرەکی'),
              navItem(1, Icons.search_rounded, 'گەڕان'),
              const SizedBox(width: 80), // Space for FAB
              navItem(3, Icons.chat_bubble_outline_rounded, 'چات'),
              navItem(4, Icons.person_outline_rounded, 'پڕۆفایل'),
            ],
          ),
          // Professional Elevated FAB
          Positioned(
            top: -25,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _currentIndex = 2);
                },
                child: Column(
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [tealColor, Color(0xFF0AAE95)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: tealColor.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: barColor, width: 4),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'چاوپێکەوتن',
                      style: TextStyle(
                        color: _currentIndex == 2 ? tealColor : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        extendBody: true,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: _buildFloatingMainBottomNav(context),
      ),
    );
  }
}

class _MainAppointmentsHostScreen extends StatelessWidget {
  const _MainAppointmentsHostScreen();

  @override
  Widget build(BuildContext context) {
    // Uses the patient appointments UI (embedded keeps it shell-friendly).
    return const PatientAppointmentsScreen(embedded: true);
  }
}

class _MainSearchPlaceholderScreen extends StatelessWidget {
  const _MainSearchPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('گەڕان', style: TextStyle(fontFamily: kPatientPrimaryFont)),
    );
  }
}

class _MainChatPlaceholderScreen extends StatelessWidget {
  const _MainChatPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('چات', style: TextStyle(fontFamily: kPatientPrimaryFont)),
    );
  }
}
