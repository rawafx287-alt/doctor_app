import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_rtl.dart';
import '../auth/app_logout.dart';
import 'patient_edit_profile_screen.dart';

/// Patient profile tab: info card + settings; logout uses [performAppLogout].
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await performAppLogout(context);
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: kRtlTextDirection,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'زمان',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD9E2EC),
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF42A5F5)),
                title: const Text(
                  'کوردی',
                  style: TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'ئێستا چالاکە',
                  style: TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'نور بۆ پزیشکان',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.medical_services_rounded,
          color: Color(0xFF42A5F5),
          size: 32,
        ),
      ),
      children: [
        const Directionality(
          textDirection: kRtlTextDirection,
          child: Text(
            'ئەم ئەپە یارمەتی تۆ دەدات بۆ دۆزینەوەی پزیشک و بەڕێوەبردنی نۆرەکان.',
            style: TextStyle(
              color: Color(0xFF829AB1),
              fontFamily: 'KurdishFont',
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Directionality(
      textDirection: kRtlTextDirection,
      child: ColoredBox(
        color: const Color(0xFF0A0E21),
        child: uid == null
            ? const Center(
                child: Text(
                  'هیچ هەژمارێک نییە',
                  style: TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                  ),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final name =
                      (data?['fullName'] ?? 'نەخۆش').toString();
                  final emailFromDoc =
                      (data?['email'] ?? '').toString().trim();
                  final authEmail =
                      FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
                  final email = emailFromDoc.isNotEmpty
                      ? emailFromDoc
                      : (authEmail.isNotEmpty ? authEmail : '—');

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF42A5F5)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF42A5F5),
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: Color(0xFFD9E2EC),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'KurdishFont',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        textDirection: kRtlTextDirection,
                                        children: [
                                          const Icon(
                                            Icons.alternate_email_rounded,
                                            size: 18,
                                            color: Color(0xFF627D98),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              email,
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                color: Color(0xFF9FB3C8),
                                                fontSize: 14,
                                                fontFamily: 'KurdishFont',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SettingsCard(
                        children: [
                          _tile(
                            icon: Icons.edit_outlined,
                            title: 'گۆڕینی زانیارییەکان',
                            subtitle: 'ناو و ژمارەی مۆبایل',
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const PatientEditProfileScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          _tile(
                            icon: Icons.language_rounded,
                            title: 'زمان',
                            subtitle: 'کوردی',
                            onTap: () => _showLanguageSheet(context),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          _tile(
                            icon: Icons.info_outline_rounded,
                            title: 'دەربارەی ئەپ',
                            subtitle: 'وەشان و زانیاری',
                            onTap: () => _showAbout(context),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          _tile(
                            icon: Icons.logout_rounded,
                            title: 'چوونەدەرەوە',
                            subtitle: null,
                            iconColor: const Color(0xFFEF4444),
                            titleColor: const Color(0xFFFCA5A5),
                            onTap: () => _logout(context),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }
}

Widget _tile({
  required IconData icon,
  required String title,
  String? subtitle,
  Color? iconColor,
  Color? titleColor,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Icon(
      icon,
      color: iconColor ?? const Color(0xFF42A5F5),
      size: 26,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: titleColor ?? const Color(0xFFD9E2EC),
        fontFamily: 'KurdishFont',
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF829AB1),
              fontFamily: 'KurdishFont',
              fontSize: 12,
            ),
          ),
    trailing: const Icon(
      Icons.chevron_left_rounded,
      color: Color(0xFF627D98),
      size: 22,
    ),
    onTap: onTap,
  );
}
