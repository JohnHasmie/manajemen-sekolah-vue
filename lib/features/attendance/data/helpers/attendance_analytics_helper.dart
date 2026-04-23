import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper service for attendance analytics and reporting.
/// Handles statistics, dashboards, and read status operations.
class AttendanceAnalyticsHelper {
  /// Fetches attendance statistics.
  Future<Map<String, dynamic>> getAttendanceStats({
    String? date,
    String? classId,
    String? subjectId,
    String? teacherId,
    String? lessonHourId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      queryParams['subject_id'] = subjectId;
    }
    if (teacherId != null && teacherId.isNotEmpty) {
      queryParams['teacher_id'] = teacherId;
    }
    if (lessonHourId != null && lessonHourId.isNotEmpty) {
      queryParams['lesson_hour_id'] = lessonHourId;
    }

    try {
      final response = await dioClient.get(
        ApiEndpoints.attendanceStats,
        queryParameters: queryParams,
      );
      final result = response.data;
      return result['data'] ?? {};
    } catch (e) {
      AppLogger.error('api', 'Error fetching attendance stats: $e');
      return {};
    }
  }

  /// Fetches count of unread attendance records.
  Future<int> getUnreadPresenceCount() async {
    try {
      final response = await dioClient.get(ApiEndpoints.attendanceUnreadCount);
      final result = response.data;
      return int.tryParse(result['count']?.toString() ?? '0') ?? 0;
    } catch (e) {
      AppLogger.error('api', 'Error fetching unread presence count: $e');
      return 0;
    }
  }

  /// Fetches attendance dashboard chart data.
  Future<List<dynamic>> getAttendanceDashboardChart({
    String? academicYearId,
    String? month,
    String? week,
    String? role,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (academicYearId != null) params['academic_year_id'] = academicYearId;
      if (month != null) params['month'] = month;
      if (week != null) params['week'] = week;
      if (role != null) params['role'] = role;

      final response = await dioClient.get(
        ApiEndpoints.attendanceDashboardChart,
        queryParameters: params,
      );
      final result = response.data;

      if (result is List) return result;
      return [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching attendance dashboard chart: $e');
      return [];
    }
  }
}
