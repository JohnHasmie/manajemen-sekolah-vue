// Extracted from teacher_attendance_screen.dart (_buildSummaryCard +
// _buildInfoTag). Like a Vue `<AttendanceSummaryCard>` component -- renders
// one summary row in the Results tab list with subject info, attendance counts,
// a progress bar, a detail button, and a delete button.
//
// Stateless: the parent passes callbacks for navigation and deletion so this
// widget has zero business logic of its own, just pure UI. In Laravel terms
// it's like a Blade partial -- it only renders, never mutates.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_summary_item.dart';

/// A card widget that displays a single [AttendanceSummaryItem] in the
/// Results tab.
///
/// Parameters (like Vue props):
/// - [summary]          -- the data model to display
/// - [primaryColor]     -- role-based accent color passed from the screen
/// - [languageProvider] -- for translating UI strings
/// - [onTap]            -- called when the user taps the card body or "Detail"
/// - [onDelete]         -- called when the user taps the delete button
class AttendanceSummaryCard extends StatelessWidget {
  final AttendanceSummaryItem summary;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AttendanceSummaryCard({
    super.key,
    required this.summary,
    required this.primaryColor,
    required this.languageProvider,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final attendanceRate = summary.totalStudent > 0
        ? (summary.present / summary.totalStudent * 100).round()
        : 0;

    final progressColor = attendanceRate >= 80
        ? ColorUtils.success600
        : attendanceRate >= 60
        ? ColorUtils.warning600
        : ColorUtils.error600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: subject icon + info + delete button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.book_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Subject name + class + lesson hour + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.subjectName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.class_outlined,
                              size: 12,
                              color: primaryColor,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              summary.className ?? 'Kelas',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (summary.lessonHourName != null &&
                                summary.lessonHourName!.isNotEmpty) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                  color: ColorUtils.slate400,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                summary.lessonHourName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat(
                            'EEEE, dd MMMM yyyy',
                            'id_ID',
                          ).format(summary.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Delete button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onDelete,
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
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
                          size: 16,
                          color: ColorUtils.error600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              Divider(color: ColorUtils.slate100, height: 1),
              const SizedBox(height: 10),

              // Attendance info tags + detail button
              Row(
                children: [
                  _AttendanceInfoTag(
                    icon: Icons.check_circle_outline,
                    label: '${summary.present} Hadir',
                    tagColor: ColorUtils.success600,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _AttendanceInfoTag(
                    icon: Icons.cancel_outlined,
                    label: '${summary.absent} Absen',
                    tagColor: ColorUtils.error600,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _AttendanceInfoTag(
                    icon: Icons.people_outline,
                    label: '${summary.totalStudent} Siswa',
                    tagColor: primaryColor,
                  ),
                  const Spacer(),
                  // Detail button
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 12,
                            color: primaryColor,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Detail',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Attendance progress bar
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: LinearProgressIndicator(
                  value: summary.totalStudent > 0
                      ? summary.present / summary.totalStudent
                      : 0,
                  minHeight: 6,
                  backgroundColor: ColorUtils.slate200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$attendanceRate% ${languageProvider.getTranslatedText({'en': 'Attendance', 'id': 'Kehadiran'})}',
                style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper widget
// ---------------------------------------------------------------------------

/// A small pill-shaped tag with an icon and a label.
/// Extracted from the original `_buildInfoTag` method.
class _AttendanceInfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tagColor;

  const _AttendanceInfoTag({
    required this.icon,
    required this.label,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor!.withValues(alpha: 0.1)
            : ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(
          color: tagColor != null
              ? tagColor!.withValues(alpha: 0.2)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: tagColor ?? ColorUtils.slate600),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: tagColor ?? ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
