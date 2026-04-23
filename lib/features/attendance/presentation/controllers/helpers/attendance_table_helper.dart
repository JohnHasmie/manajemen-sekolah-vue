/// Table view data loading helper for admin attendance report.
///
/// Encapsulates complex table data processing logic.
library;

import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/helpers/attendance_result_models.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_grid_data.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendanceTableHelper {
  final WidgetRef ref;

  AttendanceTableHelper(this.ref);

  /// Fetches all data needed for Syncfusion DataGrid table view.
  ///
  /// Returns [TableDataResult] with processed students, dates, and
  /// ready-to-use [AttendanceDataSource].
  Future<TableDataResult> loadTableData({
    required String classId,
    required String? selectedDateFilter,
    required List<dynamic> subjectList,
  }) async {
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();

    // Resolve date range
    String? startDate;
    String? endDate;
    final now = DateTime.now();

    if (selectedDateFilter == 'today') {
      startDate = DateFormat('yyyy-MM-dd').format(now);
      endDate = startDate;
    } else if (selectedDateFilter == 'week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
      endDate = DateFormat('yyyy-MM-dd').format(endOfWeek);
    } else {
      // Default to current month
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
      endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);
    }

    // Parallel fetch: students + attendance records
    final students = await getIt<ApiClassService>().getStudentsByClassId(
      classId,
      academicYearId: academicYearId,
    );

    final attendanceResult = await AttendanceService.getAttendancePaginated(
      page: 1,
      limit: 1000,
      classId: classId,
      dateStart: startDate,
      dateEnd: endDate,
      academicYearId: academicYearId,
    );

    final List<dynamic> attendanceData = attendanceResult['data'] ?? [];

    // Process attendance records into a flat map
    final Set<String> dateSet = {};
    final Set<String> subjectIdSet = {};
    final Map<String, dynamic> attMap = {};

    for (final record in attendanceData) {
      final String? date = record['date'];
      final String? sId = record['student_id']?.toString();
      final String? subjId = record['subject_id']?.toString();
      final String? status = record['status'];

      if (date != null && sId != null && subjId != null) {
        dateSet.add(date);
        subjectIdSet.add(subjId);
        attMap['$sId-$date-$subjId'] = status;
      }
    }

    // Build subject name lookup map
    final Map<String, dynamic> subjectMap = {};
    for (final s in subjectList) {
      subjectMap[s['id'].toString()] = s['name'];
    }

    // Map students to AttendanceGridData
    final List<AttendanceGridData> gridData = [];
    for (final student in students) {
      final sData = student is Map ? student : <dynamic, dynamic>{};
      var id = sData['id']?.toString() ?? sData['student_id']?.toString() ?? '';
      var nis = sData['nis'] ?? sData['student_number'] ?? '-';
      var name = sData['name'] ?? sData['nama'] ?? 'Unknown';

      // Normalize: sometimes nested under 'student' key
      if (sData.containsKey('student')) {
        final inner = sData['student'];
        if (id.isEmpty) id = inner['id']?.toString() ?? '';
        nis = inner['nis'] ?? inner['student_number'] ?? nis;
        name = inner['name'] ?? inner['nama'] ?? name;
      }

      gridData.add(
        AttendanceGridData(
          studentId: id,
          nis: nis.toString(),
          name: name.toString(),
          attendance: attMap,
        ),
      );
    }

    final sortedDates = dateSet.toList()..sort();

    // Build date → day-of-month label map
    final Map<String, String> dateLabels = {};
    for (final d in sortedDates) {
      final DateTime? dt = AppDateUtils.parseApiDate(d);
      dateLabels[d] = dt != null ? dt.day.toString() : d;
    }

    return TableDataResult(
      studentList: students,
      uniqueDates: sortedDates,
      uniqueSubjectIds: subjectIdSet.toList(),
      dateLabels: dateLabels,
      dataSource: AttendanceDataSource(
        students: gridData,
        dates: sortedDates,
        subjectIds: subjectIdSet.toList(),
        subjectMap: subjectMap,
      ),
    );
  }
}
