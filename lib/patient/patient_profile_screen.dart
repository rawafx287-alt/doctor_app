import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../locale/language_picker.dart';
import 'patient_edit_profile_screen.dart';

/// Patient profile tab: info card + settings; logout uses [performAppLogout].
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await performAppLogout(context);
  }

  void _showLanguageSheet(BuildContext context) {
    showHrNoraLanguagePicker(context);
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: S.of(context).translate('app_display_name'),
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
        Directionality(
          textDirection: AppLocaleScope.of(context).textDirection,
          child: Text(
            S.of(context).translate('about_description'),
            style: const TextStyle(
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
      textDirection: AppLocaleScope.of(context).textDirection,
      child: ColoredBox(
        color: const Color(0xFF0A0E21),
        child: uid == null
            ? Center(
                child: Text(
                  S.of(context).translate('profile_guest'),
                  style: const TextStyle(
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
                  final name = (data?['fullName'] ??
                          S.of(context).translate('patient_default'))
                      .toString();
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
                                        textDirection:
                                            AppLocaleScope.of(context)
                                                .textDirection,
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
                            context,
                            icon: Icons.edit_outlined,
                            title: S.of(context).translate('edit_profile'),
                            subtitle:
                                S.of(context).translate('edit_profile_subtitle'),
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
                            context,
                            icon: Icons.language_rounded,
                            title: S.of(context).translate('language'),
                            subtitle: AppLocaleScope.of(context)
                                    .selectedLanguage
                                    ?.nativeTitle ??
                                '—',
                            onTap: () => _showLanguageSheet(context),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          _tile(
                            context,
                            icon: Icons.info_outline_rounded,
                            title: S.of(context).translate('about_app'),
                            subtitle:
                                S.of(context).translate('about_app_subtitle'),
                            onTap: () => _showAbout(context),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          _tile(
                            context,
                            icon: Icons.logout_rounded,
                            title: S.of(context).translate('logout'),
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

Widget _tile(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? subtitle,
  Color? iconColor,
  Color? titleColor,
  required VoidCallback onTap,
}) {
  final rtl = Directionality.of(context) == TextDirection.rtl;
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
    trailing: Icon(
      rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      color: const Color(0xFF627D98),
      size: 22,
    ),
    onTap: onTap,
  );
}
