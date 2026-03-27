import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_rtl.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key, this.embedded = false});

  /// When true, used inside [IndexedStack] without an [AppBar] (parent supplies title).
  final bool embedded;

  static String _statusKey(dynamic raw) {
    return (raw ?? 'pending').toString().trim().toLowerCase();
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortNewestFirst(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final list = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    int ts(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final c = d.data()['createdAt'];
      if (c is Timestamp) return c.millisecondsSinceEpoch;
      return 0;
    }

    list.sort((a, b) => ts(b).compareTo(ts(a)));
    return list;
  }

  static String _formatDateTime(Map<String, dynamic> data) {
    final date = data['date'];
    final time = (data['time'] ?? '—').toString();
    String datePart = '—';
    if (date is Timestamp) {
      datePart = DateFormat('yyyy/MM/dd').format(date.toDate());
    }
    return '$datePart  •  $time';
  }

  Future<void> _setStatus(BuildContext context, String docId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'completed' ? 'وەک تەواوبوو تۆمارکرا' : 'وەک هەڵوەشاوە تۆمارکرا',
              style: const TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هەڵە لە نوێکردنەوە')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final body = uid == null
            ? const Center(
                child: Text(
                  'چوونەژوورەوە پێویستە',
                  style: TextStyle(color: Color(0xFF829AB1), fontFamily: 'KurdishFont'),
                ),
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('appointments')
                    .where('doctorId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'هەڵە: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final sorted = _sortNewestFirst(docs);

                  if (sorted.isEmpty) {
                    return const Center(
                      child: Text(
                        'هیچ نۆرەیەکی نوێ نییە',
                        style: TextStyle(
                          color: Color(0xFF829AB1),
                          fontFamily: 'KurdishFont',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = sorted[index];
                      final data = doc.data();
                      final patientName = (data['patientName'] ?? '—').toString();
                      final status = _statusKey(data['status']);
                      final dateTimeLine = _formatDateTime(data);

                      return _AppointmentCard(
                        patientName: patientName,
                        dateTimeLine: dateTimeLine,
                        status: status,
                        showActions: status == 'pending',
                        onComplete: () => _setStatus(context, doc.id, 'completed'),
                        onCancel: () => _setStatus(context, doc.id, 'cancelled'),
                      );
                    },
                  );
                },
              );

    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: embedded
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'گەڕانەوە',
                ),
                title: const Text(
                  'نۆرەکانی داواکراو',
                  style: TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: const Color(0xFFD9E2EC),
                elevation: 0,
              ),
        body: body,
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.patientName,
    required this.dateTimeLine,
    required this.status,
    required this.showActions,
    required this.onComplete,
    required this.onCancel,
  });

  final String patientName;
  final String dateTimeLine;
  final String status;
  final bool showActions;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  Color get _badgeColor {
    switch (status) {
      case 'completed':
        return const Color(0xFF28C76F);
      case 'cancelled':
        return const Color(0xFFFF4D6D);
      case 'pending':
      default:
        return const Color(0xFFE6B800);
    }
  }

  String get _badgeLabel {
    switch (status) {
      case 'completed':
        return 'تەواوبوو';
      case 'cancelled':
        return 'هەڵوەشاوە';
      case 'pending':
      default:
        return 'چاوەڕێ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: kRtlTextDirection,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ناوی نەخۆش',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: const Color(0xFF829AB1).withOpacity(0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patientName,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFFD9E2EC),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _badgeColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _badgeColor.withOpacity(0.55)),
                ),
                child: Text(
                  _badgeLabel,
                  style: TextStyle(
                    color: _badgeColor,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'KurdishFont',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'بەروار و کات',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: const Color(0xFF829AB1).withOpacity(0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'KurdishFont',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateTimeLine,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFD9E2EC),
              fontSize: 15,
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            Row(
              textDirection: kRtlTextDirection,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF4D6D),
                      side: const BorderSide(color: Color(0xFFFF4D6D)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ڕەتکردنەوە',
                      style: TextStyle(
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28C76F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تەواوبوو',
                      style: TextStyle(
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
