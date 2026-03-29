import 'package:flutter/foundation.dart';
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:shared_preferences_foundation/shared_preferences_foundation.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

/// Ensures [SharedPreferencesStorePlatform] is not left on the default
/// [MethodChannel] before any [SharedPreferences.getInstance] call.
///
/// The Flutter tool normally runs the generated Dart plugin registrant first,
/// but some IDE/run setups can call [main] code before that, which causes
/// `MissingPluginException` for `plugins.flutter.io/shared_preferences`.
void ensureSharedPreferencesRegistered() {
  if (kIsWeb) return;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      SharedPreferencesAndroid.registerWith();
      break;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      SharedPreferencesFoundation.registerWith();
      break;
    case TargetPlatform.linux:
      PathProviderLinux.registerWith();
      SharedPreferencesLinux.registerWith();
      break;
    case TargetPlatform.windows:
      PathProviderWindows.registerWith();
      SharedPreferencesWindows.registerWith();
      break;
    case TargetPlatform.fuchsia:
      break;
  }
}
