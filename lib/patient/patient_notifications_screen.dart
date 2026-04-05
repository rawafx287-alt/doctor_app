import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';

/// In-app list of server-pushed messages (cancellations, clinic closure, etc.).
class PatientNotificationsScreen extends StatefulWidget {
  const PatientNotificationsScreen({super.key});

  @override
  State<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState
    extends State<PatientNotificationsScreen> {
  static const Color _kCardBorder = Color(0xFF90CAF9);
  static const Color _kTitleNavy = Color(0xFF0D2137);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleUnreadRead());
  }

  Future<void> _markVisibleUnreadRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docId = firestoreUserDocId(user).trim();
    if (docId.isEmpty) return;
    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .collection('notificationInbox');
      final snap =
          await col.where('read', isEqualTo: false).limit(50).get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final docId = user != null ? firestoreUserDocId(user) : '';

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
                  child: user == null || docId.isEmpty
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
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(docId)
                              .collection('notificationInbox')
                              .orderBy('createdAt', descending: true)
                              .limit(50)
                              .snapshots(),
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
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    s.translate('patient_notifications_empty'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _kTitleNavy.withValues(alpha: 0.72),
                                      fontFamily: kPatientPrimaryFont,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final d = docs[index].data();
                                final body =
                                    (d['body'] ?? '').toString().trim().isEmpty
                                        ? '—'
                                        : d['body'].toString();
                                final type = (d['type'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final isCancel = type.contains('cancel') ||
                                    type == 'clinic_closed';
                                final created = d['createdAt'];
                                var timeStr = '';
                                if (created is Timestamp) {
                                  timeStr = DateFormat.yMMMd()
                                      .add_jm()
                                      .format(created.toDate());
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(16),
                                    elevation: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isCancel
                                              ? const Color(0xFFE53935)
                                                  .withValues(alpha: 0.55)
                                              : _kCardBorder.withValues(
                                                  alpha: 0.65,
                                                ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: isCancel
                                                ? const Color(0xFFFFEBEE)
                                                : const Color(0xFFE3F2FD),
                                            child: Icon(
                                              isCancel
                                                  ? Icons.event_busy_rounded
                                                  : Icons
                                                      .notifications_none_rounded,
                                              color: isCancel
                                                  ? const Color(0xFFC62828)
                                                  : const Color(0xFF1565C0),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (d['title'] ?? 'نۆرینگە')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        kPatientPrimaryFont,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                    color: _kTitleNavy,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  body,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        kPatientPrimaryFont,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    height: 1.35,
                                                    color: isCancel
                                                        ? const Color(
                                                            0xFFB71C1C,
                                                          )
                                                        : _kTitleNavy
                                                            .withValues(
                                                              alpha: 0.82,
                                                            ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (timeStr.isNotEmpty)
                                            Text(
                                              timeStr,
                                              style: TextStyle(
                                                fontFamily: kPatientPrimaryFont,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 10,
                                                color: _kTitleNavy.withValues(
                                                  alpha: 0.45,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
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
