// Bottom sheet widget for selecting the activity type (Assignment or Material).
// Extracted from teacher_class_activity_screen.dart to reduce file size.
// Like a Vue child component that emits an event when the user picks a type.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_type_option_tile.dart';

/// Bottom sheet content for choosing between "Tugas" and "Materi" activity types.
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityTypeBottomSheet(
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        onActivityTypeSelected: onActivityTypeSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: const Icon(
                        Icons.add_circle_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Select Activity Type',
                        'id': 'Pilih Jenis Kegiatan',
                      }),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              children: [
                ActivityTypeOptionTile(
                  icon: Icons.assignment_rounded,
                  title: languageProvider.getTranslatedText({
                    'en': 'Assignment',
                    'id': 'Tugas',
                  }),
                  description: languageProvider.getTranslatedText({
                    'en': 'Create an assignment for students',
                    'id': 'Buat tugas untuk siswa',
                  }),
                  color: ColorUtils.warning600,
                  onTap: () {
                    AppNavigator.pop(context);
                    onActivityTypeSelected('tugas');
                  },
                ),
                SizedBox(height: AppSpacing.md),
                ActivityTypeOptionTile(
                  icon: Icons.menu_book_rounded,
                  title: languageProvider.getTranslatedText({
                    'en': 'Material',
                    'id': 'Materi',
                  }),
                  description: languageProvider.getTranslatedText({
                    'en': 'Share learning materials',
                    'id': 'Bagikan materi pembelajaran',
                  }),
                  color: ColorUtils.corporateBlue600,
                  onTap: () {
                    AppNavigator.pop(context);
                    onActivityTypeSelected('materi');
                  },
                ),
                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
          SafeArea(top: false, child: SizedBox(height: AppSpacing.sm)),
        ],
      ),
    );
  }
}
