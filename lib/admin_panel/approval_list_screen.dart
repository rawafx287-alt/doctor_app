import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';

/// Pending doctor registrations: [role] Doctor, [isApproved] false.
class ApprovalListScreen extends StatefulWidget {
  const ApprovalListScreen({super.key});

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen> {
  static const Color _approveGreen = Color(0xFF22C55E);
  static const Color _rejectRed = Color(0xFFEF4444);

  Future<void> _approve(String uid, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isApproved': true,
      'status': 'approved',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'قبوڵکرا: $name',
          style: const TextStyle(fontFamily: 'NRT'),
        ),
      ),
    );
  }

  Future<void> _reject(String uid, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ڕەتکرایەوە: $name',
          style: const TextStyle(fontFamily: 'NRT'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'داواکارییەکان',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'NRT',
          ),
        ),
      ),
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'Doctor')
              .where('isApproved', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'هەڵەیەک لە هێنانی داواکارییەکان ڕوویدا',
                  style: TextStyle(
                    color: _rejectRed,
                    fontFamily: 'NRT',
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'هیچ داواکارییەکی نوێ نییە',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF829AB1),
                      fontSize: 16,
                      fontFamily: 'NRT',
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(18),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = (data['fullName'] ?? 'بێ ناو').toString();
                final specialty =
                    (data['specialty'] ?? 'دیارینەکراو').toString();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFFD9E2EC),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NRT',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'پسپۆڕی: $specialty',
                        style: const TextStyle(
                          color: Color(0xFF829AB1),
                          fontFamily: 'NRT',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _approveGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => _approve(doc.id, name),
                              child: const Text(
                                'قبوڵکردن',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'NRT',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _rejectRed,
                                side: const BorderSide(
                                  color: _rejectRed,
                                  width: 1.4,
                                ),
                                minimumSize: const Size(double.infinity, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => _reject(doc.id, name),
                              child: const Text(
                                'ڕەتکردنەوە',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'NRT',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: docs.length,
            );
          },
        ),
      ),
    );
  }
}
