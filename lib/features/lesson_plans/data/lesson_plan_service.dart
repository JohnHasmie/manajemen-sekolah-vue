import 'dart:io';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

class LessonPlanService {
  /// Fetches RPP (lesson plans) with optional filters.
  static Future<List<dynamic>> getLessonPlans({
    String? teacherId,
    String? status,
    String? search,
    String? academicYearId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (teacherId != null) queryParams['teacher_id'] = teacherId;
    if (status != null) queryParams['status'] = status;
    if (search != null) queryParams['search'] = search;
    if (academicYearId != null)
      queryParams['academic_year_id'] = academicYearId;

    final response = await dioClient.get(
      ApiEndpoints.lessonPlans,
      queryParameters: queryParams,
    );

    final result = response.data;

    if (result is Map && result.containsKey('data')) {
      return result['data'] is List ? result['data'] : [];
    }

    return result is List ? result : [];
  }

  /// Get a single RPP by its ID.
  static Future<Map<String, dynamic>> getLessonPlanById(String id) async {
    final response = await dioClient.get('/rpp/$id');
    final result = response.data;
    return result is Map<String, dynamic> ? result : {};
  }

  // Get RPP with pagination & filters (recommended)
  static Future<Map<String, dynamic>> getLessonPlansPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? status,
    String? search,
    String? subjectId,
    String? classId,
    String? semester,
    String? academicYear,
    String? dateStart,
    String? dateEnd,
    String? academicYearId,
    String? filterSubjectId,
    String? date,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (teacherId != null && teacherId.isNotEmpty)
      queryParams['teacher_id'] = teacherId;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (subjectId != null && subjectId.isNotEmpty)
      queryParams['subject_id'] = subjectId;
    if (filterSubjectId != null && filterSubjectId.isNotEmpty)
      queryParams['mataPelajaranId'] = filterSubjectId;
    if (classId != null && classId.isNotEmpty) queryParams['classId'] = classId;
    if (date != null && date.isNotEmpty) queryParams['tanggal'] = date;
    if (dateStart != null && dateStart.isNotEmpty)
      queryParams['tanggalStart'] = dateStart;
    if (dateEnd != null && dateEnd.isNotEmpty)
      queryParams['tanggalEnd'] = dateEnd;
    if (academicYearId != null && academicYearId.isNotEmpty)
      queryParams['academic_year_id'] = academicYearId;
    if (semester != null && semester.isNotEmpty)
      queryParams['semester'] = semester;
    if (academicYear != null && academicYear.isNotEmpty)
      queryParams['tahun_ajaran'] = academicYear;

    final response = await dioClient.get(
      ApiEndpoints.lessonPlans,
      queryParameters: queryParams,
    );

    final result = response.data;

    if (result is Map<String, dynamic>) return result;

    // fallback
    return {
      'success': true,
      'data': result is List ? result : [],
      'pagination': {
        'total_items': result is List ? result.length : 0,
        'total_pages': 1,
        'current_page': page,
        'per_page': limit,
        'has_next_page': false,
        'has_prev_page': false,
      },
    };
  }

  static Future<dynamic> createLessonPlan(Map<String, dynamic> data) async {
    final response = await dioClient.post(ApiEndpoints.lessonPlans, data: data);
    return response.data;
  }

  static Future<dynamic> updateLessonPlan(
    String lessonPlanId,
    Map<String, dynamic> data,
  ) async {
    final response = await dioClient.put('/rpp/$lessonPlanId', data: data);
    return response.data;
  }

  static Future<dynamic> updateLessonPlanStatus(
    String lessonPlanId,
    String status, {
    String? catatan,
  }) async {
    final response = await dioClient.put(
      '/rpp/$lessonPlanId/status',
      data: {'status': status, 'catatan': catatan},
    );
    return response.data;
  }

  static Future<dynamic> deleteLessonPlan(String lessonPlanId) async {
    final response = await dioClient.delete('/rpp/$lessonPlanId');
    return response.data;
  }

  static Future<dynamic> uploadLessonPlanFile(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post(
        ApiEndpoints.uploadLessonPlan,
        data: formData,
      );

      AppLogger.debug('api', 'Upload Response Status: ${response.statusCode}');
      AppLogger.debug('api', 'Upload Response Data: ${response.data}');

      return response.data;
    } catch (e) {
      AppLogger.error('api', 'Upload error details: $e');
      throw Exception('Upload error: $e');
    }
  }
}
