import 'package:flutter/material.dart';

import '../theme/hr_nora_colors.dart';
import 'app_locale.dart';
import 'app_localizations.dart';

/// Profile (and elsewhere): bottom sheet with the same three languages as [LanguageSelectionScreen].
Future<void> showHrNoraLanguagePicker(BuildContext context) async {
  final controller = AppLocaleScope.of(context);
  final sheetDir = controller.textDirection;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1D1E33),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Directionality(
        textDirection: sheetDir,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                S.of(ctx).translate('language'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD9E2EC),
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              ...HrNoraLanguage.values.map((lang) {
                final selected = controller.selectedLanguage == lang;
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? HrNoraColors.accentLight.withValues(alpha: 0.5)
                            : Colors.white10,
                      ),
                    ),
                    tileColor: selected
                        ? HrNoraColors.accentLight.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.03),
                    leading: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.language_rounded,
                      color: selected
                          ? HrNoraColors.accentLight
                          : const Color(0xFF627D98),
                    ),
                    title: Text(
                      lang.nativeTitle,
                      style: const TextStyle(
                        color: Color(0xFFD9E2EC),
                        fontFamily: 'KurdishFont',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    subtitle: lang.nativeSubtitle.isEmpty
                        ? null
                        : Text(
                            lang.nativeSubtitle,
                            style: const TextStyle(
                              color: Color(0xFF829AB1),
                              fontFamily: 'KurdishFont',
                              fontSize: 12,
                            ),
                          ),
                    trailing: selected
                        ? Text(
                            S.of(ctx).translate('language_current'),
                            style: TextStyle(
                              color: HrNoraColors.accentLight.withValues(alpha: 0.9),
                              fontFamily: 'KurdishFont',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                    onTap: () async {
                      await controller.setLanguage(lang);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  S.of(ctx).translate('close'),
                  style: const TextStyle(
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
