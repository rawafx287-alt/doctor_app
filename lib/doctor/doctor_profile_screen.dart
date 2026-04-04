import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../locale/hr_nora_about_dialog.dart';
import '../locale/language_picker.dart';
import '../models/doctor_localized_content.dart';
import '../auth/app_logout.dart';
import '../auth/firestore_user_doc_id.dart';
import '../auth/doctor_session_cache.dart';
import '../specialty_categories.dart';
import '../theme/staff_premium_theme.dart';
import 'doctor_premium_shell.dart';
import 'profile_settings_screen.dart';

const Color _kDoctorProfileSubtitle = Color(0xFFC9C4B0);

String _firstNonEmptyField(Map<String, dynamic>? data, List<String> keys) {
  if (data == null) return '';
  for (final k in keys) {
    final t = (data[k] ?? '').toString().trim();
    if (t.isNotEmpty) return t;
  }
  return '';
}

String _hospitalDisplay(Map<String, dynamic>? data) {
  var h = (data?['hospitalName'] ?? '').toString().trim();
  if (h.isEmpty) {
    h = _firstNonEmptyField(data, ['hospital_name_ku', 'clinicName']);
  }
  return h;
}

/// Doctor profile tab: premium gold/navy layout, glass menu rows, outlined logout.
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
    showHrNoraAboutDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
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
              child: CircularProgressIndicator(color: kStaffLuxGold),
            );
          }
          if (uid.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: kStaffLuxGold),
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
                  child: CircularProgressIndicator(color: kStaffLuxGold),
                );
              }
              final data = snap.data?.data();
              final nameRaw = data ?? {};
              var name = localizedDoctorFullName(nameRaw, lang);
              if (name.isEmpty) {
                name = s.translate('doctor_default');
              }
              final specialtyRaw = (data?['specialty'] ?? '—')
                  .toString()
                  .trim();
              final city = (data?['city'] ?? data?['clinicLocation'] ?? '')
                  .toString()
                  .trim();
              final hospital = _hospitalDisplay(data);
              final specialtyDisplay =
                  specialtyRaw.isEmpty || specialtyRaw == '—'
                  ? '—'
                  : translatedSpecialtyForFirestore(context, specialtyRaw);
              final emailFromDoc = (data?['email'] ?? '').toString().trim();
              final authEmail =
                  FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
              final email = emailFromDoc.isNotEmpty
                  ? emailFromDoc
                  : (authEmail.isNotEmpty ? authEmail : '—');
              final photoUrl = (data?['profileImageUrl'] ?? '')
                  .toString()
                  .trim();

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _DoctorProfileHeaderCard(
                    name: name,
                    email: email,
                    hospital: hospital,
                    specialtyLabel: s.translate('field_specialty'),
                    specialtyValue: specialtyDisplay,
                    clinicLabel: s.translate('doctor_profile_location'),
                    clinicValue: city.isEmpty ? '—' : city,
                    photoUrl: photoUrl,
                  ),
                  const SizedBox(height: 12),
                  _DoctorProfileGlassMenuTile(
                    icon: Icons.edit_outlined,
                    title: s.translate('doctor_profile_tile_edit'),
                    subtitle: s.translate('doctor_profile_tile_edit_sub'),
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _DoctorProfileGlassMenuTile(
                    icon: Icons.language_rounded,
                    title: s.translate('language'),
                    subtitle:
                        AppLocaleScope.of(
                          context,
                        ).selectedLanguage?.nativeTitle ??
                        '—',
                    onTap: () => _showLanguageSheet(context),
                  ),
                  const SizedBox(height: 10),
                  _DoctorProfileGlassMenuTile(
                    icon: Icons.info_outline_rounded,
                    title: s.translate('about_app'),
                    subtitle: s.translate('about_app_subtitle'),
                    onTap: () => _showAbout(context),
                  ),
                  const SizedBox(height: 22),
                  _DoctorLogoutButton(
                    label: s.translate('logout'),
                    onPressed: () => _logout(context),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Compact header card: silver border, gold avatar ring, hospital + specialty/clinic rows.
class _DoctorProfileHeaderCard extends StatelessWidget {
  const _DoctorProfileHeaderCard({
    required this.name,
    required this.email,
    required this.hospital,
    required this.specialtyLabel,
    required this.specialtyValue,
    required this.clinicLabel,
    required this.clinicValue,
    required this.photoUrl,
  });

  final String name;
  final String email;
  final String hospital;
  final String specialtyLabel;
  final String specialtyValue;
  final String clinicLabel;
  final String clinicValue;
  final String photoUrl;

  static const double _avatarOuter = 88;
  static const double _goldRing = 2.6;

  @override
  Widget build(BuildContext context) {
    final textDir = AppLocaleScope.of(context).textDirection;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: kStaffSilverBorder,
              width: kStaffCardOutlineWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: _avatarOuter,
                  height: _avatarOuter,
                  padding: const EdgeInsets.all(_goldRing),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: kStaffGoldActionGradient,
                    boxShadow: [
                      BoxShadow(
                        color: kStaffLuxGold.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kDoctorPremiumGradientTop,
                    ),
                    child: ClipOval(
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, _, _) => _avatarPlaceholder(),
                            )
                          : _avatarPlaceholder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              if (hospital.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  textDirection: textDir,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_hospital_rounded,
                      size: 17,
                      color: kStaffLuxGold,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        hospital,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFFE8F4F0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                textDirection: textDir,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.alternate_email_rounded,
                    size: 16,
                    color: kStaffLuxGold.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      email,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: _kDoctorProfileSubtitle.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: kStaffSilverBorder.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 8),
              _InfoChipRow(
                textDirection: textDir,
                icon: Icons.workspace_premium_rounded,
                label: specialtyLabel,
                value: specialtyValue,
              ),
              const SizedBox(height: 7),
              _InfoChipRow(
                textDirection: textDir,
                icon: Icons.apartment_rounded,
                label: clinicLabel,
                value: clinicValue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _avatarPlaceholder() {
    return ColoredBox(
      color: kDoctorPremiumGradientMid,
      child: const Center(
        child: Icon(Icons.person_rounded, size: 38, color: kStaffLuxGold),
      ),
    );
  }
}

class _InfoChipRow extends StatelessWidget {
  const _InfoChipRow({
    required this.textDirection,
    required this.icon,
    required this.label,
    required this.value,
  });

  final TextDirection textDirection;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: textDirection,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 19, color: kStaffLuxGold),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  color: _kDoctorProfileSubtitle.withValues(alpha: 0.9),
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoctorProfileGlassMenuTile extends StatelessWidget {
  const _DoctorProfileGlassMenuTile({
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kStaffSilverBorder,
                  width: kStaffCardOutlineWidth,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: kStaffAccentSlateBlue),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          textDirection: TextDirection.ltr,
                          children: [
                            Icon(icon, color: kStaffLuxGold, size: 26),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Directionality(
                                textDirection: AppLocaleScope.of(
                                  context,
                                ).textDirection,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                        color: _kDoctorProfileSubtitle
                                            .withValues(alpha: 0.92),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Icon(
                              rtl
                                  ? Icons.chevron_left_rounded
                                  : Icons.chevron_right_rounded,
                              color: kStaffLuxGold.withValues(alpha: 0.75),
                              size: 24,
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
      ),
    );
  }
}

class _DoctorLogoutButton extends StatelessWidget {
  const _DoctorLogoutButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StaffGoldGradientButton(
      label: label,
      onPressed: onPressed,
      fontSize: 16,
      borderRadius: 16,
      minHeight: 52,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    );
  }
}
