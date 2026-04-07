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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Gradient
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_task_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Select Activity Type',
                              'id': 'Pilih Jenis Kegiatan',
                            }),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Choose what you want to create',
                              'id': 'Pilih apa yang ingin Anda buat',
                            }),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => AppNavigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
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
                    // REMOVED pop() to keep the selection sheet in the background
                    onActivityTypeSelected('tugas');
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
                    // REMOVED pop() to keep the selection sheet in the background
                    onActivityTypeSelected('materi');
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
            ),
          ),
          const SafeArea(top: false, child: SizedBox(height: 12)),
        ],
      ),
    );
  }
}
