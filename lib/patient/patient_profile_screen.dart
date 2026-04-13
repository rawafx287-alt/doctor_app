import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../locale/hr_nora_about_dialog.dart';
import '../locale/language_picker.dart';
import '../theme/patient_premium_theme.dart';
import 'patient_edit_profile_screen.dart';

const Color _kLuxuryGold = Color(0xFFD4AF37);
const Color _kTitleNavy = Color(0xFF1A237E);
const Color _kBodyMuted = Color(0xFF546E7A);
const Color _kLogoutRed = Color(0xFFC62828);
const Color _kLogoutBg = Color(0xFFFFEBEE);
const Color _kAvatarFill = Color(0xFFF5F5F5);
const String _kEmptyStat = '--';
/// Logout title (fixed copy per product spec).
const String _kLogoutTitleKu = 'چوونەدەرەوە';

String _ageDisplayFromUserDoc(Map<String, dynamic>? data) {
  if (data == null) return _kEmptyStat;
  final explicit = data['ageYears'] ?? data['age'];
  if (explicit is int) return '$explicit';
  if (explicit is num) return '${explicit.round()}';
  final st = explicit?.toString().trim() ?? '';
  if (st.isNotEmpty) {
    final n = int.tryParse(st);
    if (n != null && n >= 1 && n <= 130) return '$n';
  }
  final raw = data['dateOfBirth'];
  DateTime? d;
  if (raw is Timestamp) {
    d = raw.toDate();
  } else if (raw is DateTime) {
    d = raw;
  }
  if (d == null) return _kEmptyStat;
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
    age--;
  }
  if (age < 0 || age > 130) return _kEmptyStat;
  return '$age';
}

String _bloodDisplayFromUserDoc(Map<String, dynamic>? data) {
  if (data == null) return _kEmptyStat;
  final b = (data['bloodGroup'] ?? data['blood'] ?? '').toString().trim();
  return b.isEmpty ? _kEmptyStat : b;
}

