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
import '../firestore/firestore_cache_helpers.dart';
import '../specialty_categories.dart';
import '../theme/staff_premium_theme.dart';
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

String _phoneDisplay(Map<String, dynamic>? data, User? user) {
  final fromDoc = _firstNonEmptyField(data, [
    'phone',
    'phoneNumber',
    'mobile',
    'phone_number',
  ]);
  final authPhone = (user?.phoneNumber ?? '').trim();
  if (fromDoc.isNotEmpty) return fromDoc;
  if (authPhone.isNotEmpty) return authPhone;
  return '—';
}

bool _userCanUseEmailPassword(User? user) {
  final email = user?.email?.trim() ?? '';
  if (email.isEmpty) return false;
  for (final p in user!.providerData) {
    if (p.providerId == 'password') return true;
  }
  return false;
}

Future<void> _showDoctorChangePasswordDialog(BuildContext context) async {
  final s = S.of(context);
  final user = FirebaseAuth.instance.currentUser;
  if (!_userCanUseEmailPassword(user)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.translate('doctor_profile_password_requires_email'),
          style: const TextStyle(fontFamily: kPatientPrimaryFont),
        ),
      ),
    );
    return;
  }

  final authUser = user!;
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();

  try {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: Text(
                s.translate('doctor_profile_change_password_title'),
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: current,
                      obscureText: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: kPatientPrimaryFont,
                      ),
                      decoration: InputDecoration(
                        labelText: s.translate('doctor_profile_password_current'),
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontFamily: kPatientPrimaryFont,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: next,
                      obscureText: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: kPatientPrimaryFont,
                      ),
                      decoration: InputDecoration(
                        labelText: s.translate('doctor_profile_password_new'),
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontFamily: kPatientPrimaryFont,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirm,
                      obscureText: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: kPatientPrimaryFont,
                      ),
                      decoration: InputDecoration(
                        labelText: s.translate('doctor_profile_password_confirm'),
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontFamily: kPatientPrimaryFont,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: Text(
                    s.translate('action_cancel'),
                    style: const TextStyle(fontFamily: kPatientPrimaryFont),
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final pw = current.text;
                          final n1 = next.text;
                          final n2 = confirm.text;
                          if (n1.length < 6) return;
                          if (n1 != n2) return;
                          setLocal(() => busy = true);
                          try {
                            final cred = EmailAuthProvider.credential(
                              email: authUser.email!,
                              password: pw,
                            );
                            await authUser.reauthenticateWithCredential(cred);
                            await authUser.updatePassword(n1);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    s.translate(
                                      'doctor_profile_password_change_success',
                                    ),
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                    ),
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            setLocal(() => busy = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    s.translate(
                                      'doctor_profile_password_change_failed',
                                    ),
                                    style: const TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kStaffLuxGold,
                          ),
                        )
                      : Text(
                          s.translate('doctor_profile_password_save'),
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            color: kStaffLuxGold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    current.dispose();
    next.dispose();
    confirm.dispose();
  }
}

Future<void> _sendDoctorPasswordReset(
  BuildContext context,
  String email,
) async {
  final s = S.of(context);
  final trimmed = email.trim();
  if (trimmed.isEmpty || trimmed == '—' || !trimmed.contains('@')) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.translate('doctor_profile_password_requires_email'),
          style: const TextStyle(fontFamily: kPatientPrimaryFont),
        ),
      ),
    );
    return;
  }
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: trimmed);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('doctor_profile_password_reset_sent'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('doctor_profile_password_change_failed'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    }
  }
}

void _openDoctorSecuritySheet(
  BuildContext context, {
  required String email,
  required String phone,
}) {
  final rootContext = context;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _DoctorSecurityAccountSheet(
        email: email,
        phone: phone,
        onChangePassword: () {
          Navigator.of(sheetContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (rootContext.mounted) {
              _showDoctorChangePasswordDialog(rootContext);
            }
          });
        },
        onForgotPassword: () {
          Navigator.of(sheetContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (rootContext.mounted) {
              _sendDoctorPasswordReset(rootContext, email);
            }
          });
        },
      );
    },
  );
}

