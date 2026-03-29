// AdminActivityCard — a tappable row card showing one class activity in the
// admin drill-down (third level: Activity list for a teacher + subject).
//
// Extracted from `AdminClassActivityScreenState._buildActivityCard`.
// Think of this like a Vue `<AdminActivityCard :activity="item" @tap />` —
// a pure presentational widget; the parent handles detail display via [onTap].

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_info_tag.dart';

/// A single card representing one class activity in the admin monitoring screen.
///
/// Constructor params (Vue-style props):
/// - [activity] — raw API map for the activity entry
/// - [onTap]    — called when the card is tapped; parent calls [_showActivityDetail]
class AdminActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;

  /// Fired when the user taps the card.
  /// The parent screen opens the detail dialog in response — this widget is
  /// stateless and has no knowledge of the dialog logic.
  final VoidCallback onTap;

  const AdminActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  // Formats a nullable date string to dd/MM/yyyy, mirroring
  // `AdminClassActivityScreenState._formatDate`.
  String _formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  @override
  Widget build(BuildContext context) {
    final isAssignment = activity['type'] == 'assignment';
    final isSpecificTarget = activity['target'] == 'specific';
    final accentColor = isAssignment
        ? ColorUtils.corporateBlue600
        : ColorUtils.success600;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container (task vs material)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isAssignment
                        ? Icons.assignment_outlined
                        : Icons.menu_book_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                // Info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['title'] ?? 'Judul Kegiatan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${activity['subject_name'] ?? '-'} • ${activity['class_name'] ?? '-'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          ActivityInfoTag(
                            icon: Icons.calendar_today_outlined,
                            label:
                                '${activity['day'] ?? '-'} • ${_formatDate(activity['date']?.toString())}',
                          ),
                          ActivityInfoTag(
                            icon: isAssignment
                                ? Icons.assignment_outlined
                                : Icons.menu_book_outlined,
                            label: isAssignment ? 'Tugas' : 'Materi',
                            tagColor: accentColor,
                          ),
                          ActivityInfoTag(
                            icon: isSpecificTarget
                                ? Icons.person_outline
                                : Icons.group_outlined,
                            label: isSpecificTarget ? 'Khusus' : 'Semua',
                            tagColor: isSpecificTarget
                                ? ColorUtils.corporateBlue600
                                : ColorUtils.success600,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                // Chevron
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: ColorUtils.slate500,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
