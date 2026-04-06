import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/firestore_user_doc_id.dart';
import '../firestore/root_notifications_firestore.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';
import 'patient_notification_formatting.dart';
import 'patient_notification_tile.dart';
import 'patient_recipient_keys.dart';

/// In-app list of server-pushed messages (cancellations, clinic closure, etc.).
class PatientNotificationsScreen extends StatefulWidget {
  const PatientNotificationsScreen({super.key});

  @override
  State<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState
    extends State<PatientNotificationsScreen> {
  static const Color _kTitleNavy = Color(0xFF0D2137);

  late final Future<Set<String>> _recipientKeysFuture =
      resolvePatientRecipientKeys();

  @override
  void initState() {
    super.initState();
    ensurePatientNotificationTimeagoLocales();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleUnreadRead());
  }

  Future<void> _markVisibleUnreadRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docId = firestoreUserDocId(user).trim();
    try {
      final batch = FirebaseFirestore.instance.batch();
      var n = 0;
      var hasWrites = false;
      final touched = <DocumentReference<Map<String, dynamic>>>{};

      final keys = await _recipientKeysFuture;
      for (final k in keys) {
        if (k.isEmpty) continue;
        final snap = await FirebaseFirestore.instance
            .collection(RootNotificationFields.collection)
            .where(RootNotificationFields.patientId, isEqualTo: k)
            .orderBy(RootNotificationFields.createdAt, descending: true)
            .limit(40)
            .get();
        for (final d in snap.docs) {
          final st =
              (d.data()[RootNotificationFields.status] ?? '').toString();
          if (st != 'unread') continue;
          if (touched.add(d.reference)) {
            batch.update(d.reference, {RootNotificationFields.status: 'read'});
            hasWrites = true;
            n++;
            if (n >= 400) break;
          }
        }
        if (n >= 400) break;
      }

      if (docId.isNotEmpty) {
        final col = FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .collection('notificationInbox');
        final inboxSnap =
            await col.where('read', isEqualTo: false).limit(50).get();
        for (final d in inboxSnap.docs) {
          batch.update(d.reference, {'read': true});
          hasWrites = true;
        }
      }

      if (hasWrites) await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: patientSkyGradientDecoration(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: _kTitleNavy,
                    ),
                    Expanded(
                      child: Text(
                        s.translate('patient_notifications_screen_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: _kTitleNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Directionality(
                  textDirection: AppLocaleScope.of(context).textDirection,
                  child: user == null
                      ? Center(
                          child: Text(
                            s.translate('patient_notifications_login'),
                            style: TextStyle(
                              color: _kTitleNavy.withValues(alpha: 0.7),
                              fontFamily: kPatientPrimaryFont,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : FutureBuilder<Set<String>>(
                          future: _recipientKeysFuture,
                          builder: (context, keySnap) {
                            if (keySnap.connectionState ==
                                    ConnectionState.waiting &&
                                !keySnap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF1976D2),
                                ),
                              );
                            }
                            final keys = keySnap.data ?? {};
                            if (keys.isEmpty) {
                              return Center(
                                child: Text(
                                  s.translate('patient_notifications_login'),
                                  style: TextStyle(
                                    color: _kTitleNavy.withValues(alpha: 0.7),
                                    fontFamily: kPatientPrimaryFont,
                                    fontSize: 15,
                                  ),
                                ),
                              );
                            }
                            return StreamBuilder<
                                List<
                                    QueryDocumentSnapshot<
                                        Map<String, dynamic>>>>(
                              stream: watchRootNotificationsForRecipientKeys(
                                keys,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        '${snapshot.error}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontFamily: kPatientPrimaryFont,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                if (snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF1976D2),
                                    ),
                                  );
                                }
                                final docs = snapshot.data ?? [];
                                if (docs.isEmpty) {
                                  return const _PatientNotificationsEmptyView();
                                }
                                return ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 28),
                                  itemCount: docs.length,
                                  itemBuilder: (context, index) {
                                    return PatientNotificationTile(
                                      doc: docs[index],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell illustration + glass panel (no external Lottie asset required).
class _PatientNotificationsEmptyView extends StatelessWidget {
  const _PatientNotificationsEmptyView();

  static const Color _navy = Color(0xFF0D2137);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    right: 20,
                    top: 24,
                    child: _glowBlob(100, const Color(0xFF90CAF9)),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 20,
                    child: _glowBlob(88, const Color(0xFFB39DDB)),
                  ),
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.55),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _navy.withValues(alpha: 0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: _navy.withValues(alpha: 0.35),
                    ),
                  ),
                  Positioned(
                    top: 36,
                    right: 64,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 22,
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _navy.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    s.translate('patient_notifications_empty_modern'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.45,
                      color: _navy.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _glowBlob(double size, Color color) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
