/// Data models for admin attendance report controller results.
///
/// Separates model classes from the main controller for clarity.
library;

import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_grid_data.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';

/// Result returned by [AdminAttendanceReportController.fetchData].
/// Contains the new attendance summary items and updated pagination state.
class FetchDataResult {
  final List<AttendanceSummary> items;
  final bool hasMoreData;
  final int nextPage;

  const FetchDataResult({
    required this.items,
    required this.hasMoreData,
    required this.nextPage,
  });
}

/// Result returned by [AdminAttendanceReportController.loadTableData].
class TableDataResult {
  final List<dynamic> studentList;
  final List<String> uniqueDates;
  final List<String> uniqueSubjectIds;
  final Map<String, String> dateLabels;
  final AttendanceDataSource dataSource;

  const TableDataResult({
    required this.studentList,
    required this.uniqueDates,
    required this.uniqueSubjectIds,
    required this.dateLabels,
    required this.dataSource,
  });
}
