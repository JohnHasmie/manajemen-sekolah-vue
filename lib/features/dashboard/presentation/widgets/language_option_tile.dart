// A tappable language-selection tile used inside the language-picker dialog.
// Like a Vue `<LanguageOptionTile>` that highlights the active language with a checkmark.
// Receives the LanguageProvider and a callback-free setter — no setState involved.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A single language option row rendered inside the language-picker [AlertDialog].
///
/// Tapping the tile pops the dialog and asynchronously switches the app
/// language via [LanguageProvider.setLanguage].  A checkmark icon appears
/// on the right when this language is already active — similar to a
/// radio-button option in a Laravel Blade form, but styled as a card.
///
/// Example usage:
/// ```dart
/// LanguageOptionTile(
///   languageProvider: languageProvider,
///   language: 'Indonesia',
///   code: 'id',
///   color: Colors.green,
/// )
/// ```
class LanguageOptionTile extends StatelessWidget {
  /// The shared language provider (like a Pinia/Vuex store module).
  final LanguageProvider languageProvider;

  /// Display name of the language, e.g. "Indonesia" or "English".
  final String language;

  /// ISO language code, e.g. "id" or "en".
  final String code;

  /// Accent colour for the border, background tint, and icon.
  final Color color;

  const LanguageOptionTile({
    super.key,
    required this.languageProvider,
    required this.language,
    required this.code,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = languageProvider.currentLanguage == code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Pop the dialog first, then switch language asynchronously
        onTap: () async {
          AppNavigator.pop(context);
          await languageProvider.setLanguage(code);
        },
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.language, color: color),
              const SizedBox(width: AppSpacing.md),
              Text(
                language,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              // Checkmark visible only when this is the currently active language
              if (isActive) Icon(Icons.check_circle, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
