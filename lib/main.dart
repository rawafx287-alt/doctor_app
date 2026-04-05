import 'dart:ui' show ImageFilter;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
    FirebaseMessaging.onMessage.listen(FcmForegroundNotifications.showFromRemoteMessage);
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
  static const Color _mainNavInactive = Color(0xFF9AA5B1);

  final List<Widget> _screens = [
    const ListiDoctorakanScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  Widget _buildFloatingMainBottomNav(BuildContext context) {
    final s = S.of(context);
    const barRadius = 32.0;
    const barHeight = 64.0;

    Widget tab({
      required int index,
      required FaIconData icon,
      required FaIconData iconActive,
      required String label,
    }) {
      final selected = _currentIndex == index;
      final gold = kStaffLuxGold;
      final inactive = _mainNavInactive;

      final iconWidget = FaIcon(
        selected ? iconActive : icon,
        size: 22,
        color: selected ? gold : inactive,
      );

      return Expanded(
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _currentIndex = index);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 24, child: Center(child: iconWidget)),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? gold : Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      height: 1.05,
                      color: selected ? gold : inactive,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(barRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: kStaffLuxGold.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(barRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  border: Border(
                    top: BorderSide(
                      color: kStaffLuxGold.withValues(alpha: 0.78),
                      width: 1,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(barRadius),
                ),
                child: Row(
                  children: [
                    tab(
                      index: 0,
                      icon: FontAwesomeIcons.house,
                      iconActive: FontAwesomeIcons.house,
                      label: s.translate('home'),
                    ),
                    tab(
                      index: 1,
                      icon: FontAwesomeIcons.bell,
                      iconActive: FontAwesomeIcons.solidBell,
                      label: s.translate('notifications'),
                    ),
                    tab(
                      index: 2,
                      icon: FontAwesomeIcons.user,
                      iconActive: FontAwesomeIcons.solidUser,
                      label: s.translate('profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
