import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLanguagePrefKey = 'hr_nora_app_language';

/// Sorani (stored as `ckb`), Arabic, English.
enum HrNoraLanguage {
  ckb,
  ar,
  en;

  static HrNoraLanguage? fromStorageCode(String? code) {
    switch (code) {
      case 'ckb':
      case 'ku':
        return HrNoraLanguage.ckb;
      case 'ar':
        return HrNoraLanguage.ar;
      case 'en':
        return HrNoraLanguage.en;
      default:
        return null;
    }
  }

  String get storageCode => switch (this) {
        HrNoraLanguage.ckb => 'ckb',
        HrNoraLanguage.ar => 'ar',
        HrNoraLanguage.en => 'en',
      };

  /// Material/Cupertino: Kurdish UI uses English delegates (no built-in `ckb`).
  Locale get materialLocale => switch (this) {
        HrNoraLanguage.en => const Locale('en'),
        HrNoraLanguage.ar => const Locale('ar'),
        HrNoraLanguage.ckb => const Locale('en'),
      };

  TextDirection get textDirection => switch (this) {
        HrNoraLanguage.en => TextDirection.ltr,
        HrNoraLanguage.ar => TextDirection.rtl,
        HrNoraLanguage.ckb => TextDirection.rtl,
      };

  /// Label shown on the language picker (native script).
  String get nativeTitle => switch (this) {
        HrNoraLanguage.ckb => 'کوردی',
        HrNoraLanguage.ar => 'العربية',
        HrNoraLanguage.en => 'English',
      };

  String get nativeSubtitle => switch (this) {
        HrNoraLanguage.ckb => 'سۆرانی',
        HrNoraLanguage.ar => '',
        HrNoraLanguage.en => '',
      };
}

/// Loads/saves language with [SharedPreferences] and notifies listeners.
class LocaleController extends ChangeNotifier {
  LocaleController();

  HrNoraLanguage? _language;

  /// `null` until the user picks a language for the first time.
  HrNoraLanguage? get selectedLanguage => _language;

  bool get hasCompletedLanguageSelection => _language != null;

  /// Resolved language for [S.of] / [AppLocalizations]; before selection defaults to Sorani.
  HrNoraLanguage get effectiveLanguage => _language ?? HrNoraLanguage.ckb;

  Locale get materialLocale {
    if (_language == null) return const Locale('en');
    return _language!.materialLocale;
  }

  TextDirection get textDirection {
    if (_language == null) return TextDirection.ltr;
    return _language!.textDirection;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = HrNoraLanguage.fromStorageCode(prefs.getString(_kLanguagePrefKey));
    notifyListeners();
  }

  Future<void> setLanguage(HrNoraLanguage language) async {
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguagePrefKey, language.storageCode);
  }
}

/// Provides [LocaleController] below [MaterialApp] (see [main.dart] `builder`).
class AppLocaleScope extends InheritedNotifier<LocaleController> {
  const AppLocaleScope({
    required LocaleController super.notifier,
    required super.child,
    super.key,
  });

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope not found above this context');
    return scope!.notifier!;
  }
}
