// Generated from android/app/google-services.json for Android.
// For Web, iOS, macOS, Windows, or Linux, run:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// and replace this file, or merge the new platform blocks.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web. Add a Web app in Firebase Console '
        'and run: flutterfire configure',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Firebase is not configured for Apple platforms. Add an iOS app in '
          'Firebase Console, download GoogleService-Info.plist, and run: '
          'flutterfire configure',
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase is not configured for desktop. Run: flutterfire configure',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAmW1VYvOJXLuAHx1bsgPRD2Lfcq05A_qY',
    appId: '1:697067838527:android:437a318bcdec3922b06c8a',
    messagingSenderId: '697067838527',
    projectId: 'doctorapp-4daa6',
    storageBucket: 'doctorapp-4daa6.firebasestorage.app',
  );
}
