import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/domain/models/'
    'attendance.dart';

/// Helper service for attendance query and fetch operations.
/// Handles all read-only operations and data retrieval.
class AttendanceQueryHelper {
  static const _kDateRangeStart = 'tanggalStart';
  static const _kDateRangeEnd = 'tanggalEnd';

  /// Fetches attendance records with optional filters.
  ///
  /// The backend `/attendance` endpoint paginates with a default
  /// `per_page=15`. Most callers want the FULL set for a narrow
  /// query (e.g. one class on one date — bounded by class size, ~30),
  /// not page 1. We pass an explicit large [limit] so the detail
  /// screen doesn't silently fall back to 'absent' for any student
  /// whose attendance row lands on page 2.
  Future<List<Attendance>> getAttendance({
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? academicYearId,
    String? lessonHourId,
    int limit = 500,
  }) async {
    final queryParams = _buildFilterParams(
      teacherId: teacherId,
      date: date,
      subjectId: subjectId,
      studentId: studentId,
      classId: classId,
      academicYearId: academicYearId,
      lessonHourId: lessonHourId,
    );
    queryParams['per_page'] = limit.toString();

    AppLogger.debug(
      'api',
      '📍 Calling getAbsensi: ${ApiEndpoints.attendance} '
          'with params: $queryParams',
    );

    final response = await dioClient.get(
      ApiEndpoints.attendance,
      queryParameters: queryParams,
    );

    return _parseAttendanceList(response.data);
  }

  /// Fetches paginated attendance records.
  Future<Map<String, dynamic>> getAttendancePaginated({
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
      _addOptionalParams(params, {
        'teacher_id': teacherId,
        'date': date,
        'subject_id': subjectId,
        'student_id': studentId,
        'class_id': classId,
        _kDateRangeStart: dateStart,
        _kDateRangeEnd: dateEnd,
        'academic_year_id': academicYearId,
      });

      final response = await dioClient.get(
        ApiEndpoints.attendance,
        queryParameters: params,
      );

      return _parseMapOrListResponse(response.data, limit);
    } catch (e) {
      AppLogger.error('api', 'Error getAbsensiPaginated: $e');
      rethrow;
    }
  }

