import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_rtl.dart';
import '../auth/app_logout.dart';
import 'profile_settings_screen.dart';

/// Doctor profile tab: name, email, specialty; edit and logout ([performAppLogout]).
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await performAppLogout(context);
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'نور بۆ پزیشکان',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2CB1BC).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.medical_services_rounded,
          color: Color(0xFF2CB1BC),
          size: 32,
        ),
      ),
      children: [
        const Directionality(
          textDirection: kRtlTextDirection,
          child: Text(
            'تەختەی پزیشک و بەڕێوەبردنی نۆرە و خشتە.',
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
                  final name = (data?['fullName'] ?? 'پزیشک').toString();
                  final specialty =
                      (data?['specialty'] ?? '—').toString().trim();
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
                                    color: const Color(0xFF2CB1BC)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.medical_services_rounded,
                                    color: Color(0xFF2CB1BC),
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
                                      const SizedBox(height: 12),
                                      const Text(
                                        'پسپۆڕی',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Color(0xFF627D98),
                                          fontSize: 11,
                                          fontFamily: 'KurdishFont',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        specialty.isEmpty ? '—' : specialty,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: Color(0xFFD9E2EC),
                                          fontSize: 15,
                                          fontFamily: 'KurdishFont',
                                          fontWeight: FontWeight.w600,
                                        ),
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
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            _DoctorProfileTile(
                              icon: Icons.edit_outlined,
                              title: 'گۆڕینی زانیارییەکان',
                              subtitle: 'وێنە، ناونیشان، پسپۆڕی، ژمارە',
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const ProfileSettingsScreen(),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1, color: Colors.white10),
                            _DoctorProfileTile(
                              icon: Icons.info_outline_rounded,
                              title: 'دەربارەی ئەپ',
                              subtitle: 'وەشان و زانیاری',
                              onTap: () => _showAbout(context),
                            ),
                            const Divider(height: 1, color: Colors.white10),
                            _DoctorProfileTile(
                              icon: Icons.logout_rounded,
                              title: 'چوونەدەرەوە',
                              subtitle: null,
                              iconColor: const Color(0xFFEF4444),
                              titleColor: const Color(0xFFFCA5A5),
                              onTap: () => _logout(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _DoctorProfileTile extends StatelessWidget {
  const _DoctorProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        icon,
        color: iconColor ?? const Color(0xFF2CB1BC),
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
              subtitle!,
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
}
