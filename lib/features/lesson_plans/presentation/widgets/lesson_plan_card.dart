// RPP (lesson plan) list card widget for the teacher lesson plan screen.
// Like a reusable Vue component `<LessonPlanCard :lessonPlan="..." />`.
// Shows title, subject, status badge, class tag, and CRUD action buttons.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_info_tag.dart';

/// A card widget that renders a single RPP entry in the list.
///
/// All interactions are exposed as callbacks — like Vue `$emit('view')`.
/// [accentColor] is the per-index colour, [statusColor] is derived from status.
class LessonPlanCard extends StatelessWidget {
  final Map<String, dynamic> lessonPlan;
  final Color accentColor;
  final Color statusColor;
  final String statusLabel;
  final Color primaryColor;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const LessonPlanCard({
    super.key,
    required this.lessonPlan,
    required this.accentColor,
    required this.statusColor,
    required this.statusLabel,
    required this.primaryColor,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  // Small circular icon button — like an icon-only `<v-btn icon>` in Vuetify.
  Widget _circleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon + title/subject + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lessonPlan['judul'] ?? 'No Title',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Text(
                            lessonPlan['mata_pelajaran_nama'] ?? 'No Subject',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),
                // Info tags: class
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    LessonPlanInfoTag(
                      icon: Icons.class_,
                      label: lessonPlan['kelas_nama'] ?? 'No Class',
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _circleActionButton(
                      icon: Icons.visibility_outlined,
                      color: primaryColor,
                      onPressed: onView,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _circleActionButton(
                      icon: Icons.edit_outlined,
                      color: ColorUtils.warning600,
                      onPressed: onEdit,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _circleActionButton(
                      icon: Icons.delete_outlined,
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
