import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/patient_doc_resolver.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../specialty_categories.dart';
import '../theme/patient_premium_theme.dart';
import 'patient_available_days_list.dart';
import 'patient_scroll_physics.dart';

const Color _kDoctorNameNavy = Color(0xFF0D2137);
const Color _kPremiumDeepBlue = Color(0xFF1A237E);
const Color _kBodyGrey = Color(0xFF455A64);
const Color _kGoldDark = Color(0xFF8B6914);
const Color _kGoldMid = Color(0xFFD4AF37);
const Color _kGoldLight = Color(0xFFF6E7A6);
const Color _kGoldShine = Color(0xFFFFE082);
const Color _kGoldBrilliant = Color(0xFFFFD700);

/// Kept for call sites; returns the name exactly as stored (no honorific prefix).
String honorificDoctorDisplayName(String rawName) => rawName.trim();

const LinearGradient _kMetallicGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    _kGoldDark,
    _kGoldMid,
    _kGoldShine,
    _kGoldLight,
    _kGoldMid,
    _kGoldDark,
  ],
  stops: [0.0, 0.22, 0.42, 0.55, 0.78, 1.0],
);

const RadialGradient _kBrilliantGoldRadial = RadialGradient(
  center: Alignment(0, -0.1),
  radius: 1.15,
  colors: [
    _kGoldBrilliant,
    _kGoldShine,
    _kGoldMid,
    Color(0xFFB8860B),
  ],
  stops: [0.0, 0.24, 0.58, 1.0],
);

