import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Widget for the "Choose Action" bottom sheet when adding a lesson plan.
/// Allows user to choose between manual upload or AI generation.
class AddLessonPlanActionSheet extends ConsumerWidget {
  /// Callback when "Upload Manual" is selected.
  final VoidCallback onUploadManual;

  /// Callback when "Generate AI" is selected.
  final VoidCallback onGenerateAI;

  /// Primary color for the screen (for styling).
  final Color primaryColor;

  const AddLessonPlanActionSheet({
    super.key,
    required this.onUploadManual,
    required this.onGenerateAI,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.read(languageRiverpod);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Choose Action',
              'id': 'Pilih Aksi',
            }),
            subtitle: languageProvider.getTranslatedText({
              'en': 'How would you like to create RPP?',
              'id': 'Bagaimana Anda ingin membuat RPP?',
            }),
            icon: Icons.post_add_rounded,
            primaryColor: primaryColor,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxl + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: Row(
              children: [
                // Upload Manual Card
                Expanded(
                  child: _ActionCard(
                    icon: Icons.upload_file_rounded,
                    label: languageProvider.getTranslatedText({
                      'en': 'Upload Manual',
                      'id': 'Upload Manual',
                    }),
                    description: languageProvider.getTranslatedText({
                      'en': 'Upload your own file',
                      'id': 'Upload file Anda sendiri',
                    }),
                    color: primaryColor,
                    onTap: () {
                      AppNavigator.pop(context);
                      onUploadManual();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),

                // Generate AI Card
                Expanded(
                  child: _ActionCard(
                    icon: Icons.auto_awesome_rounded,
                    label: languageProvider.getTranslatedText({
                      'en': 'Generate AI',
                      'id': 'Generate AI',
                    }),
                    description: languageProvider.getTranslatedText({
                      'en': 'Auto-generate with AI',
                      'id': 'Buat otomatis dengan AI',
                    }),
                    color: ColorUtils.success600,
                    onTap: () {
                      AppNavigator.pop(context);
                      onGenerateAI();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable card for an action option.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
