import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Dedicated service for all Grade (Nilai) API operations.
/// Extracted from the monolithic ApiService to improve modularity.
class GradeService {
  /// Fetches student grades (nilai) with multiple optional filters.
  static Future<List<dynamic>> getGrades({
    String? studentId,
    String? teacherId,
    String? subjectId,
    String? gradeType,
    String? academicYearId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (studentId != null) queryParams['student_id'] = studentId;
    if (teacherId != null) queryParams['teacher_id'] = teacherId;
    if (subjectId != null) queryParams['subject_id'] = subjectId;
    if (gradeType != null) queryParams['grade_type'] = gradeType;
    if (academicYearId != null) {
      queryParams['academic_year_id'] = academicYearId;
    }

    final response = await dioClient.get(
      ApiEndpoints.grades,
      queryParameters: queryParams,
    );

    final result = response.data;
    if (result is List) return result;
    if (result is Map && result.containsKey('data') && result['data'] is List) {
      return result['data'];
    }
    return [];
  }

  /// Fetches classes grouped with subjects for the grade overview.
  /// Single API call replaces the old wizard's N+1 pattern.
  static Future<List<dynamic>> getTeacherGradeSummary({
    required String teacherId,
    String? academicYearId,
    String view = 'mengajar',
    String? classId,
    String? subjectId,
  }) async {
    final queryParams = <String, dynamic>{'teacher_id': teacherId, 'view': view};
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;
    if (classId != null) queryParams['class_id'] = classId;
    if (subjectId != null) queryParams['subject_id'] = subjectId;

    final response = await dioClient.get(
      ApiEndpoints.gradesTeacherSummary,
      queryParameters: queryParams,
    );

    final result = response.data;
    if (result is Map && result['data'] is List) return result['data'];
    if (result is List) return result;
    return [];
  }

  /// Fetches classes grouped with subjects + recap completion stats.
  static Future<List<dynamic>> getTeacherRecapSummary({
    required String teacherId,
    String? academicYearId,
    String view = 'mengajar',
    String? classId,
    String? subjectId,
  }) async {
    final queryParams = <String, dynamic>{'teacher_id': teacherId, 'view': view};
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;
    if (classId != null) queryParams['class_id'] = classId;
    if (subjectId != null) queryParams['subject_id'] = subjectId;

    final response = await dioClient.get(
      ApiEndpoints.gradeRecapsTeacherSummary,
      queryParameters: queryParams,
    );

    final result = response.data;
    if (result is Map && result['data'] is List) return result['data'];
    if (result is List) return result;
    return [];
  }

  /// Fetches grades filtered by subject, with optional academic year and limit.
  static Future<List<dynamic>> getGradesBySubject(
    String subjectId, {
    String? academicYearId,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'subject_id': subjectId,
        'limit': limit.toString(),
      };
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }

      final response = await dioClient.get(
        ApiEndpoints.grades,
        queryParameters: queryParams,
      );
      final result = response.data;

      if (result is Map<String, dynamic> && result.containsKey('data')) {
        return result['data'] as List<dynamic>;
      } else if (result is List) {
        return result;
      }

      return [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching nilai: $e');
      return [];
    }
  }

  /// Creates a new grade entry.
  static Future<dynamic> createGrade(Map<String, dynamic> data) async {
    final response = await dioClient.post(ApiEndpoints.grade, data: data);
    return response.data;
  }

  static Future<int> getUnreadGradeCount() async {
    try {
      final response = await dioClient.get(ApiEndpoints.gradeUnreadCount);
      final result = response.data;
      return int.tryParse(result['count']?.toString() ?? '0') ?? 0;
    } catch (e) {
      AppLogger.error('api', 'Error fetching unread grade count: $e');
      return 0;
    }
  }

  static Future<void> markGradeAsRead(List<String> gradeIds) async {
    if (gradeIds.isEmpty) return;
    try {
      await dioClient.post(
        ApiEndpoints.gradeMarkRead,
        data: {'grade_ids': gradeIds},
      );
    } catch (e) {
      AppLogger.error('api', 'Error marking grades as read: $e');
    }
  }

  /// Fetches a page of student grades with pagination metadata.
  ///
  /// Returns a map matching the pagination contract used by AttendanceService
  /// and LessonPlanService:
  /// ```
  /// {
  ///   'data': List<dynamic>,
  ///   'pagination': {
  ///     'current_page': int,
  ///     'total_pages': int,
  ///     'has_next_page': bool,
  ///     'per_page': int,
  ///     'total_items': int,
  ///   }
  /// }
  /// ```
  static Future<Map<String, dynamic>> getGradesPaginated({
    int page = 1,
    int limit = 20,
    String? studentId,
    String? teacherId,
    String? subjectId,
    String? gradeType,
    String? academicYearId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (studentId != null) queryParams['student_id'] = studentId;
      if (teacherId != null) queryParams['teacher_id'] = teacherId;
      if (subjectId != null) queryParams['subject_id'] = subjectId;
      if (gradeType != null) queryParams['grade_type'] = gradeType;
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }

      final response = await dioClient.get(
        ApiEndpoints.grades,
        queryParameters: queryParams,
      );

      final result = response.data;

      // Server already returns paginated envelope
      if (result is Map<String, dynamic> && result.containsKey('pagination')) {
        return {
          'data': result['data'] ?? [],
          'pagination': result['pagination'],
        };
      }

      // Server returned a flat list — wrap in a synthetic single-page envelope
      final items = result is List ? result : (result is Map && result['data'] is List ? result['data'] as List : []);
      return {
        'data': items,
        'pagination': {
          'current_page': page,
          'total_pages': items.length < limit ? page : page + 1,
          'has_next_page': items.length >= limit,
          'per_page': limit,
          'total_items': items.length,
        },
      };
    } catch (e) {
      AppLogger.error('api', 'Error fetching paginated grades (page $page): $e');
      return {
        'data': [],
        'pagination': {
          'current_page': page,
          'total_pages': 1,
          'has_next_page': false,
          'per_page': limit,
          'total_items': 0,
        },
      };
    }
  }
}
