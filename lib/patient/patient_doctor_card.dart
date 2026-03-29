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

  static const TextStyle _labelStyle = TextStyle(
    color: Color(0xFF829AB1),
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
                      border: Border.all(color: const Color(0xFF42A5F5), width: 1.5),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        _placeholderImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF1D1E33),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.medical_services_rounded,
                            color: Color(0xFF42A5F5),
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
                            color: Color(0xFFD9E2EC),
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
                            color: Color(0xFF829AB1),
                            fontSize: 15,
                            fontFamily: 'KurdishFont',
                            height: 1.35,
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
                      color: const Color(0xFF829AB1).withValues(alpha: 0.95),
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
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