/// Doctor profile tab: premium gold/navy layout, glass menu rows, subtle logout.
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
          // کەمکردنەوەی "Read": پروفایل/ڕێکخستن زۆرجار پێویست بە ریل‌تایم ناکات.
          // سەرەتا cache-first `.get()` بەکاربهێنە.
          final ref = FirebaseFirestore.instance.collection('users').doc(uid);
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: getDocCacheFirst(ref),
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
              final phone = _phoneDisplay(data, user);
              final photoUrl = (data?['profileImageUrl'] ?? '')
                  .toString()
                  .trim();

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _DoctorProfileHeaderCard(
                                      name: name,
                                      hospital: hospital,
                                      specialtyLabel:
                                          s.translate('field_specialty'),
                                      specialtyValue: specialtyDisplay,
                                      clinicLabel: s.translate(
                                        'doctor_profile_location',
                                      ),
                                      clinicValue:
                                          city.isEmpty ? '—' : city,
                                      photoUrl: photoUrl,
                                    ),
                                    const SizedBox(height: 6),
                                    _DoctorProfileGlassMenuTile(
                                      dense: true,
                                      icon: Icons.edit_outlined,
                                      title: s.translate(
                                        'doctor_profile_tile_edit',
                                      ),
                                      subtitle: s.translate(
                                        'doctor_profile_tile_edit_sub',
                                      ),
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
                                    const SizedBox(height: 5),
                                    _DoctorProfileGlassMenuTile(
                                      dense: true,
                                      icon: Icons.shield_outlined,
                                      title: s.translate(
                                        'doctor_profile_security_section_title',
                                      ),
                                      subtitle: s.translate(
                                        'doctor_profile_security_tile_sub',
                                      ),
                                      onTap: () => _openDoctorSecuritySheet(
                                        context,
                                        email: email,
                                        phone: phone,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    _DoctorProfileGlassMenuTile(
                                      dense: true,
                                      icon: Icons.language_rounded,
                                      title: s.translate('language'),
                                      subtitle:
                                          AppLocaleScope.of(context)
                                              .selectedLanguage
                                              ?.nativeTitle ??
                                          '—',
                                      onTap: () =>
                                          _showLanguageSheet(context),
                                    ),
                                    const SizedBox(height: 5),
                                    _DoctorProfileGlassMenuTile(
                                      dense: true,
                                      icon: Icons.info_outline_rounded,
                                      title: s.translate('about_app'),
                                      subtitle:
                                          s.translate('about_app_subtitle'),
                                      onTap: () => _showAbout(context),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: _DoctorLogoutButton(
                          label: s.translate('logout'),
                          onPressed: () => _logout(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Header: avatar + professional name (solid tone, authority cue — no gradient text).
class _DoctorProfileHeaderCard extends StatelessWidget {
  const _DoctorProfileHeaderCard({
    required this.name,
    required this.hospital,
    required this.specialtyLabel,
    required this.specialtyValue,
    required this.clinicLabel,
    required this.clinicValue,
    required this.photoUrl,
  });

  final String name;
  final String hospital;
  final String specialtyLabel;
  final String specialtyValue;
  final String clinicLabel;
  final String clinicValue;
  final String photoUrl;

  static const double _avatarOuter = 92;
  static const double _goldRing = 4;

  static const Color _kNameSoftIvory = Color(0xFFF7F4ED);

  @override
  Widget build(BuildContext context) {
    final textDir = AppLocaleScope.of(context).textDirection;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: kStaffSilverBorder,
              width: kStaffCardOutlineWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 5),
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
                        color: kStaffLuxGold.withValues(alpha: 0.48),
                        blurRadius: 16,
                        spreadRadius: 0.5,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: kStaffShellGradientTop,
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
              Row(
                textDirection: textDir,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 19,
                    color: kStaffLuxGold.withValues(alpha: 0.88),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 1.12,
                        letterSpacing: 0.65,
                        color: _kNameSoftIvory,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.32),
                            blurRadius: 5,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                      size: 15,
                      color: kStaffLuxGold,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        hospital,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: const Color(0xFFE8F4F0)
                              .withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Divider(
                height: 1,
                thickness: 0.75,
                color: kStaffSilverBorder.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 6),
              _InfoChipRow(
                textDirection: textDir,
                icon: Icons.workspace_premium_rounded,
                label: specialtyLabel,
                value: specialtyValue,
                compact: true,
              ),
              const SizedBox(height: 4),
              _InfoChipRow(
                textDirection: textDir,
                icon: Icons.apartment_rounded,
                label: clinicLabel,
                value: clinicValue,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _avatarPlaceholder() {
    return ColoredBox(
      color: kStaffShellGradientMid,
      child: const Center(
        child: Icon(Icons.person_rounded, size: 40, color: kStaffLuxGold),
      ),
    );
  }
}

/// Bottom sheet: email, phone, password actions (main profile stays compact).
class _DoctorSecurityAccountSheet extends StatelessWidget {
  const _DoctorSecurityAccountSheet({
    required this.email,
    required this.phone,
    required this.onChangePassword,
    required this.onForgotPassword,
  });

  final String email;
  final String phone;
  final VoidCallback onChangePassword;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    Widget line(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: AppLocaleScope.of(context).textDirection,
          children: [
            Icon(icon, size: 20, color: kStaffLuxGold.withValues(alpha: 0.9)),
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
                      fontSize: 11,
                      color: _kDoctorProfileSubtitle.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    value,
                    style: const TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xE8121827),
              border: Border.all(color: kStaffSilverBorder.withValues(alpha: 0.5)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 14 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      s.translate('doctor_profile_security_section_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: Colors.white,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const SizedBox(height: 16),
                    line(
                      Icons.alternate_email_rounded,
                      s.translate('doctor_profile_security_email_label'),
                      email,
                    ),
                    line(
                      Icons.phone_iphone_rounded,
                      s.translate('doctor_profile_security_phone_label'),
                      phone,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onChangePassword,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kStaffLuxGold,
                              side: BorderSide(
                                color: kStaffLuxGold.withValues(alpha: 0.75),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              s.translate('doctor_profile_change_password'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onForgotPassword,
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Colors.white.withValues(alpha: 0.92),
                              side: BorderSide(
                                color: kStaffSilverBorder
                                    .withValues(alpha: 0.85),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              s.translate('doctor_profile_forgot_password'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _InfoChipRow extends StatelessWidget {
  const _InfoChipRow({
    required this.textDirection,
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final TextDirection textDirection;
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 16.0 : 19.0;
    final labelSize = compact ? 9.5 : 10.5;
    final valueSize = compact ? 12.5 : 14.0;
    return Row(
      textDirection: textDirection,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: compact ? 0.5 : 1),
          child: Icon(icon, size: iconSize, color: kStaffLuxGold),
        ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: labelSize,
                  color: _kDoctorProfileSubtitle.withValues(alpha: 0.9),
                  letterSpacing: compact ? 0.12 : 0.15,
                ),
              ),
              SizedBox(height: compact ? 1 : 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                  fontSize: valueSize,
                  color: Colors.white,
                  height: 1.15,
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
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final radius = dense ? 14.0 : 16.0;
    final hPad = dense ? 11.0 : 14.0;
    final vPad = dense ? 9.0 : 14.0;
    final iconSize = dense ? 22.0 : 26.0;
    final gap = dense ? 10.0 : 14.0;
    final titleSize = dense ? 14.5 : 16.0;
    final subSize = dense ? 11.0 : 12.5;
    final chev = dense ? 21.0 : 24.0;
    final strip = dense ? 3.0 : 4.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: kStaffSilverBorder,
                  width: kStaffCardOutlineWidth,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: strip, color: kStaffAccentSlateBlue),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: hPad,
                          vertical: vPad,
                        ),
                        child: Row(
                          textDirection: TextDirection.ltr,
                          children: [
                            Icon(icon, color: kStaffLuxGold, size: iconSize),
                            SizedBox(width: gap),
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
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w800,
                                        fontSize: titleSize,
                                        color: Colors.white,
                                        height: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: dense ? 2 : 4),
                                    Text(
                                      subtitle,
                                      maxLines: dense ? 1 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w600,
                                        fontSize: subSize,
                                        color: _kDoctorProfileSubtitle
                                            .withValues(alpha: 0.92),
                                        height: 1.2,
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
                              size: chev,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168, minHeight: 36),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.72),
          side: BorderSide(
            color: kStaffLuxGold.withValues(alpha: 0.32),
            width: 1,
          ),
          backgroundColor: Colors.black.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.15,
          ),
        ),
      ),
    );
  }
}
