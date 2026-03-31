import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Coloured info banner that explains SPECIFIC vs GENERAL target mode.
///
/// Used inside [AddActivityDialog] just below the form header.
class AddActivityTargetInfoBox extends StatelessWidget {
  final String initialTarget;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  const AddActivityTargetInfoBox({
    super.key,
    required this.initialTarget,
    required this.primaryColor,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            initialTarget == 'khusus' ? Icons.people : Icons.schedule,
            color: primaryColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              initialTarget == 'khusus'
                  ? languageProvider.getTranslatedText({
                      'en': 'SPECIFIC: You can select any class anytime.',
                      'id': 'KHUSUS: Anda dapat memilih kelas kapan saja.',
                    })
                  : languageProvider.getTranslatedText({
                      'en':
                          'GENERAL: Only classes from start time to +23 hours are available.',
                      'id':
                          'UMUM: Hanya kelas dari jam mulai sampai +23 jam yang tersedia.',
                    }),
              style: TextStyle(
                fontSize: 12,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
