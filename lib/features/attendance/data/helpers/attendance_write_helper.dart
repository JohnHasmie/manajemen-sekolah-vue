import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper service for attendance write/mutation operations.
/// Handles create, update, and delete operations.
class AttendanceWriteHelper {
  /// Creates a single attendance record.
  Future<dynamic> createAttendance(Map<String, dynamic> data) async {
    final response = await dioClient.post(ApiEndpoints.attendance, data: data);
    await CacheInvalidationService.onAttendanceChanged();
    return response.data;
  }

  /// Bulk creates/updates attendance for multiple students.
  Future<Map<String, dynamic>> createBulkAttendance({
    required String teacherId,
    required String subjectId,
    required String classId,
    required String date,
    String? lessonHourId,
    required List<Map<String, dynamic>> attendances,
  }) async {
    final response = await dioClient.post(
      ApiEndpoints.attendanceBulk,
      data: {
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'class_id': classId,
        'date': date,
        'lesson_hour_id': lessonHourId,
        'attendances': attendances,
      },
    );

    final result = response.data;
    if (result is Map<String, dynamic>) {
      await CacheInvalidationService.onAttendanceChanged();
      return result;
    }
    return {'success': 0, 'failed': 0, 'errors': []};
  }

  /// Deletes attendance records by criteria.
  Future<dynamic> deleteAttendance({
    required String subjectId,
    required String classId,
    required String date,
    String? lessonHourId,
  }) async {
    try {
      final params = <String, dynamic>{
        'subject_id': subjectId,
        'class_id': classId,
        'date': date,
      };
      if (lessonHourId != null) params['lesson_hour_id'] = lessonHourId;

      final response = await dioClient.delete(
        ApiEndpoints.attendance,
        queryParameters: params,
      );
      await CacheInvalidationService.onAttendanceChanged();
      return response.data;
    } catch (e) {
      AppLogger.error('api', 'AttendanceService.deleteAttendance error: $e');
      rethrow;
    }
  }

  /// Deletes attendance summary by teacher/subject/class/date.
  ///
  /// Routes through `DELETE /attendance/bulk` (bulkDestroy) — the
  /// previous `DELETE /attendance?...` URL had no matching backend
  /// route (only `/attendance/{id}`, `/attendance/bulk` and
  /// `/attendances/{id}` exist), which 404'd and surfaced as the
  /// generic "system error" toast on the teacher Presensi screen.
  /// `bulkDestroy` already accepts the same teacher_id / subject_id /
  /// date / class_id / lesson_hour_id filters and returns a count.
  Future<dynamic> deleteAttendanceSummary({
    required String teacherId,
    required String subjectId,
    required String date,
    String? classId,
    String? lessonHourId,
  }) async {
    final params = <String, String>{
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'date': date,
      if (classId != null && classId.isNotEmpty) 'class_id': classId,
      if (lessonHourId != null && lessonHourId.isNotEmpty)
        'lesson_hour_id': lessonHourId,
    };

    final response = await dioClient.delete(
      '${ApiEndpoints.attendance}/bulk',
      queryParameters: params,
    );
    await CacheInvalidationService.onAttendanceChanged();
    return response;
  }

  /// Marks a student's attendance as read.
  Future<void> markAttendanceRead({required String studentId}) async {
    try {
      await dioClient.post(
        ApiEndpoints.attendanceMarkRead,
        data: {'student_id': studentId},
      );
    } catch (e) {
      AppLogger.error('api', 'Error marking attendance read: $e');
    }
  }

  /// Marks multiple attendance records as read.
  Future<void> markPresenceAsRead(List<String> attendanceIds) async {
    if (attendanceIds.isEmpty) return;
    try {
      await dioClient.post(
        ApiEndpoints.attendanceMarkRead,
        data: {'attendance_ids': attendanceIds},
      );
    } catch (e) {
      AppLogger.error('api', 'Error marking presence as read: $e');
    }
  }
}
