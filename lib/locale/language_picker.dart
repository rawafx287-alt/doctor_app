import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/staff_premium_theme.dart';
import 'app_locale.dart';
import 'app_localizations.dart';

/// Doctor profile sheets / panels ([DoctorProfileScreen] security bottom sheet).
const Color _kDoctorSheetPanelFill = Color(0xE8121827);

const Color _kMatteGoldBorder = Color(0xFFC9A227);
const Color _kLightGoldCardFill = Color(0xFFFFF4E0);
/// Same handle treatment as doctor profile bottom sheets.
final Color _kSheetHandle = Colors.white.withValues(alpha: 0.22);

/// Outline globe — Feather/Lucide-style strokes (tint via [ColorFilter]).
const String _kSvgGlobeOutline = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <circle cx="12" cy="12" r="10" stroke="#000000" stroke-width="1.65"/>
  <path d="M2 12h20" stroke="#000000" stroke-width="1.65" stroke-linecap="round"/>
  <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" stroke="#000000" stroke-width="1.65"/>
</svg>
''';

/// Solid circular check — gold disc + high-contrast check ([kStaffLuxGold]).
const String _kSvgCheckCircleSolid = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="10" fill="#D4AF37"/>
  <path d="M8 12.2l2.4 2.4L16 9" fill="none" stroke="#FFFFFF" stroke-width="2.15" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const double _kSheetTopRadius = 22;

/// Max blur (matches booking-style dialogs); ramps 0 → this with [Curves.easeOut].
const double _kLanguageScrimBlurSigma = 5;

/// Scrim dim at full open; scales with the same animation as blur.
const double _kLanguageScrimDimAlpha = 0.12;

/// Profile (and elsewhere): dark navy / gold — aligned with doctor premium shell.
Future<void> showHrNoraLanguagePicker(BuildContext context) async {
  final controller = AppLocaleScope.of(context);
  final sheetDir = controller.textDirection;
  final barrierLabel =
      MaterialLocalizations.of(context).modalBarrierDismissLabel;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    // Avoid the default full-route [FadeTransition]; blur + sheet use [animation] directly.
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _LanguagePickerOverlay(
        animation: animation,
        textDirection: sheetDir,
        controller: controller,
      );
    },
  );
}

class _LanguagePickerOverlay extends StatelessWidget {
  const _LanguagePickerOverlay({
    required this.animation,
    required this.textDirection,
    required this.controller,
  });

  final Animation<double> animation;
  final TextDirection textDirection;
  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    // One curved progress drives blur sigma, scrim alpha, and sheet slide (open + reverse).
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curved);

    return Directionality(
      textDirection: textDirection,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: curved,
            builder: (context, child) {
              final t = curved.value.clamp(0.0, 1.0);
              final sigma = t * _kLanguageScrimBlurSigma;
              final dimAlpha = t * _kLanguageScrimDimAlpha;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: sigma,
                      sigmaY: sigma,
                    ),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: dimAlpha),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: SlideTransition(
              position: slide,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _LanguageSheetBody(controller: controller),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSheetBody extends StatefulWidget {
  const _LanguageSheetBody({required this.controller});

  final LocaleController controller;

  @override
  State<_LanguageSheetBody> createState() => _LanguageSheetBodyState();
}

class _LanguageSheetBodyState extends State<_LanguageSheetBody> {
  double _dragDy = 0;

  void _onHandleDragEnd(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond.dy;
    if (_dragDy > 88 || v > 500) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _dragDy = 0);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Transform.translate(
      offset: Offset(0, _dragDy),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_kSheetTopRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_kSheetTopRadius),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _kDoctorSheetPanelFill,
                  border: Border.all(
                    color: kStaffSilverBorder.withValues(alpha: 0.5),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_kSheetTopRadius),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (d) {
                          final next = _dragDy + d.delta.dy;
                          if (next >= 0) setState(() => _dragDy = next);
                        },
                        onVerticalDragEnd: _onHandleDragEnd,
                        child: SizedBox(
                          height: 36,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _kSheetHandle,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        S.of(context).translate('language'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...HrNoraLanguage.values.map((lang) {
                      final selected =
                          widget.controller.selectedLanguage == lang;
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _LanguageOptionCard(
                            lang: lang,
                            selected: selected,
                            onTap: () async {
                              await widget.controller.setLanguage(lang);
                              if (context.mounted) {
                                Navigator.of(context).maybePop();
                              }
                            },
                          ),
                        );
                      }),
                  ],
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

class _LanguageOptionCard extends StatelessWidget {
  const _LanguageOptionCard({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  static const double _kCardHPad = 18;
  static const double _kIconSlot = 40;

  final HrNoraLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final textAlign = rtl ? TextAlign.right : TextAlign.left;

    final leadingIcon = selected
        ? SvgPicture.string(
            _kSvgCheckCircleSolid,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          )
        : SvgPicture.string(
            _kSvgGlobeOutline,
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(
              kStaffLuxGold,
              BlendMode.srcIn,
            ),
          );

    return Material(
      color: Colors.transparent,
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: kStaffLuxGold.withValues(alpha: 0.14),
        highlightColor: kStaffLuxGold.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? _kLightGoldCardFill.withValues(alpha: 0.92)
                : Colors.black.withValues(alpha: 0.2),
            border: Border.all(
              color: selected
                  ? _kMatteGoldBorder.withValues(alpha: 0.85)
                  : kStaffSilverBorder,
              width: selected ? 1.25 : kStaffCardOutlineWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: selected ? 0.35 : 0.22,
                ),
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kCardHPad,
              vertical: 4,
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                textDirection: Directionality.of(context),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _kIconSlot,
                    child: Center(child: leadingIcon),
                  ),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        lang.nativeTitle,
                        textAlign: textAlign,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          height: 1.2,
                          letterSpacing: 0.15,
                          color: Colors.white,
                          shadows: selected
                              ? const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _kIconSlot),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
