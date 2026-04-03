import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../locale/language_picker.dart';
import '../models/doctor_localized_content.dart';
import '../auth/app_logout.dart';
import '../auth/firestore_user_doc_id.dart';
import '../auth/doctor_session_cache.dart';
import '../specialty_categories.dart';
import 'profile_settings_screen.dart';

/// Doctor profile tab: name, email, specialty; edit, language, about, logout.
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key, this.doctorUserId});
  final String? doctorUserId;

  Future<void> _logout(BuildContext context) async {
    await performAppLogout(context);
  }

  void _showLanguageSheet(BuildContext context) {
    showHrNoraLanguagePicker(context);
  }

  void _showAbout(BuildContext context) {
    final s = S.of(context);
    showAboutDialog(
      context: context,
      applicationName: s.translate('app_display_name'),
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
            s.translate('doctor_about_description'),
            style: const TextStyle(
              color: Color(0xFF829AB1),
              fontFamily: 'NRT',
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: ColoredBox(
        color: const Color(0xFF0A0E21),
        child: FutureBuilder<String?>(
          future: DoctorSessionCache.readDoctorRefId(),
          builder: (context, cacheSnap) {
            final fallbackUid = firestoreUserDocId(user).trim();
            final fromTab = doctorUserId?.trim() ?? '';
            final cachedUid = (cacheSnap.data ?? '').trim();
            final uid = fromTab.isNotEmpty
                ? fromTab
                : (cachedUid.isNotEmpty ? cachedUid : fallbackUid);
            if (cacheSnap.connectionState == ConnectionState.waiting &&
                uid.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              );
            }
            if (uid.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              );
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                    );
                  }
                  final data = snap.data?.data();
                  final nameRaw = data ?? {};
                  var name = localizedDoctorFullName(nameRaw, lang);
                  if (name.isEmpty) {
                    name = s.translate('doctor_default');
                  }
                  final specialtyRaw =
                      (data?['specialty'] ?? '—').toString().trim();
                  final city = (data?['city'] ?? data?['clinicLocation'] ?? '')
                      .toString()
                      .trim();
                  final specialtyDisplay = specialtyRaw.isEmpty || specialtyRaw == '—'
                      ? '—'
                      : translatedSpecialtyForFirestore(context, specialtyRaw);
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
                                    Icons.medical_services_rounded,
                                    color: Color(0xFF42A5F5),
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        textAlign: TextAlign.start,
                                        style: const TextStyle(
                                          color: Color(0xFFD9E2EC),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'NRT',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        textDirection:
                                            AppLocaleScope.of(context).textDirection,
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
                                              textAlign: TextAlign.start,
                                              style: const TextStyle(
                                                color: Color(0xFF9FB3C8),
                                                fontSize: 14,
                                                fontFamily: 'NRT',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        s.translate('field_specialty'),
                                        textAlign: TextAlign.start,
                                        style: const TextStyle(
                                          color: Color(0xFF627D98),
                                          fontSize: 11,
                                          fontFamily: 'NRT',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        specialtyDisplay,
                                        textAlign: TextAlign.start,
                                        style: const TextStyle(
                                          color: Color(0xFFD9E2EC),
                                          fontSize: 15,
                                          fontFamily: 'NRT',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        textDirection:
                                            AppLocaleScope.of(context).textDirection,
                                        children: [
                                          const Icon(
                                            Icons.location_city_rounded,
                                            size: 18,
                                            color: Color(0xFF627D98),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              city.isEmpty ? '—' : city,
                                              textAlign: TextAlign.start,
                                              style: const TextStyle(
                                                color: Color(0xFF9FB3C8),
                                                fontSize: 14,
                                                fontFamily: 'NRT',
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
                              title: s.translate('doctor_profile_tile_edit'),
                              subtitle: s.translate('doctor_profile_tile_edit_sub'),
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
                              icon: Icons.language_rounded,
                              title: s.translate('language'),
                              subtitle: AppLocaleScope.of(context)
                                      .selectedLanguage
                                      ?.nativeTitle ??
                                  '—',
                              onTap: () => _showLanguageSheet(context),
                            ),
                            const Divider(height: 1, color: Colors.white10),
                            _DoctorProfileTile(
                              icon: Icons.info_outline_rounded,
                              title: s.translate('about_app'),
                              subtitle: s.translate('about_app_subtitle'),
                              onTap: () => _showAbout(context),
                            ),
                            const Divider(height: 1, color: Colors.white10),
                            _DoctorProfileTile(
                              icon: Icons.logout_rounded,
                              title: s.translate('logout'),
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
          fontFamily: 'NRT',
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
                fontFamily: 'NRT',
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
}
