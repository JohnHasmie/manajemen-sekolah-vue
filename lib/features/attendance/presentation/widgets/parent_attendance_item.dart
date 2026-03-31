// Extracted from parent_attendance_screen.dart (_buildAttendanceItem).
// Like a Vue `<AttendanceItem>` component -- a Material card row showing
// date box, subject name, day label, info tags, status badge, and unread dot.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer;
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_info_tag.dart';

/// A single attendance record row card for the parent view.
///
/// Uses [ConsumerWidget] because it calls [ref.watch] on [languageRiverpod]
/// to localise date format strings — like a Vue component using `$i18n.locale`
/// in a computed property.
///
/// Parameters (like Vue props):
/// - [record]          -- the [Attendance] model to render
/// - [primaryColor]    -- role-based accent color (wali = green/teal)
/// - [statusColor]     -- resolved color for [record.status]
/// - [statusText]      -- translated display string for [record.status]
/// - [statusIcon]      -- icon corresponding to [record.status]
/// - [normalizedStatus]-- lowercase Indonesian status key (hadir/terlambat/…)
class ParentAttendanceItem extends ConsumerWidget {
  final Attendance record;
  final Color primaryColor;
  final Color statusColor;
  final String statusText;
  final IconData statusIcon;
  final String normalizedStatus;

  const ParentAttendanceItem({
    super.key,
    required this.record,
    required this.primaryColor,
    required this.statusColor,
    required this.statusText,
    required this.statusIcon,
    required this.normalizedStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageRiverpod).currentLanguage;
    final locale = currentLanguage == 'id' ? 'id_ID' : 'en_US';
    final date = record.date;
    final subjectName =
        record.subjectName ?? AppLocalizations.subject.tr;
    final lessonHourName = record.lessonHourName ?? '';
    final isRead = record.isRead;

    final String day = DateFormat('EEEE', locale).format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: date box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        DateFormat('MMM', locale).format(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Middle: subject + day + info tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Info tags row
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          ParentAttendanceInfoTag(
                            icon: Icons.calendar_today_outlined,
                            text: DateFormat('dd MMM yyyy', locale).format(date),
                          ),
                          if (lessonHourName.isNotEmpty)
                            ParentAttendanceInfoTag(
                              icon: Icons.access_time_outlined,
                              text: lessonHourName,
                            ),
                          ParentAttendanceInfoTag(
                            icon: statusIcon,
                            text: statusText,
                            tagColor: statusColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Right: unread dot
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: ColorUtils.error600,
                      shape: BoxShape.circle,
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
