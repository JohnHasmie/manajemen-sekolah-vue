// Empty-state placeholder for the RPP (lesson plan) list screen.
// Like a Vue component `<EmptyState />` shown when a list has no items.
// Displays a centred icon, heading, and hint text — no data dependencies.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Shown in the RPP list when there are no lesson plans to display.
///
/// [languageProvider] drives translated text, like Vue's `$t('...')`.
/// Completely stateless — no callbacks needed.
class LessonPlanEmptyState extends StatelessWidget {
  final LanguageProvider languageProvider;

  const LessonPlanEmptyState({super.key, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: const BorderRadius.all(Radius.circular(20)),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 36,
              color: ColorUtils.slate400,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            languageProvider.getTranslatedText({
              'en': 'No RPP created yet',
              'id': 'Belum ada RPP dibuat',
            }),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            languageProvider.getTranslatedText({
              'en': 'Click the "+" button to create your first RPP.',
              'id': 'Klik tombol "+" untuk membuat RPP pertama Anda.',
            }),
            style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
          ),
        ],
      ),
    );
  }
}
