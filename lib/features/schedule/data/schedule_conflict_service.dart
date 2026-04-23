/// schedule_conflict_service.dart - Schedule conflict detection.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for checking schedule conflicts.
class ScheduleConflictService {
  /// Checks for schedule conflicts before creating/updating a schedule.
  /// Like a Laravel validation rule that queries for overlapping slots.
  /// Returns a list of conflicting schedules (empty if no conflicts).
  /// [excludeScheduleId] - Exclude the current schedule when editing.
  Future<List<dynamic>> getConflictingSchedules({
    required List<String> daysIds,
    required String classId,
    required String teacherId,
    required String semesterId,
    required String academicYearId,
    required String lessonHourId,
    String? excludeScheduleId,
  }) async {
    try {
      String url = '/teaching-schedule/conflicts?';
      url += 'days_ids=${daysIds.join(',')}&';
      url += 'class_id=$classId&';
      url += 'teacher_id=$teacherId&';
      url += 'semester_id=$semesterId&';
      url += 'academic_year_id=$academicYearId&';
      url += 'lesson_hour_id=$lessonHourId&';

      if (excludeScheduleId != null) {
        url += 'exclude_id=$excludeScheduleId&';
      }

      final response = await dioClient.get(url);
      final result = response.data;
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('schedule', 'Error checking conflicts: $e');
      return [];
    }
  }
}
