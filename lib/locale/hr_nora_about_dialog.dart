import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/staff_premium_theme.dart';
import 'app_locale.dart';
import 'app_localizations.dart';

const String _kAboutVersion = '1.0.0';

const Color _kAboutGlassFill = Color(0xCC0B1220);
const Color _kAboutGlassInner = Color(0xE6030712);
const Color _kNeonBlue = Color(0xFF38BDF8);

/// Phrases highlighted in gold per language (must appear verbatim in [about_description]).
List<String> _aboutGoldPhrasesForLanguage(HrNoraLanguage lang) {
  switch (lang) {
    case HrNoraLanguage.ckb:
      return ['سیستەمێکی ڕێکخراوە', 'باشترین خزمەتگوزاری'];
    case HrNoraLanguage.ar:
      return ['نظام منظم', 'أفضل خدمات'];
    case HrNoraLanguage.en:
      return ['organized system', 'quality healthcare'];
  }
}

/// Builds centered body text: white base + gold for known key phrases.
List<InlineSpan> _aboutDescriptionSpans(
  String fullText,
  HrNoraLanguage lang, {
  required TextStyle baseStyle,
  required TextStyle goldStyle,
}) {
  final phrases = _aboutGoldPhrasesForLanguage(lang);
  final spans = <InlineSpan>[];
  var remaining = fullText;

  while (remaining.isNotEmpty) {
    var bestPos = -1;
    String? bestPhrase;
    for (final h in phrases) {
      if (h.isEmpty) continue;
      final p = remaining.indexOf(h);
      if (p >= 0 && (bestPos < 0 || p < bestPos)) {
        bestPos = p;
        bestPhrase = h;
      }
    }
    if (bestPos < 0 || bestPhrase == null) {
      spans.add(TextSpan(text: remaining, style: baseStyle));
      break;
    }
    if (bestPos > 0) {
      spans.add(TextSpan(text: remaining.substring(0, bestPos), style: baseStyle));
    }
    spans.add(TextSpan(text: bestPhrase, style: goldStyle));
    remaining = remaining.substring(bestPos + bestPhrase.length);
  }
  return spans;
}

/// Premium «دەربارەی ئەپ» — dark glass, gold/cyan rim, fade + scale open.
Future<void> showHrNoraAboutDialog(BuildContext context) {
  final barrierLabel =
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return const _HrNoraAboutDialog();
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _HrNoraAboutDialog extends StatelessWidget {
  const _HrNoraAboutDialog();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dir = AppLocaleScope.of(context).textDirection;
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    final maxH = MediaQuery.sizeOf(context).height * 0.52;

    final baseText = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.72,
      letterSpacing: 0.15,
      color: Colors.white.withValues(alpha: 0.92),
    );
    final goldText = baseText.copyWith(
      color: kStaffLuxGold,
      fontWeight: FontWeight.w800,
      height: 1.72,
    );

    return Center(
      child: Directionality(
        textDirection: dir,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            padding: const EdgeInsets.all(1.1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kStaffLuxGold.withValues(alpha: 0.75),
                  _kNeonBlue.withValues(alpha: 0.55),
                  kStaffLuxGold.withValues(alpha: 0.45),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: kStaffLuxGold.withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: 0,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _kAboutGlassFill,
                        _kAboutGlassInner,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: SizedBox(
                            width: 104,
                            height: 104,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kStaffLuxGold.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 28,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: _kNeonBlue.withValues(alpha: 0.2),
                                        blurRadius: 20,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      width: 1.2,
                                    ),
                                    color: const Color(0xFF111827),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/app_icon.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.medical_services_rounded,
                                        size: 48,
                                        color: kStaffLuxGold.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.translate('app_display_name'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1.2,
                            letterSpacing: 0.35,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: kStaffLuxGold.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'v$_kAboutVersion',
                              style: TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                letterSpacing: 0.8,
                                color: kStaffLuxGold.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxH),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text.rich(
                              TextSpan(
                                children: _aboutDescriptionSpans(
                                  s.translate('about_description'),
                                  lang,
                                  baseStyle: baseText,
                                  goldStyle: goldText,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context, rootNavigator: true)
                                    .maybePop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Colors.white.withValues(alpha: 0.92),
                              side: BorderSide(
                                color: kStaffLuxGold.withValues(alpha: 0.65),
                                width: 1.2,
                              ),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              s.translate('close'),
                              style: const TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                letterSpacing: 0.2,
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
        ),
      ),
    );
  }
}
