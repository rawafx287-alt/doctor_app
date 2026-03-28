import 'package:flutter/material.dart';

import '../auth/auth_gate.dart';
import '../theme/hr_nora_colors.dart';
import 'app_locale.dart';
import 'app_localizations.dart';

/// First-launch language choice → saves locale → [AuthGate].
class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  Future<void> _select(
    BuildContext context,
    HrNoraLanguage language,
  ) async {
    final nav = Navigator.of(context, rootNavigator: true);
    await AppLocaleScope.of(context).setLanguage(language);
    if (!context.mounted) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HrNoraColors.scaffoldDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'HR Nora',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: HrNoraColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context).translate('choose_language'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HrNoraColors.textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LanguageCard(
                      title: HrNoraLanguage.ckb.nativeTitle,
                      subtitle: HrNoraLanguage.ckb.nativeSubtitle,
                      flag: 'KU',
                      onTap: () => _select(context, HrNoraLanguage.ckb),
                    ),
                    const SizedBox(height: 16),
                    _LanguageCard(
                      title: HrNoraLanguage.ar.nativeTitle,
                      subtitle: HrNoraLanguage.ar.nativeSubtitle,
                      flag: 'AR',
                      onTap: () => _select(context, HrNoraLanguage.ar),
                    ),
                    const SizedBox(height: 16),
                    _LanguageCard(
                      title: HrNoraLanguage.en.nativeTitle,
                      subtitle: HrNoraLanguage.en.nativeSubtitle,
                      flag: 'EN',
                      onTap: () => _select(context, HrNoraLanguage.en),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.flag,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String flag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HrNoraColors.primaryDeep.withValues(alpha: 0.95),
                const Color(0xFF1E3A5F).withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(
              color: HrNoraColors.accentLight.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HrNoraColors.accentLight.withValues(alpha: 0.15),
                    border: Border.all(
                      color: HrNoraColors.accentLight.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    flag,
                    style: const TextStyle(
                      color: HrNoraColors.accentLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: HrNoraColors.textSoft,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'KurdishFont',
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: HrNoraColors.textMuted.withValues(alpha: 0.95),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: HrNoraColors.accentLight.withValues(alpha: 0.85),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
