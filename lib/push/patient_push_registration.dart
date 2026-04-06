import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/firestore_user_doc_id.dart';

/// Saves FCM tokens under [users] docs so Cloud Functions can send pushes when
/// appointments are cancelled (doctor/secretary or clinic day closure).
class PatientPushRegistration {
  PatientPushRegistration._();

  static const String _prefFcmPermissionPrompted =
      'hr_nora_fcm_permission_prompted_v1';

  static StreamSubscription<String>? _tokenRefreshSub;

  /// One-time OS permission dialog (first cold start after install / pref clear).
  static Future<void> promptNotificationPermissionOnFirstLaunch() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefFcmPermissionPrompted) == true) return;
      await prefs.setBool(_prefFcmPermissionPrompted, true);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
    } catch (e, st) {
      debugPrint('[FCM] promptNotificationPermissionOnFirstLaunch: $e\n$st');
    }
  }

  /// Call after patient (or any user) signs in — persists token to Firestore.
  static Future<void> registerForCurrentUser() async {
    if (kIsWeb) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final messaging = FirebaseMessaging.instance;

      if (!kIsWeb) {
        final current = await messaging.getNotificationSettings();
        if (current.authorizationStatus == AuthorizationStatus.notDetermined) {
          await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
        }
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      await messaging.setAutoInitEnabled(true);

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await _persistToken(token, user);

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen(
        (newToken) {
          _persistToken(newToken, user);
        },
        onError: (Object e, StackTrace st) {
          debugPrint('[FCM] onTokenRefresh error: $e');
        },
      );
    } catch (e, st) {
      debugPrint('[FCM] registerForCurrentUser failed: $e\n$st');
    }
  }

  static Future<void> _persistToken(String token, User user) async {
    final uid = user.uid.trim();
    final docId = firestoreUserDocId(user);
    final platform = kIsWeb
        ? 'web'
        : (Platform.isIOS ? 'ios' : 'android');

    final entry = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': platform,
    };

    final ids = <String>{uid, docId}..removeWhere((e) => e.isEmpty);
    if (ids.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      final ref = FirebaseFirestore.instance.collection('users').doc(id);
      batch.set(
        ref,
        {
          'fcmTokens': {token: entry},
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
