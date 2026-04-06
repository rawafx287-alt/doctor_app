import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';

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
    final s = S.of(context);
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('support_empty'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('support_need_login'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final profileDocId = firestoreUserDocId(user);
      final userSnap =
          await FirebaseFirestore.instance.collection('users').doc(profileDocId).get();
      final data = userSnap.data() ?? {};
      final name = (data['fullName'] ?? s.translate('patient_default')).toString().trim();
      final emailFromProfile = (data['email'] ?? '').toString().trim();
      final phoneFromProfile = (data['phone'] ?? '').toString().trim();
      final email = (user.email ?? emailFromProfile).trim();
      final phone = phoneFromProfile;
      final fallbackName = s.translate('patient_default');

      await FirebaseFirestore.instance.collection('support_messages').add({
        'patientId': user.uid,
        'patientName': name.isEmpty ? fallbackName : name,
        'patientEmail': email,
        'patientPhone': phone,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unread',
      });

      if (!mounted) return;
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('support_thanks_received'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('support_error_retry'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dir = AppLocaleScope.of(context).textDirection;
    final s = S.of(context);
    return Directionality(
      textDirection: dir,
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
          title: Text(
            s.translate('support_title'),
            style: const TextStyle(
              fontFamily: 'NRT',
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
                Text(
                  s.translate('support_intro'),
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'NRT',
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
                    textAlign: TextAlign.start,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: Color(0xFFD9E2EC),
                      fontFamily: 'NRT',
                      height: 1.45,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      alignLabelWithHint: true,
                      hintText: s.translate('support_hint'),
                      hintStyle: const TextStyle(
                        color: Color(0xFF627D98),
                        fontFamily: 'NRT',
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
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                s.translate('support_send'),
                                style: const TextStyle(
                                  fontFamily: 'NRT',
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