const RadialGradient _kGoldIconRadial = RadialGradient(
  center: Alignment(0, -0.15),
  radius: 1.1,
  colors: [
    _kGoldBrilliant,
    _kGoldShine,
    _kGoldMid,
    Color(0xFFB8860B),
  ],
  stops: [0.0, 0.2, 0.58, 1.0],
);

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
    required this.doctorData,
    this.showBookingSection = true,
  });

  final String doctorId;
  final Map<String, dynamic> doctorData;

  /// When `false`, only profile (bio, experience, location) — no calendar or book CTA.
  final bool showBookingSection;

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  final GlobalKey _bookingSectionKey = GlobalKey();

  String get _doctorUid => widget.doctorId.trim();

  Widget _ambientBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: const SizedBox.expand(),
        ),
        CustomPaint(
          painter: PatientSubtleGeometricPatternPainter(),
          child: const SizedBox.expand(),
        ),
        CustomPaint(
          painter: _SubtleMedicalGlyphsPainter(),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }

  Widget _sliverAppBar(
    BuildContext context,
    String displayName,
    AppLocalizations s,
  ) {
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 92,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      forceMaterialTransparency: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_forward_ios_rounded),
        color: _kDoctorNameNavy,
        onPressed: () => Navigator.pop(context),
        tooltip: s.translate('tooltip_back'),
      ),
      flexibleSpace: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.14),
                    ],
                  ),
                ),
              ),
            ),
            FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsetsDirectional.only(
                start: 48,
                bottom: 14,
                end: 12,
              ),
              title: Text(
                displayName,
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _kDoctorNameNavy,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goldIconBubble(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _kGoldIconRadial,
        border: Border.all(
          color: _kGoldLight.withValues(alpha: 0.7),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: _kGoldMid.withValues(alpha: 0.46),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: _kDoctorNameNavy, size: 22),
    );
  }

  Widget _profileHeroCard({
    required TextDirection appTextDir,
    required String doctorDisplayName,
    required String mergedSpecialty,
    required String profileImageUrl,
    required BuildContext context,
  }) {
    final s = S.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.72),
                Colors.white.withValues(alpha: 0.42),
                const Color(0xFFFFF8E1).withValues(alpha: 0.28),
              ],
            ),
            border: Border.all(
              color: _kGoldMid.withValues(alpha: 0.75),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: _kGoldMid.withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: _kGoldMid.withValues(alpha: 0.18),
                blurRadius: 40,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            child: Row(
              textDirection: appTextDir,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kGoldMid.withValues(alpha: 0.9),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kGoldMid.withValues(alpha: 0.22),
                        blurRadius: 14,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE3F2FD),
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: profileImageUrl.isNotEmpty
                              ? profileImageUrl
                              : _placeholderImageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 180,
                          memCacheHeight: 180,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFE3F2FD),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFE3F2FD),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.medical_services_rounded,
                              color: Color(0xFF1565C0),
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorDisplayName,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: _kDoctorNameNavy,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          fontFamily: kPatientPrimaryFont,
                          height: 1.15,
                          letterSpacing: 0.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: _kBrilliantGoldRadial,
                            border: Border.all(
                              color: _kGoldLight.withValues(alpha: 0.82),
                              width: 0.9,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _kGoldMid.withValues(alpha: 0.42),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 9,
                            ),
                            child: Text(
                              s.translate(
                                'specialty_colon',
                                params: {
                                  'value': translatedSpecialtyForFirestore(
                                    context,
                                    mergedSpecialty,
                                  ),
                                },
                              ),
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                color: _kDoctorNameNavy,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: kPatientPrimaryFont,
                                height: 1.25,
                                letterSpacing: 0.15,
                                shadows: [
                                  Shadow(
                                    color: Color(0x66FFFFFF),
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.48),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.82),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _kPremiumDeepBlue.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _goldIconBubble(icon),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: _kDoctorNameNavy,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _goldBookButton({
    required BuildContext context,
    required VoidCallback onTap,
  }) {
    final s = S.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: _DoctorDetailsPressableScale(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: _kMetallicGoldGradient,
              border: Border.all(
                color: _kGoldLight.withValues(alpha: 0.65),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kGoldDark.withValues(alpha: 0.42),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: _kGoldMid.withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 18,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    s.translate('book_now'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.25,
                      letterSpacing: 0.2,
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

  List<Widget> _buildGuestSlivers({
    required BuildContext context,
    required String doctorDisplayName,
    required AppLocalizations s,
    required Widget bookingChild,
  }) {
    return [
      _sliverAppBar(context, doctorDisplayName, s),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        sliver: SliverToBoxAdapter(child: bookingChild),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final appTextDir = AppLocaleScope.of(context).textDirection;
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;

    return Directionality(
      textDirection: appTextDir,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _ambientBackground(),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_doctorUid)
                  .snapshots(),
              builder: (context, snap) {
                final merged = <String, dynamic>{
                  ...widget.doctorData,
                  if (snap.data?.data() != null) ...snap.data!.data()!,
                };
                var doctorDisplayName =
                    localizedDoctorFullName(merged, lang);
                if (doctorDisplayName.isEmpty) {
                  doctorDisplayName =
                      (merged['fullName'] ?? s.translate('doctor_default'))
                          .toString();
                }
                doctorDisplayName = doctorDisplayName.trim();
                final mergedSpecialty =
                    (merged['specialty'] ?? '—').toString();
                final profileImageUrl =
                    (merged['profileImageUrl'] ?? '').toString().trim();

                if (user == null) {
                  return CustomScrollView(
                    physics: patientHomePrimaryScrollPhysics,
                    slivers: _buildGuestSlivers(
                      context: context,
                      doctorDisplayName: doctorDisplayName,
                      s: s,
                      bookingChild: PatientAvailableDaysList(
                        doctorId: _doctorUid,
                        patientName: s.translate('patient_default'),
                        doctorDisplayName: doctorDisplayName,
                        mergedDoctorData: merged,
                      ),
                    ),
                  );
                }

                return FutureBuilder<String?>(
                  future: resolvePatientUserDocId(user),
                  builder: (context, idSnap) {
                    if (idSnap.connectionState == ConnectionState.waiting &&
                        !idSnap.hasData) {
                      return CustomScrollView(
                        physics: patientHomePrimaryScrollPhysics,
                        slivers: [
                          _sliverAppBar(context, doctorDisplayName, s),
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF42A5F5),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final pid = (idSnap.data ?? '').trim();
                    if (pid.isEmpty) {
                      return CustomScrollView(
                        physics: patientHomePrimaryScrollPhysics,
                        slivers: _buildGuestSlivers(
                          context: context,
                          doctorDisplayName: doctorDisplayName,
                          s: s,
                          bookingChild: PatientAvailableDaysList(
                            doctorId: _doctorUid,
                            patientName: s.translate('patient_default'),
                            doctorDisplayName: doctorDisplayName,
                            mergedDoctorData: merged,
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(pid)
                          .snapshots(),
                      builder: (context, patientSnap) {
                        final patientWaiting =
                            patientSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !patientSnap.hasData;
                        final patientName = patientWaiting
                            ? s.translate('patient_default')
                            : (patientSnap.data?.data()?['fullName'] ??
                                      s.translate('patient_default'))
                                  .toString();

                        final bio = localizedDoctorField(
                          merged,
                          lang,
                          baseKey: 'bio',
                          legacyKeys: const ['biography', 'about'],
                        );
                        final hospital = localizedDoctorField(
                          merged,
                          lang,
                          baseKey: 'hospital_name',
                          legacyKeys: const ['clinicName', 'hospitalName'],
                        );
                        final address = localizedDoctorField(
                          merged,
                          lang,
                          baseKey: 'address',
                          legacyKeys: const ['clinicAddress'],
                        );
                        var experienceText = localizedDoctorField(
                          merged,
                          lang,
                          baseKey: 'experience',
                          legacyKeys: const [],
                        );
                        if (experienceText.isEmpty) {
                          final rawY = merged['yearsExperience'];
                          int? yi;
                          if (rawY is int) {
                            yi = rawY;
                          } else if (rawY is num) {
                            yi = rawY.toInt();
                          } else {
                            yi = int.tryParse(rawY?.toString() ?? '');
                          }
                          if (yi != null && yi > 0) {
                            experienceText = s.translate(
                              'doctor_experience_years',
                              params: {'years': '$yi'},
                            );
                          }
                        }

                        final bottomInset =
                            MediaQuery.paddingOf(context).bottom;

                        return CustomScrollView(
                          physics: patientHomePrimaryScrollPhysics,
                          slivers: [
                            _sliverAppBar(context, doctorDisplayName, s),
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                24 + bottomInset,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _profileHeroCard(
                                      appTextDir: appTextDir,
                                      doctorDisplayName: doctorDisplayName,
                                      mergedSpecialty: mergedSpecialty,
                                      profileImageUrl: profileImageUrl,
                                      context: context,
                                    ),
                                    if (bio.isNotEmpty) ...[
                                      const SizedBox(height: 18),
                                      _glassInfoCard(
                                        icon: Icons.health_and_safety_rounded,
                                        title: s.translate(
                                          'doctor_profile_about',
                                        ),
                                        children: [
                                          Text(
                                            bio,
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              color: _kBodyGrey.withValues(
                                                alpha: 0.95,
                                              ),
                                              fontSize: 15,
                                              fontFamily: 'KurdishFont',
                                              fontWeight: FontWeight.w500,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (experienceText.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _glassInfoCard(
                                        icon: Icons.workspace_premium_rounded,
                                        title: s.translate(
                                          'doctor_profile_experience',
                                        ),
                                        children: [
                                          Text(
                                            experienceText,
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              color: _kBodyGrey.withValues(
                                                alpha: 0.95,
                                              ),
                                              fontSize: 15,
                                              fontFamily: 'KurdishFont',
                                              fontWeight: FontWeight.w500,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (hospital.isNotEmpty ||
                                        address.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _glassInfoCard(
                                        icon: Icons.location_on_rounded,
                                        title: s.translate(
                                          'doctor_profile_location',
                                        ),
                                        children: [
                                          if (hospital.isNotEmpty) ...[
                                            Text(
                                              s.translate(
                                                'doctor_profile_hospital_label',
                                              ),
                                              style: TextStyle(
                                                color: _kGoldDark.withValues(
                                                  alpha: 0.85,
                                                ),
                                                fontSize: 12,
                                                fontFamily: kPatientPrimaryFont,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              hospital,
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                color: _kBodyGrey.withValues(
                                                  alpha: 0.95,
                                                ),
                                                fontSize: 15,
                                                fontFamily: 'KurdishFont',
                                                fontWeight: FontWeight.w500,
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                          if (hospital.isNotEmpty &&
                                              address.isNotEmpty)
                                            const SizedBox(height: 14),
                                          if (address.isNotEmpty) ...[
                                            Text(
                                              s.translate(
                                                'doctor_profile_address_label',
                                              ),
                                              style: TextStyle(
                                                color: _kGoldDark.withValues(
                                                  alpha: 0.85,
                                                ),
                                                fontSize: 12,
                                                fontFamily: kPatientPrimaryFont,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              address,
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                color: _kBodyGrey.withValues(
                                                  alpha: 0.95,
                                                ),
                                                fontSize: 15,
                                                fontFamily: 'KurdishFont',
                                                fontWeight: FontWeight.w500,
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                    if (widget.showBookingSection) ...[
                                      const SizedBox(height: 22),
                                      _goldBookButton(
                                        context: context,
                                        onTap: () {
                                          final ctx = _bookingSectionKey
                                              .currentContext;
                                          if (ctx != null) {
                                            Scrollable.ensureVisible(
                                              ctx,
                                              duration: const Duration(
                                                milliseconds: 420,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              alignment: 0.12,
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      KeyedSubtree(
                                        key: _bookingSectionKey,
                                        child: PatientAvailableDaysList(
                                          doctorId: _doctorUid,
                                          patientName: patientName,
                                          doctorDisplayName: doctorDisplayName,
                                          mergedDoctorData: merged,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Faint medical cross motif at very low opacity.
class _SubtleMedicalGlyphsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1565C0).withValues(alpha: 0.032)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    const spacing = 110.0;
    const arm = 12.0;
    for (var y = 50.0; y < size.height; y += spacing) {
      for (var x = 40.0; x < size.width; x += spacing * 1.15) {
        canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), paint);
        canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Same scale-down / bounce-back interaction as doctor card CTAs.
class _DoctorDetailsPressableScale extends StatefulWidget {
  const _DoctorDetailsPressableScale({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_DoctorDetailsPressableScale> createState() =>
      _DoctorDetailsPressableScaleState();
}

class _DoctorDetailsPressableScaleState extends State<_DoctorDetailsPressableScale>
    with SingleTickerProviderStateMixin {
  static const double _kPressedScale = 0.96;

  late final AnimationController _scaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 115),
    reverseDuration: const Duration(milliseconds: 135),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: _kPressedScale,
  ).animate(
    CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
    ),
  );

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _pressDown() {
    HapticFeedback.lightImpact();
    _scaleController.forward();
  }

  void _pressEnd() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) => _pressEnd(),
      onTapCancel: _pressEnd,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
