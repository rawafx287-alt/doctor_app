import 'dart:math' show pi;

import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../locale/language_picker.dart';
import '../theme/patient_premium_theme.dart';
import '../locale/hr_nora_about_dialog.dart';
import 'patient_edit_profile_screen.dart';

/// Profile page: very soft sky → white (depth; distinct from home shell if needed).
const Color _kProfileSkyTop = Color(0xFFE3F2FD);
const Color _kProfileSkyBottom = Color(0xFFFFFFFF);
const Color _kDoctorNameNavy = Color(0xFF0D2137);
const Color _kPremiumDeepBlue = Color(0xFF1A237E);
const Color _kMutedGrey = Color(0xFF546E7A);
const Color _kLogoutRedDeep = Color(0xFFC62828);
const Color _kLogoutRedSoft = Color(0xFFE57373);

/// Same silver stroke as home doctor cards ([PatientDoctorCard]).
const Color _kProfileSilverBorder = Color(0xFFD1D1D1);
const double _kProfileSilverBorderWidth = 0.8;

/// Emerald for primary menu row icons (badge, translate, sparkle).
const Color _kProfileMenuEmerald = Color(0xFF1B4332);

/// Avatar ring: deep forest green + classic gold ([SweepGradient] ring, not [Border.all]).
const Color _kAvatarRingGreen = Color(0xFF1B4332);
const Color _kAvatarRingGold = Color(0xFFD4AF37);
const double _kAvatarRingWidth = 2.5;
const double _kAvatarInnerDiameter = 78;

/// Navy chevron (leading edge, LTR).
const Color _kProfileChevronNavy = Color(0xFF0D2137);

/// Thin divider between separate glass menu rows.
const Color _kProfileMenuDivider = Color(0x1A000000);

/// Very light frosted blur over the gradient (sigma).
const double _kProfileGlassBlurSigma = 10;

/// Semi-transparent white glass fill + silver outline (glassmorphism).
BoxDecoration _profilePremiumGlassDecoration(double borderRadius) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: _kProfileSilverBorder,
      width: _kProfileSilverBorderWidth,
    ),
  );
}

Widget _profileBlurredPanel({
  required double borderRadius,
  required Decoration decoration,
  required Widget child,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _kProfileGlassBlurSigma,
              sigmaY: _kProfileGlassBlurSigma,
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x00000000)),
            ),
          ),
        ),
        DecoratedBox(
          decoration: decoration,
          child: child,
        ),
      ],
    ),
  );
}

/// Profile photo: green–gold gradient ring (2.5), subtle glow + inner depth, verified badge.
class _ProfileHeaderAvatar extends StatelessWidget {
  const _ProfileHeaderAvatar();

