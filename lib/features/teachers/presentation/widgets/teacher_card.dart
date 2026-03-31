// TeacherCard — list-item card for a single teacher in the admin teacher screen.
// Shows avatar, name, email, homeroom class tag, status chip, and edit/delete actions.
// Extracted from TeacherAdminScreen.buildTeacherCard (admin_teacher_management_screen.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_info_tag.dart';

/// A Material card that renders one teacher row in the admin list.
///
/// In Laravel/Vue terms this is a standalone `TeacherCard.vue` component.
/// All mutations (edit, delete, navigate) are delegated upward via callbacks
/// so this widget stays stateless and testable in isolation.
class TeacherCard extends ConsumerWidget {
  /// The raw teacher map returned by the API (same shape as TeacherResource).
  final Map<String, dynamic> teacher;

  /// Position in the list — used only for avatar color generation.
  final int index;

  /// Called when the card row itself is tapped (navigate to detail screen).
  final VoidCallback onTap;

  /// Called when the pencil/edit icon is tapped.
  final VoidCallback onEdit;

  /// Called when the trash/delete icon is tapped.
  final VoidCallback onDelete;

  const TeacherCard({
    super.key,
    required this.teacher,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.read(languageRiverpod);
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;

    // Determine homeroom status — homeroom_class can be a Map, a List, or null.
    final isHomeroomTeacher =
        (teacher['homeroom_class'] != null &&
            teacher['homeroom_class'] is! List) ||
        (teacher['homeroom_class'] is List &&
            (teacher['homeroom_class'] as List).isNotEmpty);

    final className = (teacher['homeroom_class'] is Map)
        ? teacher['homeroom_class']['name']
        : (teacher['homeroom_class'] is List &&
              (teacher['homeroom_class'] as List).isNotEmpty)
        ? teacher['homeroom_class'][0]['name']
        : (teacher['homeroom_class_name'] ?? '-');

    final email = teacher['user']?['email'] ?? teacher['email'] ?? '-';
    final avatarColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              children: [
                // ── Avatar ──────────────────────────────────────────────
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    (teacher['name'] ?? 'N')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // ── Name + info tags ─────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (isHomeroomTeacher && className != '-') ...[
                        TeacherInfoTag(
                          icon: Icons.class_outlined,
                          text: className,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      TeacherInfoTag(icon: Icons.email_outlined, text: email),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // ── Status chip + action buttons ─────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Homeroom or Active badge
                    if (isHomeroomTeacher)
                      _StatusBadge(
                        label: languageProvider.getTranslatedText({
                          'en': 'Homeroom',
                          'id': 'Wali Kelas',
                        }),
                        color: ColorUtils.corporateBlue600,
                      )
                    else
                      _StatusBadge(
                        label: languageProvider.getTranslatedText({
                          'en': 'Active',
                          'id': 'Aktif',
                        }),
                        color: ColorUtils.success600,
                      ),

                    // Edit / Delete buttons — hidden in read-only mode
                    if (!isReadOnly) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _ActionIcon(
                            icon: Icons.edit_outlined,
                            color: ColorUtils.corporateBlue600,
                            onTap: onEdit,
                          ),
                          const SizedBox(width: 6),
                          _ActionIcon(
                            icon: Icons.delete_outline,
                            color: ColorUtils.error600,
                            onTap: onDelete,
                          ),
                        ],
                      ),
                    ],
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

// ── Private helpers (only used inside this file) ─────────────────────────────

/// Pill badge for homeroom / active status — like a Vue `<StatusBadge>` sub-component.
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tappable icon button used for edit/delete actions inside the card.
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
