// Summary card for individual attendance sessions in the detail sheet.
// Shows date, class, subject, attendance counts with circular indicator.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_summary_item.dart';

class AttendanceSummaryCard extends StatelessWidget {
  final AttendanceSummaryItem summary;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// When true the trailing trash icon is replaced by a check/uncheck
  /// indicator and `onTap` toggles selection instead of opening the
  /// detail. The host sheet enters this mode via a long-press; see
  /// [AttendanceDetailSheet]'s multi-select branch.
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;

  const AttendanceSummaryCard({
    super.key,
    required this.summary,
    required this.primaryColor,
    required this.languageProvider,
    required this.onTap,
    required this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final rate = summary.totalStudent > 0
        ? (summary.present / summary.totalStudent * 100).round()
        : 0;
    final pctColor = rate >= 80
        ? ColorUtils.success600
        : rate >= 60
        ? ColorUtils.warning600
        : ColorUtils.error600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Tint the card while it's selected so the multi-select
            // state reads at a glance.
            color: isSelected
                ? primaryColor.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? primaryColor : ColorUtils.slate200,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular percentage
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: summary.totalStudent > 0
                            ? summary.present / summary.totalStudent
                            : 0,
                        strokeWidth: 4,
                        backgroundColor: ColorUtils.slate100,
                        color: pctColor,
                      ),
                    ),
                    Text(
                      '$rate%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pctColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    Text(
                      DateFormat(
                        'EEEE, d MMMM yyyy',
                        'id_ID',
                      ).format(summary.date),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Class + Subject + Lesson Hour
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${summary.className ?? '-'} · ${summary.subjectName}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (summary.lessonHourName != null &&
                            summary.lessonHourName!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.access_time_rounded,
                            size: 10,
                            color: ColorUtils.slate400,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            summary.lessonHourName!,
                            style: TextStyle(
                              fontSize: 10,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Counts row
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 12,
                          color: ColorUtils.success600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${summary.present}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.success600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.cancel_outlined,
                          size: 12,
                          color: ColorUtils.error600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${summary.absent}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.error600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.people_outline,
                          size: 12,
                          color: ColorUtils.slate400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${summary.totalStudent}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing affordance — selection check in multi-select
              // mode, single-row trash icon otherwise.
              if (isSelectionMode)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? primaryColor : ColorUtils.slate300,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                )
              else
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorUtils.error600.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ColorUtils.error600.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: ColorUtils.error600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
