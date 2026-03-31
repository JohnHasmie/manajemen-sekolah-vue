// Card widget that displays a single subject in the admin subject list.
// Shows name, code, active status, class count, and edit/delete actions.
// Extracted from admin_subject_management_screen.dart to slim down the screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_circle_action_button.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_info_tag.dart';

/// A card that represents one subject (mata pelajaran) in the list.
///
/// Like a Vue `<SubjectCard>` component — reads the language provider for
/// translated labels, then delegates mutations upward via [onEdit],
/// [onDelete], and [onTap] callbacks (no setState / no direct API calls).
///
/// [index] drives the avatar accent color via [ColorUtils.getColorForIndex].
class SubjectCard extends ConsumerWidget {
  /// Raw subject map returned from the API.
  final Map<String, dynamic> subject;

  /// Position of this card in the list — used for avatar color cycling.
  final int index;

  /// The primary accent color for action buttons (typically admin role color).
  final Color primaryColor;

  /// Called when the user taps the card body (navigate to class management).
  final VoidCallback onTap;

  /// Called when the user presses the edit (pencil) button.
  final VoidCallback onEdit;

  /// Called when the user presses the delete (trash) button.
  final VoidCallback onDelete;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.index,
    required this.primaryColor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Like a Vue computed property — derive display values from raw data.
    final languageProvider = ref.read(languageRiverpod);
    final classCount = subject['jumlah_kelas'] ?? 0;
    final isActive = subject['is_active'] ?? true;
    final avatarColor = ColorUtils.getColorForIndex(index);
    final subjectCode = subject['code'] ?? subject['kode'] ?? '-';
    final classNames = (subject['kelas_names']?.toString() ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with first letter of subject name
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    (subject['name'] ?? 'S')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),

                // Content area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject name
                      Text(
                        subject['name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),

                      // Subject code + active/inactive badge
                      Row(
                        children: [
                          Text(
                            subjectCode,
                            style: TextStyle(
                              fontSize: 13,
                              color: ColorUtils.slate500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          // Dot separator
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: ColorUtils.slate300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? ColorUtils.success600
                                      .withValues(alpha: 0.1)
                                  : ColorUtils.error600.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? ColorUtils.success600
                                        : ColorUtils.error600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.xs),
                                Text(
                                  isActive
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Active',
                                          'id': 'Aktif',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Inactive',
                                          'id': 'Tidak Aktif',
                                        }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? ColorUtils.success600
                                        : ColorUtils.error600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),

                      // Info tags: class count and class names
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SubjectInfoTag(
                            icon: Icons.class_outlined,
                            text:
                                '$classCount ${languageProvider.getTranslatedText({'en': 'Classes', 'id': 'Kelas'})}',
                          ),
                          if (classNames.isNotEmpty)
                            SubjectInfoTag(
                              icon: Icons.groups_outlined,
                              text: classNames.join(', '),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons column
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SubjectCircleActionButton(
                      icon: Icons.edit_outlined,
                      color: primaryColor,
                      onPressed: onEdit,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    SubjectCircleActionButton(
                      icon: Icons.delete_outline,
                      color: ColorUtils.error600,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
