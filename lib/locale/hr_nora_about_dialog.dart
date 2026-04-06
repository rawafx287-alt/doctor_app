import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/patient_premium_theme.dart';
import 'app_locale.dart';
import 'app_localizations.dart';

/// Silver rim (0.8) — matches language sheet / doctor cards.
const LinearGradient _kAboutSilverRim = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF0F0F0),
    Color(0xFFD1D1D1),
    Color(0xFFE0E0E0),
  ],
  stops: [0.0, 0.48, 1.0],
);

/// Matte gold / bronze panel (patient bookings palette).
const LinearGradient _kAboutInnerGold = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFF5E6CA),
    Color(0xFFD4A373),
    Color(0xFFA98467),
  ],
  stops: [0.0, 0.5, 1.0],
);

const Color _kAboutTextBrown = Color(0xFF432818);
const Color _kAboutVersionTone = Color(0xFF7D6B58);

/// Gold gradient ring around the glass close control (echoes card + booking CTAs).
const LinearGradient _kAboutGlassButtonBorderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF5E6CA),
    Color(0xFFE6B800),
    Color(0xFFB8860B),
    Color(0xFFA98467),
  ],
  stops: [0.0, 0.35, 0.65, 1.0],
);

const BorderRadius _kAboutCloseStadium =
    BorderRadius.all(Radius.circular(999));

const String _kAboutVersion = '1.0.0';

/// Premium «دەربارەی ئەپ» / About — patient & doctor profiles.
Future<void> showHrNoraAboutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _HrNoraAboutDialog(),
  );
}

class _HrNoraAboutDialog extends StatelessWidget {
  const _HrNoraAboutDialog();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dir = AppLocaleScope.of(context).textDirection;
    final maxH = MediaQuery.sizeOf(context).height * 0.62;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
      child: Directionality(
        textDirection: dir,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: _kAboutSilverRim,
            boxShadow: [
              BoxShadow(
                color: kPatientDeepBlue.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(0.8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19.2),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: _kAboutInnerGold,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.42),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kAboutTextBrown.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.medical_services_rounded,
                        size: 44,
                        color: _kAboutTextBrown.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.translate('app_display_name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        height: 1.15,
                        letterSpacing: 0.4,
                        color: _kAboutTextBrown,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _kAboutVersion,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.6,
                        color: _kAboutVersionTone.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          s.translate('about_description'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            height: 1.55,
                            color: _kAboutTextBrown,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: _kAboutCloseStadium,
                        splashColor: Colors.white.withValues(alpha: 0.18),
                        highlightColor: Colors.white.withValues(alpha: 0.08),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: _kAboutCloseStadium,
                            gradient: _kAboutGlassButtonBorderGradient,
                          ),
                          padding: const EdgeInsets.all(1.2),
                          child: ClipRRect(
                            borderRadius: _kAboutCloseStadium,
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 10,
                                sigmaY: 10,
                              ),
                              child: Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                color: Colors.white.withValues(alpha: 0.2),
                                child: Text(
                                  s.translate('close'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16.5,
                                    height: 1.2,
                                    letterSpacing: 0.25,
                                    color: _kAboutTextBrown,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
