// API helper methods for TeacherScheduleController.
// Handles schedule API calls and response processing.

import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';

/// Result of [TeacherScheduleApiHelper.fetchScheduleFromApi].
///
/// [schedules] and [availableClasses] are non-null on success.
/// [error] is non-null on failure.
class LoadScheduleResult {
  final List<dynamic>? schedules;
  final List<Map<String, String>>? availableClasses;
  final String? error;

  const LoadScheduleResult({this.schedules, this.availableClasses, this.error});

  bool get isSuccess => error == null && schedules != null;
}

/// Helper class for schedule API operations.
class TeacherScheduleApiHelper {
  /// Fetches the teacher's schedule from the API.
  /// Cache writing and memory cache updates are done in the screen
  /// after a successful fetch so the screen controls its own fields.
  ///
  /// Returns [LoadScheduleResult]; check [LoadScheduleResult.error]
  /// to detect failure.
  ///
  /// Like `ScheduleController@index` in Laravel returning JSON.
  static Future<LoadScheduleResult> fetchScheduleFromApi({
    required String teacherId,
    required String semesterToUse,
    required String academicYearToUse,
    required bool isHomeroomView,
    required Map<String, dynamic>? selectedHomeroomClass,
  }) async {
    try {
      AppLogger.debug('schedule', 'FETCHING SCHEDULE WITH:');
      AppLogger.debug('schedule', '- Teacher ID: $teacherId');
      AppLogger.debug('schedule', '- Semester: $semesterToUse');
      AppLogger.debug('schedule', '- Academic Year: $academicYearToUse');

      dynamic scheduleData;

      if (isHomeroomView && selectedHomeroomClass != null) {
        final classId = selectedHomeroomClass['id'].toString();
        final result = await getIt<ApiScheduleService>().getSchedulesPaginated(
          classId: classId,
          semesterId: semesterToUse,
          academicYearId: academicYearToUse,
          limit: 100,
        );
        scheduleData = result['data'] ?? [];
      } else {
        scheduleData = await getIt<ApiScheduleService>().getFilteredSchedule(
          teacherId: teacherId,
          semester: semesterToUse,
          academicYear: academicYearToUse,
        );
      }

      final schedules = scheduleData is List ? scheduleData : [];

      AppLogger.info(
        'schedule',
        'Total schedule items loaded: ${schedules.length}',
      );

      // Extract unique classes for filter dropdown
      final uniqueClasses = <String, String>{};
      for (final item in schedules) {
        final id =
            item['class_id']?.toString() ?? item['kelas_id']?.toString() ?? '';
        final name =
            item['class_name']?.toString() ??
            item['kelas_nama']?.toString() ??
            '';
        if (id.isNotEmpty && name.isNotEmpty) {
          uniqueClasses[id] = name;
        }
      }
      final classes =
          uniqueClasses.entries
              .map((e) => {'id': e.key, 'name': e.value})
              .toList()
            ..sort((a, b) => a['name']!.compareTo(b['name']!));

      return LoadScheduleResult(
        schedules: schedules,
        availableClasses: classes,
      );
    } catch (e) {
      AppLogger.error('schedule', 'Error load jadwal: $e');
      return LoadScheduleResult(error: e.toString());
    }
  }
}
