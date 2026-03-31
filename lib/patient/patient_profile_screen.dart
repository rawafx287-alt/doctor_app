import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../locale/language_picker.dart';
import '../theme/patient_premium_theme.dart';
import 'patient_edit_profile_screen.dart';

/// Matches [PatientHomeScreen] shell.
const Color _kSkyTop = kPatientSkyTop;
const Color _kSkyBottom = kPatientSkyBottom;
const Color _kDoctorNameNavy = Color(0xFF0D2137);
const Color _kPremiumDeepBlue = Color(0xFF1A237E);
const Color _kChevronLightBlue = Color(0xFF90CAF9);
const Color _kMutedGrey = Color(0xFF546E7A);
const Color _kLogoutRedDeep = Color(0xFFC62828);

/// Patient profile tab: glass header + mini glass tiles; logout uses [performAppLogout].
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
          color: const Color(0xFF00838F).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.medical_services_rounded,
          color: Color(0xFF00838F),
          size: 32,
        ),
      ),
      children: [
        Directionality(
          textDirection: AppLocaleScope.of(context).textDirection,
          child: Text(
            S.of(context).translate('about_description'),
            style: const TextStyle(
              color: Color(0xFF666666),
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
    final user = FirebaseAuth.instance.currentUser;
    final docId = firestoreUserDocId(user);

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kSkyTop, _kSkyBottom],
          ),
        ),
        child: user == null || docId.isEmpty
            ? Center(
                child: Text(
                  S.of(context).translate('profile_guest'),
                  style: const TextStyle(
                    color: _kMutedGrey,
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(docId)
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

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      28 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      switch (index) {
                        case 0:
                          return _ProfileGlassHeader(name: name, email: email);
                        case 1:
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _GlassSettingsTile(
                              icon: Icons.edit_outlined,
                              title: S.of(context).translate('edit_profile'),
                              subtitle: S.of(context)
                                  .translate('edit_profile_subtitle'),
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
                          );
                        case 2:
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _GlassSettingsTile(
                              icon: Icons.language_rounded,
                              title: S.of(context).translate('language'),
                              subtitle: AppLocaleScope.of(context)
                                      .selectedLanguage
                                      ?.nativeTitle ??
                                  '—',
                              onTap: () => _showLanguageSheet(context),
                            ),
                          );
                        case 3:
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _GlassSettingsTile(
                              icon: Icons.info_outline_rounded,
                              title: S.of(context).translate('about_app'),
                              subtitle: S.of(context)
                                  .translate('about_app_subtitle'),
                              onTap: () => _showAbout(context),
                            ),
                          );
                        case 4:
                        default:
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _GlassLogoutTile(
                              title: S.of(context).translate('logout'),
                              onTap: () => _logout(context),
                            ),
                          );
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _ProfileGlassHeader extends StatelessWidget {
  const _ProfileGlassHeader({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final textDir = AppLocaleScope.of(context).textDirection;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: patientFrostedGlassDecoration(borderRadius: 22),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Row(
              textDirection: textDir,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kPremiumDeepBlue.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFF90CAF9).withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white.withValues(alpha: 0.42),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: _kPremiumDeepBlue,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: _kDoctorNameNavy,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'KurdishFont',
                          height: 1.2,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        textDirection: textDir,
                        children: [
                          Icon(
                            Icons.alternate_email_rounded,
                            size: 18,
                            color: _kPremiumDeepBlue.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: _kMutedGrey.withValues(alpha: 0.95),
                                fontSize: 14,
                                fontFamily: 'KurdishFont',
                                fontWeight: FontWeight.w500,
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
          ),
        ),
    );
  }
}

/// Chevron fixed on physical left; content respects app [textDirection].
class _GlassSettingsTile extends StatelessWidget {
  const _GlassSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textDir = AppLocaleScope.of(context).textDirection;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: patientFrostedGlassDecoration(borderRadius: 16),
            child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      color: _kChevronLightBlue,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      icon,
                      color: _kPremiumDeepBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Directionality(
                        textDirection: textDir,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: _kDoctorNameNavy,
                                fontFamily: 'KurdishFont',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: _kMutedGrey.withValues(alpha: 0.92),
                                fontFamily: 'KurdishFont',
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                height: 1.25,
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
        ),
    );
  }
}

class _GlassLogoutTile extends StatelessWidget {
  const _GlassLogoutTile({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFEBEE).withValues(alpha: 0.98),
                  const Color(0xFFFFCDD2).withValues(alpha: 0.45),
                ],
              ),
              border: Border.all(
                color: _kLogoutRedDeep.withValues(alpha: 0.22),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kLogoutRedDeep.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              child: Directionality(
                textDirection: AppLocaleScope.of(context).textDirection,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: _kLogoutRedDeep.withValues(alpha: 0.88),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: TextStyle(
                        color: _kLogoutRedDeep.withValues(alpha: 0.92),
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
