import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locale/app_localizations.dart';
import '../theme/patient_premium_theme.dart';
import 'doctor_rating_service.dart';

/// Interactive "rate this doctor" block on [DoctorDetailsScreen].
class DoctorRateDoctorPanel extends StatefulWidget {
  const DoctorRateDoctorPanel({
    super.key,
    required this.doctorId,
    required this.patientDocId,
    required this.authUid,
  });

  final String doctorId;
  final String patientDocId;
  final String authUid;

  @override
  State<DoctorRateDoctorPanel> createState() => _DoctorRateDoctorPanelState();
}

class _DoctorRateDoctorPanelState extends State<DoctorRateDoctorPanel> {
  late Future<bool> _eligibleFuture;
  int _selectedStars = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  static const Color _starActive = Colors.amber;
  static const Color _starEmpty = Color(0xFFBDBDBD);

  @override
  void initState() {
    super.initState();
    _eligibleFuture = patientHasCompletedAppointmentWithDoctor(
      doctorUserId: widget.doctorId,
      patientUserDocId: widget.patientDocId,
      authUid: widget.authUid,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations s) async {
    if (_selectedStars < 1 || _selectedStars > 5 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await submitDoctorRating(
        doctorUserId: widget.doctorId,
        patientUserDocId: widget.patientDocId,
        authUid: widget.authUid,
        stars: _selectedStars,
        comment: _commentController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('doctor_rating_thanks'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    } on StateError catch (e) {
      if (!mounted) return;
      final msg = switch (e.message) {
        'already_rated' => s.translate('doctor_rating_already'),
        'no_completed_appointment' =>
          s.translate('doctor_rating_need_visit'),
        _ => s.translate('doctor_rating_error'),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate('doctor_rating_error'),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ref = doctorRatingDocRef(
      doctorUserId: widget.doctorId,
      patientUserDocId: widget.patientDocId,
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, ratingSnap) {
        final hasRated = ratingSnap.hasData && ratingSnap.data!.exists;

        return FutureBuilder<bool>(
          future: _eligibleFuture,
          builder: (context, eligSnap) {
            final eligible = eligSnap.data == true;
            final loadingElig =
                eligSnap.connectionState == ConnectionState.waiting;

            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.star_rate_rounded,
                          color: Colors.amber.shade700,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.translate('doctor_rating_section_title'),
                            style: const TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: Color(0xFF0D2137),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (hasRated) ...[
                      Text(
                        s.translate('doctor_rating_already'),
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.blueGrey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _readOnlyStars(
                        (ratingSnap.data!.data()![DoctorRatingFirestore.stars] as num?)
                                ?.toInt()
                                .clamp(1, 5) ??
                            5,
                      ),
                    ] else if (loadingElig) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ] else if (!eligible) ...[
                      Text(
                        s.translate('doctor_rating_need_visit'),
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.blueGrey.shade700,
                          height: 1.45,
                        ),
                      ),
                    ] else ...[
                      Text(
                        s.translate('doctor_rating_tap_stars'),
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.ltr,
                        children: List.generate(5, (i) {
                          final n = i + 1;
                          final on = n <= _selectedStars;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedStars = n);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    on
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 36,
                                    color: on ? _starActive : _starEmpty,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        maxLength: 500,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          alignLabelWithHint: true,
                          labelText: s.translate('doctor_rating_comment_hint'),
                          labelStyle: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            color: Colors.blueGrey.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.75),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.blueGrey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF1976D2),
                              width: 1.4,
                            ),
                          ),
                          contentPadding: const EdgeInsets.fromLTRB(
                            14,
                            14,
                            14,
                            14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1976D2),
                                Color(0xFF42A5F5),
                                Color(0xFFD4AF37),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _submitting || _selectedStars < 1
                                  ? null
                                  : () => _submit(s),
                              child: Center(
                                child: _submitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        s.translate('doctor_rating_submit'),
                                        style: const TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _readOnlyStars(int stars) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.ltr,
      children: List.generate(
        5,
        (i) => Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 28,
          color: i < stars ? _starActive : _starEmpty,
        ),
      ),
    );
  }
}
