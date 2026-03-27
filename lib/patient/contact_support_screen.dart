import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_rtl.dart';

/// Patient feedback → Firestore [support_messages] with contact fields + [timestamp].
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _messageController = TextEditingController();
  bool _sending = false;

  static const _fieldFill = Color(0xFF1A1F35);
  static const _borderIdle = Color(0xFF334E68);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تکایە بۆچوونەکەت بنووسە',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تکایە بچۆ ژوورەوە',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final userSnap =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userSnap.data() ?? {};
      final name = (data['fullName'] ?? 'نەخۆش').toString().trim();
      final emailFromProfile = (data['email'] ?? '').toString().trim();
      final phoneFromProfile = (data['phone'] ?? '').toString().trim();
      final email = (user.email ?? emailFromProfile).trim();
      final phone = phoneFromProfile;

      await FirebaseFirestore.instance.collection('support_messages').add({
        'patientId': user.uid,
        'patientName': name.isEmpty ? 'نەخۆش' : name,
        'patientEmail': email,
        'patientPhone': phone,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });

      if (!mounted) return;
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'سوپاس، بۆچوونەکەت وەرگیرا',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'بۆچوون',
            style: TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'بۆچوون یان پێشنیارەکەت لێرە بنووسە. پشتیوانیەکەمان ئاگادار دەکەینەوە.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlign: TextAlign.right,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontFamily: 'KurdishFont',
                      height: 1.45,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      alignLabelWithHint: true,
                      hintText: 'بۆچوونەکەت لێرە بنووسە...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF627D98),
                        fontFamily: 'KurdishFont',
                      ),
                      filled: true,
                      fillColor: _fieldFill,
                      contentPadding: const EdgeInsets.all(18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _borderIdle, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _borderIdle, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF42A5F5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5),
                      foregroundColor: const Color(0xFF102A43),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: const Color(0xFF334E68),
                    ),
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF102A43),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'ناردن',
                                style: TextStyle(
                                  fontFamily: 'KurdishFont',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