  /// Fetches attendance summary for teacher overview.
  ///
  /// Pass [view] = 'wali_kelas' in homeroom mode so the backend groups by
  /// (class, subject, teacher) and returns teacher_id + teacher_name on
  /// each card. 'mengajar' (or omitted) keeps the legacy shape.
  Future<Map<String, dynamic>> getTeacherAttendanceSummary({
    String? teacherId,
    String? academicYearId,
    String? classId,
    String? subjectId,
    String? search,
    String? dateFilter,
    int page = 1,
    int perPage = 50,
    bool includeClasses = false,
    String? view,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (teacherId != null) params['teacher_id'] = teacherId;
    if (academicYearId != null) {
      params['academic_year_id'] = academicYearId;
    }
    if (classId != null) params['class_id'] = classId;
    if (subjectId != null) params['subject_id'] = subjectId;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (dateFilter != null) params['date_filter'] = dateFilter;
    if (includeClasses) params['include_classes'] = '1';
    if (view != null) params['view'] = view;

    final response = await dioClient.get(
      ApiEndpoints.attendanceTeacherSummary,
      queryParameters: params,
    );

    final result = response.data;
    if (result is Map<String, dynamic>) return result;
    return {'data': result is List ? result : [], 'pagination': {}};
  }

  /// Frame D — calendar feed for the date & slot picker.
  ///
  /// Returns the raw response: `{ dates_with_records: [...],
  /// sessions_today: [...], month, today, success }`. Errors fall back
  /// to an empty payload so the picker can still render an empty
  /// month grid.
  Future<Map<String, dynamic>> getTeacherCalendar({
    String? teacherId,
    String? classId,
    String? academicYearId,
    String? month,
  }) async {
    final params = <String, dynamic>{
      if (teacherId != null && teacherId.isNotEmpty) 'teacher_id': teacherId,
      if (classId != null && classId.isNotEmpty) 'class_id': classId,
      if (academicYearId != null && academicYearId.isNotEmpty)
        'academic_year_id': academicYearId,
      if (month != null && month.isNotEmpty) 'month': month,
    };
    try {
      final response = await dioClient.get(
        ApiEndpoints.attendanceTeacherCalendar,
        queryParameters: params,
      );
      final result = response.data;
      if (result is Map<String, dynamic>) return result;
    } catch (e) {
      AppLogger.error('attendance', 'getTeacherCalendar failed: $e');
    }
    return {
      'dates_with_records': const [],
      'sessions_today': const [],
      'month': month ?? '',
      'today': '',
    };
  }

  /// Frame C · "Salin dari sesi terakhir" feed. Returns the most
  /// recent session's per-student status mix so the take-attendance
  /// form can copy it.
  Future<Map<String, dynamic>> getLastTeacherSession({
    required String teacherId,
  }) async {
    try {
      final response = await dioClient.get(
        ApiEndpoints.attendanceLastSession,
        queryParameters: {'teacher_id': teacherId},
      );
      final r = response.data;
      if (r is Map<String, dynamic>) return r;
    } catch (e) {
      AppLogger.error('attendance', 'getLastTeacherSession failed: $e');
    }
    return {'students': const [], 'label': null};
  }

  /// Fetches basic attendance summary.
  Future<List<dynamic>> getAttendanceSummary({
    String? teacherId,
    String? date,
    String? subjectId,
    String? classId,
    String? academicYearId,
  }) async {
    final queryParams = _buildFilterParams(
      teacherId: teacherId,
      date: date,
      subjectId: subjectId,
      classId: classId,
      academicYearId: academicYearId,
    );

    final response = await dioClient.get(
      ApiEndpoints.attendanceSummary,
      queryParameters: queryParams,
    );

    final result = response.data;
    if (result is Map && result['data'] is List) {
      return result['data'] as List<dynamic>;
    }
    return result is List ? result : [];
  }

  /// Fetches paginated attendance summary.
  Future<Map<String, dynamic>> getAttendanceSummaryPaginated({
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
      final params = _buildSummaryParams(
        page: page,
        limit: limit,
        teacherId: teacherId,
        subjectId: subjectId,
        classId: classId,
        date: date,
        dateStart: dateStart,
        dateEnd: dateEnd,
        academicYearId: academicYearId,
        dayIds: dayIds,
        lessonHourIds: lessonHourIds,
      );

      final response = await dioClient.get(
        ApiEndpoints.attendanceSummary,
        queryParameters: params,
      );

      return _parseMapOrListResponse(response.data, limit);
    } catch (e) {
      AppLogger.error('api', 'Error getAbsensiSummaryPaginated: $e');
      rethrow;
    }
  }

  /// Builds summary parameters with pagination and filters.
  Map<String, String> _buildSummaryParams({
    required int page,
    required int limit,
    String? teacherId,
    String? subjectId,
    String? classId,
    String? date,
    String? dateStart,
    String? dateEnd,
    String? academicYearId,
    List<String>? dayIds,
    List<String>? lessonHourIds,
  }) {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    _addOptionalParams(params, {
      'academic_year_id': academicYearId,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'class_id': classId,
      'date': date,
      _kDateRangeStart: dateStart,
      _kDateRangeEnd: dateEnd,
    });
    if (dayIds != null && dayIds.isNotEmpty) {
      params['day_ids'] = dayIds.join(',');
    }
    if (lessonHourIds != null && lessonHourIds.isNotEmpty) {
      params['lesson_hour_ids'] = lessonHourIds.join(',');
    }
    return params;
  }

  /// Builds filter parameters for basic queries.
  Map<String, dynamic> _buildFilterParams({
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? academicYearId,
    String? lessonHourId,
  }) {
    final params = <String, dynamic>{};
    if (teacherId != null) params['teacher_id'] = teacherId;
    if (date != null) params['date'] = date;
    if (subjectId != null) params['subject_id'] = subjectId;
    if (studentId != null) params['student_id'] = studentId;
    if (classId != null) params['class_id'] = classId;
    if (academicYearId != null) params['academic_year_id'] = academicYearId;
    if (lessonHourId != null) params['lesson_hour_id'] = lessonHourId;
    return params;
  }

  /// Adds non-empty optional parameters to a map.
  void _addOptionalParams(
    Map<String, String> params,
    Map<String, String?> optionals,
  ) {
    optionals.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        params[key] = value;
      }
    });
  }

  /// Parses API response into Attendance list.
  List<Attendance> _parseAttendanceList(dynamic result) {
    if (kDebugMode) {
      AppLogger.debug('api', 'Absensi response type: ${result.runtimeType}');
    }

    if (result is Map && result['data'] is List) {
      return (result['data'] as List)
          .map((json) => Attendance.fromJson(json))
          .toList();
    } else if (result is List) {
      return result.map((json) => Attendance.fromJson(json)).toList();
    } else {
      AppLogger.warning('api', 'Unexpected response format for absensi');
      return [];
    }
  }

  /// Parses paginated response (Map or List).
  Map<String, dynamic> _parseMapOrListResponse(
    dynamic result,
    int itemsPerPage,
  ) {
    if (result is Map<String, dynamic>) return result;

    if (result is List) {
      return {
        'success': true,
        'data': result,
        'pagination': {
          'total_items': result.length,
          'total_pages': 1,
          'current_page': 1,
          'per_page': itemsPerPage,
          'has_next_page': false,
          'has_prev_page': false,
        },
      };
    }

    return {'success': false};
  }
}
