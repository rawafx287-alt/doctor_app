import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'auth_service.dart';

/// Signs out, clears persisted session flags, and replaces the stack with [AuthGate].
///
/// Pushing [LoginScreen] alone removes [AuthGate] from the tree (MaterialApp’s
/// auth listener root), which commonly yields a black screen and breaks login.
/// [AuthGate] listens to [authStateChanges] and shows [LoginScreen] when the
/// user is null.
Future<void> performAppLogout(BuildContext context) async {
  await AuthService.instance.clearSession();
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    (route) => false,
  );
}