/// Patient profile — white cards, home-matched sky scaffold, navy titles, gold accents.
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  bool _isProfileEmpty(Map<String, dynamic>? data, User user) {
    final d = data ?? const <String, dynamic>{};
    final name = (d['fullName'] ?? '').toString().trim();
    final phone = (d['phone'] ?? '').toString().trim();
    final emailFromDoc = (d['email'] ?? '').toString().trim();
    final authEmail = (user.email ?? '').trim();
    return name.isEmpty &&
        phone.isEmpty &&
        emailFromDoc.isEmpty &&
        authEmail.isEmpty;
  }

  Widget _buildCompleteProfileState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 48, color: _kLuxuryGold),
            const SizedBox(height: 20),
            Text(
              'تکایە زانیارییەکانی پرۆفایلت تەواو بکە',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kTitleNavy.withValues(alpha: 0.92),
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: Colors.white,
              elevation: 0,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PatientEditProfileScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kLuxuryGold, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.edit_rounded,
                          color: _kLuxuryGold, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'تەواوکردنی پرۆفایل',
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          color: _kTitleNavy,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBody(
    BuildContext context, {
    required User user,
    required Map<String, dynamic>? data,
    required double maxHeight,
    required double bottomPad,
  }) {
    final loc = S.of(context);
    final name =
        (data?['fullName'] ?? loc.translate('patient_default')).toString();

    if (_isProfileEmpty(data, user)) {
      return _buildCompleteProfileState(context);
    }

    final imageUrl = (data?['profileImageUrl'] ?? '').toString().trim();
    final ageText = _ageDisplayFromUserDoc(data);
    final bloodText = _bloodDisplayFromUserDoc(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight > 0 ? constraints.maxHeight : maxHeight;
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: h),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22, 12, 22, 16 + bottomPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileHeaderCard(
                          name: name,
                          imageUrl: imageUrl,
                          ageText: ageText,
                          bloodText: bloodText,
                          ageLabel: loc.translate('profile_stat_age'),
                          bloodLabel: loc.translate('profile_stat_blood'),
                        ),
                        const SizedBox(height: 22),
                        _ProfileMenuTile(
                          icon: Icons.badge_outlined,
                          title: loc.translate('profile_personal_info'),
                          subtitle: loc.translate('edit_profile_subtitle'),
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
                        const SizedBox(height: 16),
                        _ProfileMenuTile(
                          icon: Icons.language_rounded,
                          title: loc.translate('language'),
                          subtitle: AppLocaleScope.of(context)
                                  .selectedLanguage?.nativeTitle ??
                              _kEmptyStat,
                          onTap: () => showHrNoraLanguagePicker(context),
                        ),
                        const SizedBox(height: 16),
                        _ProfileMenuTile(
                          icon: Icons.auto_awesome_outlined,
                          title: loc.translate('about_app'),
                          subtitle: loc.translate('about_app_subtitle'),
                          onTap: () => showHrNoraAboutDialog(context),
                        ),
                        const SizedBox(height: 16),
                        _ProfileLogoutTile(
                          onTap: () => performAppLogout(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: kPatientSkyTop,
        body: DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: SafeArea(
            bottom: true,
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              initialData: FirebaseAuth.instance.currentUser,
              builder: (context, authSnap) {
                final user = authSnap.data ?? FirebaseAuth.instance.currentUser;
                if (authSnap.connectionState == ConnectionState.waiting &&
                    user == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _kTitleNavy,
                      strokeWidth: 2.5,
                    ),
                  );
                }
                if (user == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        S.of(context).translate('profile_guest'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _kTitleNavy,
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                final docId = firestoreUserDocId(user).trim().isNotEmpty
                    ? firestoreUserDocId(user).trim()
                    : user.uid.trim();

                return LayoutBuilder(
                  builder: (context, outer) {
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(docId)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _kTitleNavy,
                              strokeWidth: 2.5,
                            ),
                          );
                        }
                        final data = snap.data?.data();
                        return _buildProfileBody(
                          context,
                          user: user,
                          data: data,
                          maxHeight: outer.maxHeight,
                          bottomPad: bottomPad,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.imageUrl,
    required this.ageText,
    required this.bloodText,
    required this.ageLabel,
    required this.bloodLabel,
  });

  final String name;
  final String imageUrl;
  final String ageText;
  final String bloodText;
  final String ageLabel;
  final String bloodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kLuxuryGold, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _ProfileAvatar(imageUrl: imageUrl),
          const SizedBox(height: 20),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: _kTitleNavy,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 14),
          _ProfileStatsRow(
            ageLabel: ageLabel,
            ageText: ageText,
            bloodLabel: bloodLabel,
            bloodText: bloodText,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const double r = 46;
    return CircleAvatar(
      radius: r,
      backgroundColor: _kAvatarFill,
      backgroundImage: imageUrl.isNotEmpty
          ? CachedNetworkImageProvider(imageUrl)
          : null,
      onBackgroundImageError: imageUrl.isNotEmpty ? (_, _) {} : null,
      child: imageUrl.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: 48,
              color: _kBodyMuted.withValues(alpha: 0.65),
            )
          : null,
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  const _ProfileStatsRow({
    required this.ageLabel,
    required this.ageText,
    required this.bloodLabel,
    required this.bloodText,
  });

  final String ageLabel;
  final String ageText;
  final String bloodLabel;
  final String bloodText;

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: kPatientPrimaryFont,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: _kBodyMuted,
    height: 1.2,
  );

  static const TextStyle _valueStyle = TextStyle(
    fontFamily: kPatientPrimaryFont,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: _kTitleNavy,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(ageLabel, style: _labelStyle),
        const SizedBox(width: 6),
        Text(ageText, style: _valueStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '·',
            style: TextStyle(
              fontSize: 14,
              color: _kBodyMuted.withValues(alpha: 0.5),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(bloodLabel, style: _labelStyle),
        const SizedBox(width: 6),
        Text(bloodText, style: _valueStyle),
      ],
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
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
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsetsDirectional.only(
              start: 20,
              end: 16,
              top: 12,
              bottom: 12,
            ),
            leading: Icon(icon, color: _kLuxuryGold, size: 26),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: _kTitleNavy,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 13,
                  color: _kBodyMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing: Icon(
              rtl ? Icons.chevron_left : Icons.chevron_right,
              size: 22,
              color: _kBodyMuted.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileLogoutTile extends StatelessWidget {
  const _ProfileLogoutTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _kLogoutBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kLogoutRed.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsetsDirectional.only(
              start: 20,
              end: 16,
              top: 12,
              bottom: 12,
            ),
            leading: const Icon(
              Icons.logout,
              color: _kLogoutRed,
              size: 26,
            ),
            title: const Text(
              _kLogoutTitleKu,
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: _kLogoutRed,
              ),
            ),
            trailing: Icon(
              rtl ? Icons.chevron_left : Icons.chevron_right,
              size: 22,
              color: _kLogoutRed.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
