import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/app_logout.dart';
import '../auth/firestore_user_doc_id.dart';
import '../auth/patient_session_cache.dart';
import '../auth/phone_auth_config.dart';
import '../auth/phone_normalization.dart';
import '../firestore/appointment_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../locale/hr_nora_about_dialog.dart';
import '../locale/language_picker.dart';
import '../patient/patient_edit_profile_screen.dart';

/// Light shell palette: soft blue, white, gray (patient profile tab in main nav).
const Color _kProfileBgTop = Color(0xFFE8F2FC);
const Color _kProfileBgBottom = Color(0xFFFFFFFF);
const Color _kProfileCard = Color(0xFFFFFFFF);
const Color _kProfileTextPrimary = Color(0xFF1A2B3D);
const Color _kProfileTextMuted = Color(0xFF64748B);
const Color _kProfileBorder = Color(0xFFE2E8F0);
const String _kProfileFont = 'NRT';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Set<String> _patientIdsForQueries(User user) {
    final phoneIds = <String>{};
    final authPhone = normalizePhoneDigits((user.phoneNumber ?? '').trim());
    if (authPhone.isNotEmpty) phoneIds.add(authPhone);
    final email = (user.email ?? '').trim();
    if (email.endsWith('@$kPhoneAuthEmailDomain')) {
      final p = normalizePhoneDigits(email.split('@').first);
      if (p.isNotEmpty) phoneIds.add(p);
    }
    final ids = <String>{
      user.uid.trim(),
      firestoreUserDocId(user).trim(),
      ...phoneIds,
    };
    ids.removeWhere((e) => e.isEmpty);
    return ids;
  }

  Future<Set<String>> _resolvePatientIds(User user) async {
    final ids = <String>{};
    final cached = (await PatientSessionCache.readPatientRefId() ?? '').trim();
    if (cached.isNotEmpty) ids.add(cached);
    ids.addAll(_patientIdsForQueries(user));
    ids.removeWhere((e) => e.isEmpty);
    return ids;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _watchAppointmentsForPatientIds(Set<String> ids) {
    final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    for (final id in ids) {
      streams.add(
        FirebaseFirestore.instance
            .collection(AppointmentFields.collection)
            .where(AppointmentFields.patientId, isEqualTo: id)
            .snapshots(),
      );
      streams.add(
        FirebaseFirestore.instance
            .collection(AppointmentFields.collection)
            .where(AppointmentFields.userId, isEqualTo: id)
            .snapshots(),
      );
    }

    return Stream.multi((controller) {
      final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
        streams.length,
        null,
      );
      void emitMerged() {
        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final snap in latest) {
          for (final d in snap?.docs ?? const []) {
            byId[d.id] = d;
          }
        }
        controller.add(byId.values.toList());
      }

      final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      for (var i = 0; i < streams.length; i++) {
        subs.add(
          streams[i].listen((event) {
            latest[i] = event;
            emitMerged();
          }, onError: controller.addError),
        );
      }
      controller.onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    });
  }

  int? _ageFromUserData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['dateOfBirth'];
    DateTime? d;
    if (raw is Timestamp) {
      d = raw.toDate();
    } else if (raw is DateTime) {
      d = raw;
    }
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month ||
        (now.month == d.month && now.day < d.day)) {
      age--;
    }
    return age < 0 || age > 130 ? null : age;
  }

  String _bloodFromUserData(Map<String, dynamic>? data) {
    if (data == null) return '';
    final b = (data['bloodGroup'] ?? data['blood'] ?? '').toString().trim();
    return b;
  }

  String _displayName(Map<String, dynamic>? data, AppLocalizations loc) {
    if (data == null) return loc.translate('patient_default');
    final n = (data['fullName_ku'] ?? data['fullName'] ?? '').toString().trim();
    return n.isEmpty ? loc.translate('patient_default') : n;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dir = AppLocaleScope.of(context).textDirection;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: dir,
      child: Scaffold(
        backgroundColor: _kProfileBgBottom,
        appBar: AppBar(
          title: Text(
            s.translate('profile_screen_title'),
            style: const TextStyle(
              fontFamily: _kProfileFont,
              fontWeight: FontWeight.w700,
              color: _kProfileTextPrimary,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: _kProfileTextPrimary,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kProfileBgTop, _kProfileBgBottom],
            ),
          ),
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, authSnap) {
              final user = authSnap.data ?? FirebaseAuth.instance.currentUser;
              if (user == null) {
                return Center(
                  child: Text(
                    s.translate('profile_guest'),
                    style: const TextStyle(
                      fontFamily: _kProfileFont,
                      color: _kProfileTextMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final docId = firestoreUserDocId(user).trim().isNotEmpty
                  ? firestoreUserDocId(user).trim()
                  : user.uid.trim();

              return FutureBuilder<Set<String>>(
                future: _resolvePatientIds(user),
                builder: (context, idsSnap) {
                  final patientIds = idsSnap.data ??
                      _patientIdsForQueries(user);

                  return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    stream: _watchAppointmentsForPatientIds(patientIds),
                    builder: (context, apptSnap) {
                      final apptCount = apptSnap.hasData
                          ? apptSnap.data!.length
                          : 0;

                      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(docId)
                            .snapshots(),
                        builder: (context, userDocSnap) {
                          final data = userDocSnap.data?.data();
                          final name = _displayName(data, s);
                          final age = _ageFromUserData(data);
                          final blood = _bloodFromUserData(data);
                          final photoUrl =
                              (data?['profileImageUrl'] ?? '').toString().trim();

                          return ListView(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              8,
                              20,
                              24 + bottomPad,
                            ),
                            children: [
                              Center(
                                child: _ProfileAvatar(
                                  imageUrl: photoUrl,
                                  onEditPhoto: () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const PatientEditProfileScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: _kProfileFont,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  color: _kProfileTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _StatsRow(
                                ageLabel: s.translate('profile_stat_age'),
                                ageDisplay: age != null ? '$age' : null,
                                bloodLabel: s.translate('profile_stat_blood'),
                                bloodValue: blood.isNotEmpty
                                    ? blood
                                    : s.translate('profile_stat_not_set'),
                                apptLabel:
                                    s.translate('profile_stat_appointments'),
                                apptValue: '$apptCount',
                              ),
                              const SizedBox(height: 28),
                              _ProfileMenuCard(
                                icon: Icons.badge_rounded,
                                iconColor: const Color(0xFF2563EB),
                                iconBg: const Color(0xFFEFF6FF),
                                title: s.translate('profile_personal_info'),
                                onTap: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const PatientEditProfileScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _ProfileMenuCard(
                                icon: Icons.translate_rounded,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                                title: s.translate('language'),
                                subtitle: AppLocaleScope.of(context)
                                        .selectedLanguage
                                        ?.nativeTitle ??
                                    s.translate('profile_stat_not_set'),
                                onTap: () => showHrNoraLanguagePicker(context),
                              ),
                              const SizedBox(height: 12),
                              _ProfileMenuCard(
                                icon: Icons.auto_awesome_rounded,
                                iconColor: const Color(0xFF7C3AED),
                                iconBg: const Color(0xFFF5F3FF),
                                title: s.translate('about_app'),
                                subtitle:
                                    s.translate('about_app_subtitle'),
                                onTap: () => showHrNoraAboutDialog(context),
                              ),
                              const SizedBox(height: 20),
                              _ProfileMenuCard(
                                icon: Icons.logout_rounded,
                                iconColor: const Color(0xFFDC2626),
                                iconBg: const Color(0xFFFEF2F2),
                                title: s.translate('profile_logout'),
                                showChevron: false,
                                onTap: () => performAppLogout(context),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.onEditPhoto,
  });

  final String imageUrl;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    const double radius = 52;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: radius * 2 + 6,
          height: radius * 2 + 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _kProfileCard,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: ClipOval(
                child: imageUrl.isEmpty
                    ? Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 56,
                          color: _kProfileTextMuted,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: radius * 2,
                        height: radius * 2,
                        placeholder: (_, _) => const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 56,
                            color: _kProfileTextMuted,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Material(
            color: const Color(0xFF2563EB),
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEditPhoto,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.ageLabel,
    required this.ageDisplay,
    required this.bloodLabel,
    required this.bloodValue,
    required this.apptLabel,
    required this.apptValue,
  });

  final String ageLabel;
  final String? ageDisplay;
  final String bloodLabel;
  final String bloodValue;
  final String apptLabel;
  final String apptValue;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ageText = ageDisplay ?? s.translate('profile_stat_not_set');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: _kProfileCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kProfileBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              icon: Icons.cake_outlined,
              iconColor: const Color(0xFF0284C7),
              label: ageLabel,
              value: ageText,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: _kProfileBorder,
          ),
          Expanded(
            child: _StatCell(
              icon: Icons.bloodtype_rounded,
              iconColor: const Color(0xFFDC2626),
              label: bloodLabel,
              value: bloodValue,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: _kProfileBorder,
          ),
          Expanded(
            child: _StatCell(
              icon: Icons.event_available_outlined,
              iconColor: const Color(0xFF059669),
              label: apptLabel,
              value: apptValue,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: _kProfileFont,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kProfileTextMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: _kProfileFont,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _kProfileTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _kProfileCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kProfileBorder.withValues(alpha: 0.65)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: _kProfileFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kProfileTextPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: _kProfileFont,
                            fontSize: 13,
                            color: _kProfileTextMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 22,
                    color: _kProfileTextMuted.withValues(alpha: 0.55),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
