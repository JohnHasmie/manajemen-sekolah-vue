// Displays a single admin lesson-plan (RPP) entry in a tappable card.
// Extracted from AdminLessonPlanScreen._buildLessonPlanCard to keep the
// screen file lean and make this card unit-testable in isolation.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A card that shows title, subject, status badge, class/teacher tags
/// and action buttons for an admin reviewing a lesson plan (RPP).
///
/// Like a Vue component: all data comes in via props (constructor params)
/// and user actions bubble up via callbacks — no setState inside.
class LessonPlanAdminCard extends StatelessWidget {
  /// Raw lesson-plan map from the API response.
  final Map<String, dynamic> lessonPlan;

  /// Position in the list — used to pick an accent colour.
  final int index;

  /// Called when the card body is tapped (view detail).
  final VoidCallback onTap;

  /// Called when the edit/status button is tapped.
  final VoidCallback onUpdateStatus;

  /// The screen's primary brand colour (admin role colour).
  final Color primaryColor;

  const LessonPlanAdminCard({
    super.key,
    required this.lessonPlan,
    required this.index,
    required this.onTap,
    required this.onUpdateStatus,
    required this.primaryColor,
  });

  // ---------------------------------------------------------------------------
  // Private helpers (previously private methods on the screen state)
  // ---------------------------------------------------------------------------

  Color _statusColor() {
    switch (lessonPlan['status'] ?? '') {
      case 'Approved':
      case 'Disetujui':
        return ColorUtils.success600;
      case 'Pending':
      case 'Menunggu':
        return ColorUtils.warning600;
      case 'Rejected':
      case 'Ditolak':
        return ColorUtils.error600;
      case 'Draft':
      case 'draft':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }

  String _statusLabel() {
    switch (lessonPlan['status']) {
      case 'Approved':
      case 'Disetujui':
        return 'Disetujui';
      case 'Pending':
      case 'Menunggu':
        return 'Menunggu';
      case 'Draft':
      case 'draft':
        return 'Draft';
      case 'Rejected':
      case 'Ditolak':
        return 'Ditolak';
      default:
        return lessonPlan['status'] ?? '-';
    }
  }

  /// Small pill tag with an icon and label — like a Vue chip component.
  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    Color? tagColor,
  }) {
    final color = tagColor ?? ColorUtils.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Circular icon button — like a small action button component.
  Widget _buildCircleActionButton({
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final accentColor = ColorUtils.getColorForIndex(index);
    final statusColor = _statusColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                            lessonPlan['judul'] ??
                                lessonPlan['title'] ??
                                'No Title',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            lessonPlan['mata_pelajaran_nama'] ??
                                lessonPlan['subject_name'] ??
                                'No Subject',
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _statusLabel(),
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
                const SizedBox(height: 10),
                // Info tags: class + teacher
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildInfoTag(
                      icon: Icons.class_,
                      label: lessonPlan['kelas_nama'] ??
                          lessonPlan['class_name'] ??
                          'No Class',
                    ),
                    _buildInfoTag(
                      icon: Icons.person_outline,
                      label: lessonPlan['teacher_name'] ??
                          lessonPlan['guru_nama'] ??
                          'No Teacher',
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildCircleActionButton(
                      icon: Icons.visibility_outlined,
                      color: primaryColor,
                      onPressed: onTap,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _buildCircleActionButton(
                      icon: Icons.edit_outlined,
                      color: ColorUtils.warning600,
                      onPressed: onUpdateStatus,
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
