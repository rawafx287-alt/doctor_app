import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'bootstrap/ensure_shared_preferences_registered.dart';
import 'firebase_options.dart';
import 'package:flutter_application_1/nawarok/listidoctorakan.dart';
import 'package:flutter_application_1/nawarok/profile.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'locale/app_locale.dart';
import 'patient/my_appointments_screen.dart';
import 'push/fcm_foreground_notifications.dart';
import 'push/fcm_cancellation_sync.dart';
import 'push/appointment_local_notifications.dart';
import 'push/appointment_reminder_worker.dart';
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
    // Ensure timezone DB is initialized before scheduling local notifications.
    await AppointmentLocalNotifications.ensureTimeZoneInitialized();
    await AppointmentLocalNotifications.init();
    await AppointmentLocalNotifications.requestPermissions();
    // Background fallback (no Settings UX): poll every ~15 min and trigger
    // instant notifications when reminders are due.
    await Workmanager().initialize(
      appointmentReminderCallbackDispatcher,
    );
    await AppointmentReminderWorker.registerPeriodic();
    await PatientPushRegistration.promptNotificationPermissionOnFirstLaunch();
    FirebaseMessaging.onMessage.listen(
      FcmForegroundNotifications.showFromRemoteMessage,
    );
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      unawaited(syncLocalRemindersForRemoteCancellation(m));
    });
    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      await syncLocalRemindersForRemoteCancellation(initialMsg);
    }
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
/// Patient shell: floating blurred bar, sliding gold pill indicator, center FAB.
/// Doctor shell with schedule FAB is [DoctorHomeScreen].
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const double _fabColumnW = 88;
  static const double _barBodyH = 76;
  static const double _topRadius = 22;
  static const Duration _pillDuration = Duration(milliseconds: 420);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PatientPushRegistration.registerForCurrentUser();
    });
  }

  int _currentIndex = 0;
  /// Sky-blue shell (matches patient profile — airy clinic aesthetic).
  static const Color _mainBgTop = Color(0xFFF1F9FF);
  static const Color _mainBgBottom = Color(0xFFEEF7FC);
  static const Color _navBarSkyFill = Color(0xEEF1F9FF);
  static const Color _navBarBorderGold = Color(0x66D4AF37);
  static const Color _navIconMuted = Color(0x9901579B);

  /// Order: Home, Search, (center FAB) Appointments, Chat, Profile.
  final List<Widget> _screens = const [
    ListiDoctorakanScreen(),
    _MainSearchPlaceholderScreen(),
    _MainAppointmentsHostScreen(),
    _MainChatPlaceholderScreen(),
    ProfileScreen(),
  ];

  /// Horizontal offset of the sliding pill’s left edge (LTR segment layout).
  double _pillLeft(double barW, int index, double pillW) {
    final s = (barW - _fabColumnW) / 4;
    switch (index) {
      case 0:
        return (s - pillW) / 2;
      case 1:
        return s + (s - pillW) / 2;
      case 2:
        return 2 * s + (_fabColumnW - pillW) / 2;
      case 3:
        return 2 * s + _fabColumnW + (s - pillW) / 2;
      case 4:
        return 3 * s + _fabColumnW + (s - pillW) / 2;
      default:
        return 0;
    }
  }

  double _pillWidthFor(int index, double s) {
    if (index == 2) {
      return (_fabColumnW * 0.88).clamp(64.0, 78.0);
    }
    return (s * 0.78).clamp(46.0, 56.0);
  }

  List<Shadow> _goldIconShadows(bool active) {
    if (!active) return const [];
    return [
      Shadow(
        color: kStaffLuxGold.withValues(alpha: 0.95),
        blurRadius: 10,
      ),
      Shadow(
        color: kStaffLuxGoldLight.withValues(alpha: 0.55),
        blurRadius: 18,
      ),
    ];
  }

  List<Shadow> _goldTextShadows(bool active) {
    if (!active) return const [];
    return [
      Shadow(
        color: kStaffLuxGold.withValues(alpha: 0.65),
        blurRadius: 8,
      ),
    ];
  }

  Widget _centerFab() {
    final selected = _currentIndex == 2;
    const skyDeep = Color(0xFF29B6F6);
    const skyLight = Color(0xFF81D4FA);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _currentIndex = 2);
        },
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: selected
                  ? const [Color(0xFF4FC3F7), skyDeep]
                  : const [skyLight, skyDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? kStaffLuxGold : skyDeep)
                    .withValues(alpha: selected ? 0.38 : 0.28),
                blurRadius: selected ? 18 : 14,
                spreadRadius: selected ? 1 : 0,
                offset: const Offset(0, 8),
              ),
              if (selected)
                BoxShadow(
                  color: kStaffLuxGoldLight.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
            ],
            border: Border.all(
              color: selected
                  ? kStaffLuxGold.withValues(alpha: 0.9)
                  : kStaffLuxGold.withValues(alpha: 0.45),
              width: selected ? 2.5 : 2,
            ),
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            color: const Color(0xFF01579B),
            size: 30,
            shadows: _goldIconShadows(selected),
          ),
        ),
      ),
    );
  }

  Widget _navSlot({
    required int index,
    required String label,
    required IconData iconSelected,
    required IconData iconNormal,
  }) {
    final selected = _currentIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: selected ? 1.2 : 1.0,
                  child: Icon(
                    selected ? iconSelected : iconNormal,
                    size: 22,
                    color: selected
                        ? kStaffLuxGold
                        : _navIconMuted,
                    shadows: _goldIconShadows(selected),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? kStaffLuxGold : _navIconMuted,
                    shadows: _goldTextShadows(selected),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      child: SizedBox(
        height: _barBodyH + 36,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_topRadius),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    height: _barBodyH,
                    decoration: BoxDecoration(
                      color: _navBarSkyFill,
                      border: Border(
                        top: BorderSide(
                          color: _navBarBorderGold,
                          width: 1.2,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF01579B).withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        final s = (w - _fabColumnW) / 4;
                        final pillW = _pillWidthFor(_currentIndex, s);
                        return Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            AnimatedPositioned(
                              duration: _pillDuration,
                              curve: Curves.easeOutCubic,
                              left: _pillLeft(w, _currentIndex, pillW),
                              top: 9,
                              width: pillW,
                              height: 50,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: const Color(0xFF81D4FA).withValues(alpha: 0.45),
                                  border: Border.all(
                                    color: kStaffLuxGold.withValues(alpha: 0.45),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kStaffLuxGold.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 14,
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: kStaffLuxGoldLight.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                children: [
                                  _navSlot(
                                    index: 0,
                                    label: 'سەرەکی',
                                    iconSelected: Icons.home_rounded,
                                    iconNormal: Icons.home_outlined,
                                  ),
                                  _navSlot(
                                    index: 1,
                                    label: 'گەڕان',
                                    iconSelected: Icons.search_rounded,
                                    iconNormal: Icons.search_outlined,
                                  ),
                                  const SizedBox(width: _fabColumnW),
                                  _navSlot(
                                    index: 3,
                                    label: 'چات',
                                    iconSelected: Icons.chat_bubble_rounded,
                                    iconNormal:
                                        Icons.chat_bubble_outline_rounded,
                                  ),
                                  _navSlot(
                                    index: 4,
                                    label: 'پڕۆفایل',
                                    iconSelected: Icons.person_rounded,
                                    iconNormal: Icons.person_outline_rounded,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _barBodyH - 34,
              child: Center(child: _centerFab()),
            ),
          ],
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
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _screens[_currentIndex],
          ),
        ),
        bottomNavigationBar: _buildPremiumBottomBar(),
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
