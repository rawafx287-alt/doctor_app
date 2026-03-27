import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app_rtl.dart';

/// Admin view of patient feedback ([support_messages]).
class AdminFeedbackScreen extends StatelessWidget {
  const AdminFeedbackScreen({super.key});

  static const Color _accent = Color(0xFF42A5F5);

  String _formatTime(dynamic raw) {
    if (raw is Timestamp) {
      final d = raw.toDate();
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '—';
  }

  String _emailLine(Map<String, dynamic> data) {
    final v = (data['patientEmail'] ?? '').toString().trim();
    if (v.isEmpty) return 'ئیمەیڵ: —';
    return 'ئیمەیڵ: $v';
  }

  String? _phoneLine(Map<String, dynamic> data) {
    final v = (data['patientPhone'] ?? '').toString().trim();
    if (v.isEmpty) return null;
    return 'مۆبایل: $v';
  }

  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance.collection('support_messages').doc(id).delete();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String id,
    String senderName,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: kRtlTextDirection,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: const Text(
            'سڕینەوەی بۆچوون',
            style: TextStyle(
              color: Color(0xFFD9E2EC),
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'دڵنیایت لە سڕینەوەی بۆچوونی "$senderName"؟',
            style: const TextStyle(
              color: Color(0xFF829AB1),
              fontFamily: 'KurdishFont',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'پاشگەزبوونەوە',
                style: TextStyle(
                  color: Color(0xFF829AB1),
                  fontFamily: 'KurdishFont',
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'سڕینەوە',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await _delete(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'بۆچوونەکە سڕایەوە',
              style: TextStyle(fontFamily: 'KurdishFont'),
            ),
          ),
        );
      }
    }
  }

  void _openDetailDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final name = (data['patientName'] ?? '—').toString();
    final email = (data['patientEmail'] ?? '').toString().trim();
    final phone = (data['patientPhone'] ?? '').toString().trim();
    final body = (data['message'] ?? '').toString();
    final time = _formatTime(data['timestamp']);

    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: kRtlTextDirection,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _accent, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'وردەکاری بۆچوون',
                  style: TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _detailRow('ناو', name),
                  const SizedBox(height: 12),
                  _detailRow(
                    'ئیمەیڵ',
                    email.isEmpty ? '—' : email,
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow('مۆبایل', phone),
                  ],
                  const SizedBox(height: 12),
                  _detailRow('کات', time),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 14),
                  const Text(
                    'پەیام',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF627D98),
                      fontFamily: 'KurdishFont',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    body.isEmpty ? '—' : body,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontSize: 15,
                      height: 1.55,
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'داخستن',
                style: TextStyle(
                  color: _accent,
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Color(0xFF627D98),
            fontFamily: 'KurdishFont',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Color(0xFFD9E2EC),
            fontSize: 16,
            fontFamily: 'KurdishFont',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.feedback_outlined, color: _accent, size: 26),
            SizedBox(width: 10),
            Text(
              'بۆچوونەکان',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'KurdishFont',
              ),
            ),
          ],
        ),
      ),
      body: Directionality(
        textDirection: kRtlTextDirection,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('support_messages')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'هەڵە: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _accent),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.feedback_outlined,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'هیچ بۆچوونێک نییە',
                      style: TextStyle(
                        color: Color(0xFF829AB1),
                        fontSize: 16,
                        fontFamily: 'KurdishFont',
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = (data['patientName'] ?? '—').toString();
                final body = (data['message'] ?? '').toString();
                final time = _formatTime(data['timestamp']);
                final unread =
                    (data['status'] ?? '').toString() == 'unread';
                final phoneLine = _phoneLine(data);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openDetailDialog(context, data),
                    child: Ink(
                      padding: const EdgeInsets.fromLTRB(18, 18, 14, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: unread
                              ? _accent.withValues(alpha: 0.4)
                              : Colors.white10,
                          width: unread ? 1.2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              color: Color(0xFFD9E2EC),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'KurdishFont',
                                            ),
                                          ),
                                        ),
                                        if (unread) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _accent.withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'نوێ',
                                              style: TextStyle(
                                                color: _accent,
                                                fontSize: 11,
                                                fontFamily: 'KurdishFont',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _emailLine(data),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Color(0xFF9FB3C8),
                                        fontSize: 13,
                                        fontFamily: 'KurdishFont',
                                        height: 1.35,
                                      ),
                                    ),
                                    if (phoneLine != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        phoneLine,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: Color(0xFF9FB3C8),
                                          fontSize: 13,
                                          fontFamily: 'KurdishFont',
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        color: Color(0xFF627D98),
                                        fontSize: 12,
                                        fontFamily: 'KurdishFont',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'سڕینەوە',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 24,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, doc.id, name),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 14, bottom: 12),
                            child: Divider(height: 1, color: Colors.white12),
                          ),
                          Text(
                            body.isEmpty ? '—' : body,
                            textAlign: TextAlign.right,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF9FB3C8),
                              fontSize: 15,
                              height: 1.55,
                              fontFamily: 'KurdishFont',
                            ),
                          ),
                          if (body.length > 160 ||
                              body.split('\n').length > 3) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'کرتە بکە بۆ بینینی تەواو',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF627D98),
                                fontSize: 11,
                                fontFamily: 'KurdishFont',
                              ),
                            ),
                          ],
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
    );
  }
}
