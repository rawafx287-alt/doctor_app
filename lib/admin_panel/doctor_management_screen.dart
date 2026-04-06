import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import 'admin_edit_doctor_screen.dart';

/// Lists approved doctors; admin can remove a doctor document from Firestore.
class DoctorManagementScreen extends StatelessWidget {
  const DoctorManagementScreen({super.key});

  Future<void> _confirmAndDelete(
    BuildContext context,
    String uid,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: const Text(
            'سڕینەوەی پزیشک',
            style: TextStyle(
              color: Color(0xFFD9E2EC),
              fontFamily: 'NRT',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'دڵنیایت لە سڕینەوەی "$name"؟',
            style: const TextStyle(
              color: Color(0xFF829AB1),
              fontFamily: 'NRT',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'پاشگەزبوونەوە',
                style: TextStyle(
                  color: Color(0xFF829AB1),
                  fontFamily: 'NRT',
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'سڕینەوە',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontFamily: 'NRT',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'سڕایەوە: $name',
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هەڵەیەک ڕوویدا لە سڕینەوە',
            style: TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
    }
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
          'لیستی پزیشکان',
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
              .where('isApproved', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'هەڵەیەک لە هێنانی لیستەکە ڕوویدا',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
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
                    'هیچ پزیشکێکی قبوڵکراو نییە',
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
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = (data['fullName'] ?? 'بێ ناو').toString();
                final specialty =
                    (data['specialty'] ?? 'دیارینەکراو').toString();
                final phone = (data['phone'] ?? '').toString().trim();

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Color(0xFFD9E2EC),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'NRT',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'پسپۆڕی: $specialty',
                              style: const TextStyle(
                                color: Color(0xFF829AB1),
                                fontSize: 13,
                                fontFamily: 'NRT',
                              ),
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                phone,
                                style: const TextStyle(
                                  color: Color(0xFF627D98),
                                  fontSize: 12,
                                  fontFamily: 'NRT',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'دەستکاری',
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF42A5F5),
                        ),
                        onPressed: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  AdminEditDoctorScreen(doctorId: doc.id),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'سڕینەوە',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444),
                        ),
                        onPressed: () =>
                            _confirmAndDelete(context, doc.id, name),
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
