/// Summary data loading helper for admin attendance report.
///
/// Encapsulates attendance summary fetching and mapping logic.
library;

import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/helpers/attendance_result_models.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendanceSummaryHelper {
  final WidgetRef ref;

  AttendanceSummaryHelper(this.ref);

  /// Fetches one page of attendance summaries from the API.
  ///
  /// Handles all filter params, maps raw JSON to [AttendanceSummary]
  /// objects, and returns the result.
  Future<FetchDataResult> fetchData({
    required int currentPage,
    required int perPage,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required List<dynamic> lessonHours,
  }) async {
    // Resolve date filter params
    String? filterDate;
    String? filterDateStart;
    String? filterDateEnd;

    if (selectedDateFilter == 'today') {
      filterDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (selectedDateFilter == 'week') {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      filterDateStart = DateFormat('yyyy-MM-dd').format(startOfWeek);
      filterDateEnd = DateFormat('yyyy-MM-dd').format(endOfWeek);
    } else if (selectedDateFilter == 'month') {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      filterDateStart = DateFormat('yyyy-MM-dd').format(startOfMonth);
      filterDateEnd = DateFormat('yyyy-MM-dd').format(endOfMonth);
    } else if (selectedDateFilter == 'semester') {
      // Fix-DD — last 6 months (rolling) through today.
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 6, now.day);
      filterDateStart = DateFormat('yyyy-MM-dd').format(start);
      filterDateEnd = DateFormat('yyyy-MM-dd').format(now);
    } else if (selectedDateFilter == 'year') {
      // Fix-DD — full current calendar year.
      final now = DateTime.now();
      filterDateStart = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(now.year, 1, 1));
      filterDateEnd = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(now.year, 12, 31));
    }

    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();

    final result = await AttendanceService.getAttendanceSummaryPaginated(
      page: currentPage,
      limit: perPage,
      subjectId: selectedSubjectIds.isNotEmpty
          ? selectedSubjectIds.first
          : null,
      classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
      date: filterDate,
      dateStart: filterDateStart,
      dateEnd: filterDateEnd,
      academicYearId: academicYearId,
      dayIds: selectedDayIds,
      lessonHourIds: selectedLessonHourIds,
    );

    final List<dynamic> data = result['data'] ?? [];
    final Map<String, dynamic> pagination = result['pagination'] ?? {};

    final List<AttendanceSummary> newItems = data.map((item) {
      final lessonHourId = item['lesson_hour_id']?.toString();
      String? lessonHourName;
      if (lessonHourId != null && lessonHourId.isNotEmpty) {
        final lh = lessonHours.firstWhere(
          (h) => h['id']?.toString() == lessonHourId,
          orElse: () => null,
        );
        if (lh != null) {
          lessonHourName = lh['name'];
        }
      }

      return AttendanceSummary(
        subjectId: item['subject_id']?.toString() ?? '',
        subjectName: item['subject_name'] ?? 'Unknown',
        date: AppDateUtils.parseApiDate(item['date']) ?? DateTime.now(),
        totalStudents:
            int.tryParse(item['total_students']?.toString() ?? '0') ?? 0,
        present: int.tryParse(item['present']?.toString() ?? '0') ?? 0,
        absent: int.tryParse(item['absent']?.toString() ?? '0') ?? 0,
        classId: item['class_id']?.toString() ?? '',
        className: item['class_name'] ?? 'Unknown',
        lessonHourId: lessonHourId,
        lessonHourName: lessonHourName,
        academicYearId: academicYearId,
      );
    }).toList();

    AppLogger.info(
      'attendance',
      'Fetched ${newItems.length} summaries for page $currentPage',
    );

    final hasMoreData = pagination['has_next_page'] ?? false;
    final nextPage = hasMoreData ? currentPage + 1 : currentPage;

    return FetchDataResult(
      items: newItems,
      hasMoreData: hasMoreData,
      nextPage: nextPage,
    );
  }
}
