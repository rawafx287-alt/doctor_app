import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../locale/app_localizations.dart';

/// Doctor row used on patient home and hospital doctor list.
class PatientDoctorCard extends StatelessWidget {
  const PatientDoctorCard({
    super.key,
    required this.name,
    required this.specialty,
    required this.onOpenDetails,
  });

  final String name;
  final String specialty;
  final VoidCallback onOpenDetails;

  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  static const Color _charcoal = Color(0xFF333333);
  static const Color _darkBlue = Color(0xFF0D47A1);
  static const Color _muted = Color(0xFF546E7A);
  static const Color _vibrantBlue = Color(0xFF1976D2);
  static const Color _glassFill = Color(0x66FFFFFF);
  static const Color _glassBorder = Color(0xE6FFFFFF);

  static const TextStyle _labelStyle = TextStyle(
    color: _muted,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFamily: 'KurdishFont',
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _glassFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _glassBorder, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: Directionality.of(context),
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _vibrantBlue, width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            _placeholderImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.white.withValues(alpha: 0.5),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.medical_services_rounded,
                                color: _vibrantBlue,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(context).translate('field_name'),
                              textAlign: TextAlign.start,
                              style: _labelStyle,
                            ),
                            Text(
                              name,
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                color: _charcoal,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'KurdishFont',
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              S.of(context).translate('field_specialty'),
                              textAlign: TextAlign.start,
                              style: _labelStyle,
                            ),
                            Text(
                              specialty,
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                color: _darkBlue,
                                fontSize: 15,
                                fontFamily: 'KurdishFont',
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    textDirection: Directionality.of(context),
                    children: [
                      Text(
                        S.of(context).translate('click_for_details'),
                        style: TextStyle(
                          color: _muted.withValues(alpha: 0.95),
                          fontFamily: 'KurdishFont',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_back_ios_new_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: _vibrantBlue,
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
