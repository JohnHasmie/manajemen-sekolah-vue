// Admin schedule card widget extracted from
// TeachingScheduleManagementScreenState._buildScheduleCard().
//
// Like a Vue `<AdminScheduleCard :schedule="..." :index="..." />` component —
// purely presentational, all data and action callbacks are passed in as
// constructor params. No providers are read here.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_widgets.dart';

/// A single schedule entry card for the admin list view.
///
/// Displays subject, teacher, class, day, and time; with optional Edit/Delete
/// action buttons (hidden when [isReadOnly] is true).
///
/// In Laravel terms: like a Blade partial
/// `@include('schedule.partials.admin-card', ['schedule' => $s])`.
class AdminScheduleCard extends StatelessWidget {
  const AdminScheduleCard({
    super.key,
    required this.schedule,
    required this.index,
    required this.isReadOnly,
    required this.primaryColor,
    required this.dayLabel,
    required this.timeLabel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  /// The raw schedule map from the API.
  final Map<String, dynamic> schedule;

  /// Zero-based position in the list — used to determine the card's accent color.
  final int index;

  /// When true, the Edit and Delete buttons are hidden.
  final bool isReadOnly;

  /// Role-specific accent colour (admin blue).
  final Color primaryColor;

  /// Pre-formatted day label (e.g. "Senin, Rabu") built by the parent.
  final String dayLabel;

  /// Pre-formatted time range (e.g. "07:00 - 08:30") built by the parent.
  final String timeLabel;

  /// Called when the user taps the card body — opens the detail dialog.
  final VoidCallback onTap;

  /// Called when the user taps the edit icon button.
  final VoidCallback onEdit;

  /// Called when the user taps the delete icon button.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getColorForIndex(index);
    final subjectName = schedule['mata_pelajaran_nama'] ?? 'No Subject';
    final teacherName = schedule['guru_nama'] ?? '-';
    final className = schedule['kelas_nama'] ?? '-';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colored icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject name
                      Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Teacher name
                      Text(
                        teacherName,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Info tags row
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ScheduleInfoTag(
                            icon: Icons.school_outlined,
                            text: className,
                          ),
                          ScheduleInfoTag(
                            icon: Icons.today_outlined,
                            text: dayLabel,
                          ),
                          ScheduleInfoTag(
                            icon: Icons.access_time_outlined,
                            text: timeLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons column
                if (!isReadOnly) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScheduleCircleActionButton(
                        icon: Icons.edit_outlined,
                        color: primaryColor,
                        onPressed: onEdit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ScheduleCircleActionButton(
                        icon: Icons.delete_outline,
                        color: ColorUtils.error600,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
