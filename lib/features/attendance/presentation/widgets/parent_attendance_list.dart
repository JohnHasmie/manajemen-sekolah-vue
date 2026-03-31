// Extracted from parent_attendance_screen.dart (_buildAttendanceList).
// Like a Vue `<AttendanceList>` component -- filters and sorts the full
// attendance data then renders either an empty-state or a scrollable ListView.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_item.dart';

/// Filtered, sorted list of attendance records for the parent view.
///
/// Stateless: all filtering inputs and computed helpers are passed in as
/// constructor params — like a Vue component receiving computed props. The
/// parent screen owns the state; this widget only renders.
///
/// Parameters (like Vue props):
/// - [attendanceData]         -- full unfiltered list from the screen state
/// - [selectedMonthFilter]    -- active month value string, or null
/// - [selectedSemesterFilter] -- active semester value string, or null
/// - [searchQuery]            -- current search text
/// - [hasActiveFilter]        -- true when any filter is applied
/// - [primaryColor]           -- role-based accent color
/// - [onItemVisible]          -- callback fired when a record scrolls into view
///                              (used for auto mark-as-read)
/// - [normalizeStatus]        -- maps raw status to canonical key (hadir/…)
/// - [getStatusColor]         -- resolves a status key to its [Color]
/// - [getStatusIcon]          -- resolves a status key to its [IconData]
/// - [getTranslatedStatus]    -- translates a status key to display string
class ParentAttendanceList extends StatelessWidget {
  final List<Attendance> attendanceData;
  final String? selectedMonthFilter;
  final String? selectedSemesterFilter;
  final String searchQuery;
  final bool hasActiveFilter;
  final Color primaryColor;
  final void Function(Attendance record) onItemVisible;
  final String Function(dynamic rawStatus) normalizeStatus;
  final Color Function(String status) getStatusColor;
  final IconData Function(String status) getStatusIcon;
  final String Function(String? status) getTranslatedStatus;

  const ParentAttendanceList({
    super.key,
    required this.attendanceData,
    required this.selectedMonthFilter,
    required this.selectedSemesterFilter,
    required this.searchQuery,
    required this.hasActiveFilter,
    required this.primaryColor,
    required this.onItemVisible,
    required this.normalizeStatus,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.getTranslatedStatus,
  });

  List<Attendance> _filtered() {
    return attendanceData.where((record) {
      final date = record.date;

      // Month filter
      if (selectedMonthFilter != null) {
        if (date.month.toString() != selectedMonthFilter) return false;
      }

      // Semester filter (1: July–Dec, 2: Jan–June)
      if (selectedSemesterFilter != null) {
        final semester = (date.month >= 7) ? '1' : '2';
        if (semester != selectedSemesterFilter) return false;
      }

      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final subject = (record.subjectName ?? '').toLowerCase();
        final status = record.status.toLowerCase();
        if (!subject.contains(query) && !status.contains(query)) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) =>
          b.date.toIso8601String().compareTo(a.date.toIso8601String()));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Icon(
                Icons.calendar_today,
                size: 36,
                color: ColorUtils.slate400,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppLocalizations.noPresenceData.tr,
              style: TextStyle(
                color: ColorUtils.slate700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasActiveFilter) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try adjusting your filters',
                style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No attendance records found for this year',
                style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final record = filtered[index];
        return Builder(
          builder: (context) {
            onItemVisible(record);
            final status = normalizeStatus(record.status);
            return ParentAttendanceItem(
              record: record,
              primaryColor: primaryColor,
              statusColor: getStatusColor(status),
              statusText: getTranslatedStatus(status),
              statusIcon: getStatusIcon(status),
              normalizedStatus: status,
            );
          },
        );
      },
    );
  }
}
