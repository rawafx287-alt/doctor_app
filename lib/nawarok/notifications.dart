import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';

/// Server-written rows from Cloud Functions when appointments are cancelled.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final docId = user != null ? firestoreUserDocId(user) : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'ئاگادارکردنەوەکان',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: user == null || docId.isEmpty
            ? const Center(
                child: Text(
                  'تکایە بچۆ ژوورەوە',
                  style: TextStyle(color: Colors.white70),
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
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'هێشتا ئاگادارکردنەوەیەک نییە',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final d = docs[index].data();
                      final body =
                          (d['body'] ?? '').toString().trim().isEmpty
                              ? '—'
                              : d['body'].toString();
                      final type =
                          (d['type'] ?? '').toString().toLowerCase();
                      final isCancel = type.contains('cancel') ||
                          type == 'clinic_closed';
                      final created = d['createdAt'];
                      String timeAgo = '';
                      if (created is Timestamp) {
                        final dt = created.toDate();
                        timeAgo = DateFormat.yMMMd().add_jm().format(dt);
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isCancel
                                ? const Color(0xFFE53935)
                                    .withValues(alpha: 0.75)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: isCancel
                                  ? const Color(0xFFC62828)
                                      .withValues(alpha: 0.35)
                                  : Colors.grey.withValues(alpha: 0.2),
                              child: Icon(
                                isCancel
                                    ? Icons.event_busy_rounded
                                    : Icons.notifications_none_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (d['title'] ?? 'نۆرینگە').toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    body,
                                    style: TextStyle(
                                      color: isCancel
                                          ? const Color(0xFFFFCDD2)
                                          : Colors.grey,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (timeAgo.isNotEmpty)
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
