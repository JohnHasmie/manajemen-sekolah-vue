/// Export data helper for admin attendance report.
///
/// Encapsulates export row building logic.
library;

import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendanceExportHelper {
  final WidgetRef ref;

  AttendanceExportHelper(this.ref);

  /// Builds export row list for a single month without UI calls.
  ///
  /// Like a Laravel Export class that prepares data rows. Actual file
  /// download (which needs BuildContext) is done by screen after
  /// confirming it is still mounted.
  /// Returns empty list when nothing to export for this month.
  Future<List<Map<String, dynamic>>> buildExportRows({
    required DateTime month,
    required Map<String, dynamic> selectedClassData,
    required List<dynamic> subjectList,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
    final endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);

    final classId = selectedClassData['id'];
    final className = selectedClassData['name'];

    final academicYearProvider = ref.read(academicYearRiverpod);
    final academicYearId = academicYearProvider.selectedAcademicYear?['id']
        ?.toString();
    final academicYearName =
        academicYearProvider.selectedAcademicYear?['year']?.toString() ?? '-';

    final students = await getIt<ApiClassService>().getStudentsByClassId(
      classId,
      academicYearId: academicYearId,
    );

    final attendanceResult = await AttendanceService.getAttendancePaginated(
      page: 1,
      limit: 2000,
      classId: classId,
      dateStart: startDate,
      dateEnd: endDate,
      academicYearId: academicYearId,
    );

    final List<dynamic> attendanceData = attendanceResult['data'] ?? [];
    if (attendanceData.isEmpty) return [];

    // Build subject name lookup
    final Map<String, String> subjectMap = {};
    for (final s in subjectList) {
      subjectMap[s['id'].toString()] = s['name'];
    }

    final List<Map<String, dynamic>> exportList = [];

    for (final record in attendanceData) {
      final sId = record['student_id'].toString();

      var studentMap = students.firstWhere((s) {
        final id = s['id']?.toString();
        if (id != null && id == sId) return true;
        if (s['student'] != null && s['student']['id']?.toString() == sId) {
          return true;
        }
        return false;
      }, orElse: () => null);

      if (studentMap == null) continue;

      // Normalize nested student structure
      if (studentMap['student'] != null) studentMap = studentMap['student'];

      final nis = studentMap['nis'] ?? studentMap['student_number'] ?? '';
      final name = studentMap['name'] ?? studentMap['nama'] ?? 'Unknown';
      final subjId = record['subject_id'].toString();
      final subjectName =
          subjectMap[subjId] ?? record['subject_name'] ?? 'Unknown';

      exportList.add({
        'nis': nis,
        'student_name': name,
        'class_name': className,
        'academic_year': academicYearName,
        'date': record['date'],
        'subject_name': subjectName,
        'status': record['status'],
      });
    }

    return exportList;
  }
}
