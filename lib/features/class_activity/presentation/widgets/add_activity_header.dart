import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Gradient header bar shown at the top of [AddActivityDialog].
///
/// Displays an icon, a localised title that depends on [activityType] and
/// [isEditMode], and a close button.
class AddActivityHeader extends StatelessWidget {
  final String activityType;
  final bool isEditMode;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  const AddActivityHeader({
    super.key,
    required this.activityType,
    required this.isEditMode,
    required this.primaryColor,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final isAssignment = activityType == 'tugas';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(
                  isAssignment
                      ? Icons.assignment_rounded
                      : Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  isEditMode
                      ? (isAssignment
                            ? languageProvider.getTranslatedText({
                                'en': 'Edit Assignment',
                                'id': 'Edit Tugas',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'Edit Material',
                                'id': 'Edit Materi',
                              }))
                      : (isAssignment
                            ? languageProvider.getTranslatedText({
                                'en': 'Add Assignment',
                                'id': 'Tambah Tugas',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'Add Material',
                                'id': 'Tambah Materi',
                              })),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => AppNavigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