  @override
  Widget build(BuildContext context) {
    final outer = _kAvatarInnerDiameter + 2 * _kAvatarRingWidth;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                center: Alignment.center,
                startAngle: -pi / 2,
                endAngle: 1.5 * pi,
                colors: const [
                  _kAvatarRingGreen,
                  _kAvatarRingGold,
                  _kAvatarRingGreen,
                  _kAvatarRingGold,
                  _kAvatarRingGreen,
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kAvatarRingGreen.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: _kAvatarRingGold.withValues(alpha: 0.16),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(_kAvatarRingWidth),
            child: ClipOval(
              child: SizedBox(
                width: _kAvatarInnerDiameter,
                height: _kAvatarInnerDiameter,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.88),
                            Colors.white.withValues(alpha: 0.52),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: _kPremiumDeepBlue,
                          size: 32,
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.95,
                            colors: [
                              Colors.transparent,
                              _kAvatarRingGreen.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.075),
                            ],
                            stops: const [0.58, 0.88, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8C76A),
                    _kAvatarRingGold,
                    Color(0xFFB8962E),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.25,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kAvatarRingGold.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 12,
                color: _kAvatarRingGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Patient profile tab: glass header + mini glass tiles; logout uses [performAppLogout].
class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  bool _isProfileEmpty(Map<String, dynamic>? data, User user) {
    final d = data ?? const <String, dynamic>{};
    final name = (d['fullName'] ?? '').toString().trim();
    final phone = (d['phone'] ?? '').toString().trim();
    final emailFromDoc = (d['email'] ?? '').toString().trim();
    final authEmail = (user.email ?? '').trim();
    return name.isEmpty && phone.isEmpty && emailFromDoc.isEmpty && authEmail.isEmpty;
  }

  Widget _buildCompleteProfileState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تکایە زانیارییەکانی پرۆفایلت تەواو بکە',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kMutedGrey,
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PatientEditProfileScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text(
                'تەواوکردنی پرۆفایل',
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Non-scroll body: compact header + tiles; caller adds [Expanded] + logout.
  Widget _buildProfileMainContent(
    BuildContext context, {
    required User user,
    required Map<String, dynamic>? data,
  }) {
    final name =
        (data?['fullName'] ?? S.of(context).translate('patient_default'))
            .toString();
    final phone = (data?['phone'] ?? '').toString().trim();
    final emailFromDoc = (data?['email'] ?? '').toString().trim();
    final authEmail = user.email?.trim() ?? '';
    final email = emailFromDoc.isNotEmpty
        ? emailFromDoc
        : (authEmail.isNotEmpty ? authEmail : '—');

    if (_isProfileEmpty(data, user)) {
      return Center(child: _buildCompleteProfileState(context));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileGlassHeader(
          name: name,
          email: email,
          phone: phone,
        ),
        const SizedBox(height: 12),
        _GlassSettingsTile(
          icon: Icons.badge_outlined,
          title: 'زانیارییە کەسییەکان',
          subtitle: 'زانیارییەکان تەنها بۆ بینینە',
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PatientEditProfileScreen(),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: _kProfileMenuDivider,
            indent: 8,
            endIndent: 8,
          ),
        ),
        _GlassSettingsTile(
          icon: Icons.translate_rounded,
          title: S.of(context).translate('language'),
          subtitle: AppLocaleScope.of(context).selectedLanguage?.nativeTitle ??
              '—',
          onTap: () => _showLanguageSheet(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: _kProfileMenuDivider,
            indent: 8,
            endIndent: 8,
          ),
        ),
        _GlassSettingsTile(
          icon: Icons.auto_awesome_outlined,
          title: S.of(context).translate('about_app'),
          subtitle: S.of(context).translate('about_app_subtitle'),
          onTap: () => _showAbout(context),
        ),
      ],
    );
  }

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
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kProfileSkyTop, _kProfileSkyBottom],
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              initialData: FirebaseAuth.instance.currentUser,
              builder: (context, authSnap) {
                final user = authSnap.data ?? FirebaseAuth.instance.currentUser;
                if (authSnap.connectionState == ConnectionState.waiting &&
                    user == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                  );
                }
                if (user == null) {
                  return Center(
                    child: Text(
                      S.of(context).translate('profile_guest'),
                      style: const TextStyle(
                        color: _kMutedGrey,
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                debugPrint('Fetching data for UID: ${user.uid}');
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid.trim())
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF42A5F5)),
                      );
                    }
                    final data = snap.data?.data();
                    final empty = _isProfileEmpty(data, user);
                    return Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4 + bottomPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildProfileMainContent(
                              context,
                              user: user,
                              data: data,
                            ),
                          ),
                          if (!empty) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: _ProfileLogoutButton(
                                label: S.of(context).translate('logout'),
                                onPressed: () => _logout(context),
                              ),
                            ),
                          ],
                        ],
                      ),
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

class _ProfileGlassHeader extends StatelessWidget {
  const _ProfileGlassHeader({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final textDir = AppLocaleScope.of(context).textDirection;
    const headerRadius = 20.0;
    return _profileBlurredPanel(
      borderRadius: headerRadius,
      decoration: _profilePremiumGlassDecoration(headerRadius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _ProfileHeaderAvatar(),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kDoctorNameNavy,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                fontFamily: kPatientPrimaryFont,
                height: 1.12,
                letterSpacing: 0.15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              textDirection: textDir,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.alternate_email_rounded,
                  size: 18,
                  color: _kProfileMenuEmerald,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    email,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _kMutedGrey.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              textDirection: textDir,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  size: 18,
                  color: _kProfileMenuEmerald,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    phone.isEmpty ? '—' : phone,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kMutedGrey.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chevron on physical left (LTR row); emerald icons in fixed width for alignment.
class _GlassSettingsTile extends StatelessWidget {
  const _GlassSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const double _iconColWidth = 40;
  static const double _chevronColWidth = 32;
  static const double _iconSize = 24;

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textDir = AppLocaleScope.of(context).textDirection;
    const tileRadius = 16.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tileRadius),
        child: _profileBlurredPanel(
          borderRadius: tileRadius,
          decoration: _profilePremiumGlassDecoration(tileRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                const SizedBox(
                  width: _chevronColWidth,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _kProfileChevronNavy,
                    size: 22,
                  ),
                ),
                SizedBox(
                  width: _iconColWidth,
                  child: Center(
                    child: Icon(
                      icon,
                      color: _kProfileMenuEmerald,
                      size: _iconSize,
                    ),
                  ),
                ),
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
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: _kMutedGrey.withValues(alpha: 0.92),
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            height: 1.22,
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

class _ProfileLogoutButton extends StatelessWidget {
  const _ProfileLogoutButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = _kLogoutRedSoft.withValues(alpha: 0.85);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _kLogoutRedDeep.withValues(alpha: 0.22),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kLogoutRedDeep,
          side: BorderSide(color: borderColor, width: 1.35),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.35),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.logout_rounded,
              color: _kLogoutRedDeep.withValues(alpha: 0.92),
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
