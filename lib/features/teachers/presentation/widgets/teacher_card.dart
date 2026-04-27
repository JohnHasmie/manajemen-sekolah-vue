// TeacherCard — list-item card for a single teacher in the admin teacher screen.
// Shows avatar, name, email, homeroom class tag, status chip, and edit/delete actions.
// Extracted from TeacherAdminScreen.buildTeacherCard (admin_teacher_management_screen.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/status_badge.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
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

    // Normalize the heterogeneous API response shape through the typed model.
    // This replaces ~15 lines of inline Map/List/null homeroom handling.
    final model = Teacher.fromJson(teacher);
    final isHomeroomTeacher = model.isHomeroomTeacher;
    final className = model.homeroomClassName ?? '-';
    final email = model.email.isNotEmpty ? model.email : '-';
    final displayName = model.name.isNotEmpty ? model.name : 'No Name';
    final avatarInitial = model.name.isNotEmpty
        ? model.name[0].toUpperCase()
        : 'N';
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
                    avatarInitial,
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
                        displayName,
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
                      StatusBadge(
                        label: languageProvider.getTranslatedText({
                          'en': 'Homeroom',
                          'id': 'Wali Kelas',
                        }),
                        color: ColorUtils.corporateBlue600,
                      )
                    else
                      StatusBadge(
                        label: languageProvider.getTranslatedText({
                          'en': 'Active',
                          'id': 'Aktif',
                        }),
                        color: ColorUtils.success600,
                      ),

                    // Per-row edit/delete affordances removed (PR-7 / Audit
                    // Theme 7). Outer InkWell already wires tap-to-detail;
                    // bulk-mode + 3-dot overflow surface destructive actions.
                    // `onEdit` and `onDelete` constructor props are kept so
                    // callers stay unchanged.
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
