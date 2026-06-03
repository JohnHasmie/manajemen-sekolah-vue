// Bottom sheet widget for selecting the activity type (Assignment or Material).
// Extracted from teacher_class_activity_screen.dart to reduce file size.
// Like a Vue child component that emits an event when the user picks a type.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_type_option_tile.dart';

/// Bottom sheet content for choosing between "Tugas" and "Materi" activity
/// types.
///
/// Call [ActivityTypeBottomSheet.show] to display this as a modal sheet.
/// [onActivityTypeSelected] is called with the selected type string
/// ('tugas' or 'materi') so the caller can open the add-activity dialog.
class ActivityTypeBottomSheet extends StatelessWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final void Function(String activityType) onActivityTypeSelected;

  const ActivityTypeBottomSheet({
    super.key,
    required this.primaryColor,
    required this.languageProvider,
    required this.onActivityTypeSelected,
  });

  /// Helper to open this sheet as a modal bottom sheet.
  static void show({
    required BuildContext context,
    required Color primaryColor,
    required LanguageProvider languageProvider,
    required void Function(String activityType) onActivityTypeSelected,
  }) {
    AppBottomSheet.show(
      context: context,
      title: languageProvider.getTranslatedText({
        'en': 'Select Activity Type',
        'id': 'Pilih Jenis Kegiatan',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Choose what you want to create',
        'id': 'Pilih apa yang ingin Anda buat',
      }),
      icon: Icons.add_task_rounded,
      primaryColor: primaryColor,
      content: _ActivityTypeContent(
        languageProvider: languageProvider,
        primaryColor: primaryColor,
        onActivityTypeSelected: onActivityTypeSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ActivityTypeContent(
      languageProvider: languageProvider,
      primaryColor: primaryColor,
      onActivityTypeSelected: onActivityTypeSelected,
    );
  }
}

/// Internal content widget for the activity type selection sheet.
class _ActivityTypeContent extends StatelessWidget {
  final LanguageProvider languageProvider;
  final Color primaryColor;
  final void Function(String activityType) onActivityTypeSelected;

  const _ActivityTypeContent({
    required this.languageProvider,
    required this.primaryColor,
    required this.onActivityTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ActivityTypeOptionTile(
          icon: Icons.assignment_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Assignment',
            'id': 'Tugas',
          }),
          description: languageProvider.getTranslatedText({
            'en': 'Track student comprehension through exercises',
            'id': 'Berikan tugas untuk memantau pemahaman siswa',
          }),
          color: ColorUtils.warning600,
          onTap: () {
            // Backend canonical: `assignment` (was `tugas`).
            onActivityTypeSelected('assignment');
          },
        ),
        const SizedBox(height: 16),
        ActivityTypeOptionTile(
          icon: Icons.menu_book_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Material',
            'id': 'Materi',
          }),
          description: languageProvider.getTranslatedText({
            'en': 'Log class materials for activity tracing',
            'id': 'Catat materi kelas untuk pelacakan kegiatan',
          }),
          color: ColorUtils.corporateBlue600,
          onTap: () {
            // Backend canonical: `material` (was `materi`).
            onActivityTypeSelected('material');
          },
        ),
        const SizedBox(height: 32),
        // Footer Tracing Context Note
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 14, color: ColorUtils.slate400),
            const SizedBox(width: 8),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Input will be logged for class activity tracing',
                'id': 'Input akan tercatat untuk pelacakan kegiatan kelas',
              }),
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: ColorUtils.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
