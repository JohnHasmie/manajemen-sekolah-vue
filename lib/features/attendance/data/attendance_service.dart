import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';

class AttendanceService {
  // ── Backend query-parameter keys ─────────────────────────────────────────
  // The server uses these exact strings. English snake_case keys are used
  // wherever the backend accepts them; the two date-range keys are Indonesian
  // camelCase because the server contract has not been updated.
  static const _kDateRangeStart = 'tanggalStart';
  static const _kDateRangeEnd = 'tanggalEnd';
  // ─────────────────────────────────────────────────────────────────────────
  /// Fetches attendance (absensi) records with multiple optional filters.
  static Future<List<Attendance>> getAttendance({
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? academicYearId,
    String? lessonHourId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (teacherId != null) queryParams['teacher_id'] = teacherId;
    if (date != null) queryParams['date'] = date;
    if (subjectId != null) queryParams['subject_id'] = subjectId;
    if (studentId != null) queryParams['student_id'] = studentId;
    if (classId != null) queryParams['class_id'] = classId;
    if (academicYearId != null) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (lessonHourId != null) queryParams['lesson_hour_id'] = lessonHourId;

    AppLogger.debug(
      'api',
      '📍 Calling getAbsensi: ${ApiEndpoints.attendance} with params: $queryParams',
    );

    final response = await dioClient.get(
      ApiEndpoints.attendance,
      queryParameters: queryParams,
    );

    final result = response.data;

    if (kDebugMode) {
      AppLogger.debug('api', 'Absensi response type: ${result.runtimeType}');
      if (result is Map) {
        if (result.containsKey('data')) {
          // debug info handled in base api
        }
      }
    }

    if (result is Map && result['data'] is List) {
      return (result['data'] as List).map((json) => Attendance.fromJson(json)).toList();
    } else if (result is List) {
      return result.map((json) => Attendance.fromJson(json)).toList();
    } else {
      AppLogger.warning('api', 'Unexpected response format for absensi');
      return [];
    }
  }

  // Delete absences by summary (teacher, subject, class, date)
  static Future<dynamic> deleteAttendanceSummary({
    required String teacherId,
    required String subjectId,
    required String date,
    String? classId,
    String? lessonHourId,
  }) async {
    String query =
        '${ApiEndpoints.attendance}?teacher_id=$teacherId&subject_id=$subjectId&date=$date';
    if (classId != null && classId.isNotEmpty) {
      query += '&class_id=$classId';
    }
    if (lessonHourId != null && lessonHourId.isNotEmpty) {
      query += '&lesson_hour_id=$lessonHourId';
    }

    return await dioClient.delete(query);
  }

  // Paginated absensi (returns map with data + pagination)
  static Future<Map<String, dynamic>> getAttendancePaginated({
    int page = 1,
    int limit = 20,
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? dateStart,
    String? dateEnd,
    String? academicYearId,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (teacherId != null && teacherId.isNotEmpty) {
        params['teacher_id'] = teacherId;
      }
      if (date != null && date.isNotEmpty) params['date'] = date;
      if (subjectId != null && subjectId.isNotEmpty) {
        params['subject_id'] = subjectId;
      }
      if (studentId != null && studentId.isNotEmpty) {
        params['student_id'] = studentId;
      }
      if (classId != null && classId.isNotEmpty) params['class_id'] = classId;
      if (dateStart != null && dateStart.isNotEmpty) {
        params[_kDateRangeStart] = dateStart;
      }
      if (dateEnd != null && dateEnd.isNotEmpty) params[_kDateRangeEnd] = dateEnd;
      if (academicYearId != null && academicYearId.isNotEmpty) {
        params['academic_year_id'] = academicYearId;
      }

      final response = await dioClient.get(
        ApiEndpoints.attendance,
        queryParameters: params,
      );
      final result = response.data;

      if (result is Map<String, dynamic>) return result;

      if (result is List) {
        return {
          'success': true,
          'data': result,
          'pagination': {
            'total_items': result.length,
            'total_pages': 1,
            'current_page': 1,
            'per_page': limit,
            'has_next_page': false,
            'has_prev_page': false,
          },
        };
      }

      return {'success': false};
    } catch (e) {
      AppLogger.error('api', 'Error getAbsensiPaginated: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getAttendanceSummary({
    String? teacherId,
    String? date,
    String? subjectId,
    String? classId,
    String? academicYearId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (teacherId != null) queryParams['teacher_id'] = teacherId;
    if (date != null) queryParams['date'] = date;
    if (subjectId != null) queryParams['subject_id'] = subjectId;
    if (classId != null) queryParams['class_id'] = classId;
    if (academicYearId != null) {
      queryParams['academic_year_id'] = academicYearId;
    }

    final response = await dioClient.get(
      ApiEndpoints.attendanceSummary,
      queryParameters: queryParams,
    );

    final result = response.data;
    if (result is Map && result['data'] is List) {
      return result['data'];
    }
    return result is List ? result : [];
  }

  static Future<Map<String, dynamic>> getAttendanceSummaryPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? subjectId,
    String? classId,
    String? date,
    String? dateStart,
    String? dateEnd,
    String? academicYearId,
    List<String>? dayIds,
    List<String>? lessonHourIds,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (academicYearId != null && academicYearId.isNotEmpty) {
        params['academic_year_id'] = academicYearId;
      }
      if (teacherId != null && teacherId.isNotEmpty) {
        params['teacher_id'] = teacherId;
      }
      if (subjectId != null && subjectId.isNotEmpty) {
        params['subject_id'] = subjectId;
      }
      if (classId != null && classId.isNotEmpty) params['class_id'] = classId;
      if (date != null && date.isNotEmpty) params['date'] = date;
      if (dateStart != null && dateStart.isNotEmpty) {
        params[_kDateRangeStart] = dateStart;
      }
      if (dateEnd != null && dateEnd.isNotEmpty) params[_kDateRangeEnd] = dateEnd;
      if (dayIds != null && dayIds.isNotEmpty) {
        params['day_ids'] = dayIds.join(',');
      }
      if (lessonHourIds != null && lessonHourIds.isNotEmpty) {
        params['lesson_hour_ids'] = lessonHourIds.join(',');
      }

      final response = await dioClient.get(
        ApiEndpoints.attendanceSummary,
        queryParameters: params,
      );
      final result = response.data;

      if (result is Map<String, dynamic>) return result;

      return {
        'success': true,
        'data': result is List ? result : [],
        'pagination': {
          'total_items': result is List ? (result).length : 0,
          'total_pages': 1,
          'current_page': 1,
          'per_page': limit,
          'has_next_page': false,
          'has_prev_page': false,
        },
      };
    } catch (e) {
      AppLogger.error('api', 'Error getAbsensiSummaryPaginated: $e');
      rethrow;
    }
  }

  static Future<dynamic> createAttendance(Map<String, dynamic> data) async {
    final response = await dioClient.post(ApiEndpoints.attendance, data: data);
    return response.data;
  }

  /// Bulk create/update attendance for multiple students in a single request.
  static Future<Map<String, dynamic>> createBulkAttendance({
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
    if (result is Map<String, dynamic>) return result;
    return {'success': 0, 'failed': 0, 'errors': []};
  }

  static Future<dynamic> deleteAttendance({
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
      return response.data;
    } catch (e) {
      AppLogger.error('api', 'AttendanceService.deleteAttendance error: $e');
      rethrow;
    }
  }

  static Future<void> markAttendanceRead({required String studentId}) async {
    try {
      await dioClient.post(
        ApiEndpoints.attendanceMarkRead,
        data: {'student_id': studentId},
      );
    } catch (e) {
      AppLogger.error('api', 'Error marking attendance read: $e');
    }
  }

  static Future<Map<String, dynamic>> getAttendanceStats({
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

  static Future<int> getUnreadPresenceCount() async {
    try {
      final response = await dioClient.get(ApiEndpoints.attendanceUnreadCount);
      final result = response.data;
      return int.tryParse(result['count']?.toString() ?? '0') ?? 0;
    } catch (e) {
      AppLogger.error('api', 'Error fetching unread presence count: $e');
      return 0;
    }
  }

  static Future<void> markPresenceAsRead(List<String> attendanceIds) async {
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

  static Future<List<dynamic>> getAttendanceDashboardChart({
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
