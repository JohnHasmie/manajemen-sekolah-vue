/// api_services.dart - Core HTTP client and central API gateway for the entire app.
/// Like Laravel's Http facade + AuthController / Vue's root Axios instance + auth store.
///
/// This is the foundational service that ALL other API services depend on.
/// It provides:
/// - Base URL configuration (from .env, like Laravel's `config('app.url')`)
/// - Authenticated HTTP methods (GET, POST, PUT, DELETE) with Firebase performance tracing
/// - Shared auth headers (Bearer token + X-School-ID, like Laravel Sanctum middleware)
/// - Central response handling (JSON parsing, 401/403 auto-logout, 422 validation errors)
/// - Authentication flows: login, OTP verification, Google OAuth, school/role switching
/// - Domain-specific endpoints: grades (nilai), attendance (absensi), RPP, billing, FCM
///
/// In Vue terms, this is like combining your root Axios instance configuration,
/// auth store, and several Vuex modules into one central service.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// The central API service class -- the backbone of all HTTP communication.
/// Like Laravel's `Http` facade combined with auth middleware and a service container.
///
/// Provides both static methods (for auth flows, one-off calls) and instance methods
/// (for general CRUD via get/post/put/delete). Other service classes (ApiStudentService,
/// ApiTeacherService, etc.) either extend this pattern or use `ApiService()` instances.
///
/// Key responsibilities:
/// - [init] loads the base URL from `.env` (like Laravel's `.env` config loading)
/// - [_getHeaders] injects Bearer token + X-School-ID (like Laravel Sanctum + tenant middleware)
/// - [_handleResponse] centralizes error handling (like a global exception handler)
/// - [login], [verifyOtp], [googleLogin] handle all auth flows
/// - Grade, attendance, RPP, billing endpoints are grouped here for historical reasons
class ApiService {
  // static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:3001/api'; // iOS simulator or web

  // static const String baseUrl = 'https://backendmanajemensekolah2.vercel.app/api';
  // static const String baseUrl = 'https://libra.web.id/apimanajemen';

  // static const String baseUrl = 'http://aieasytech.id/api';
  // static const String baseUrl = 'http://192.168.1.100:3000/api';

  /// The base URL for all API calls. Loaded once from `.env` at app startup.
  /// Like `config('app.url')` in Laravel or `VUE_APP_API_URL` in Vue.
  static late final String baseUrl;

  /// Initializes the base URL from the `.env` file. Must be called before any API usage.
  /// Like Laravel's bootstrap phase that loads `.env` via Dotenv.
  /// Called from `main()` during app startup.
  static Future<void> init() async {
    final envBaseUrl = dotenv.env['API_BASE_URL'];

    if (envBaseUrl != null && envBaseUrl.isNotEmpty) {
      baseUrl = envBaseUrl;
      AppLogger.debug('api', 'API Base URL from .env: $baseUrl');
      return;
    }
  }

  /// Performs an authenticated GET request with Firebase performance tracing.
  /// Like `Http::get($url)` in Laravel or `axios.get()` in Vue.
  /// [endpoint] - Relative path (e.g., '/student'). Appended to [baseUrl].
  /// [params] - Optional query parameters (like `$request->query()` in Laravel).
  /// Returns the parsed JSON response body.
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? params}) async {
    try {
      final response = await dioClient.get(
        endpoint,
        queryParameters: params,
      );
      return response.data;
    } on DioException catch (e) {
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Performs an authenticated POST request with Firebase performance tracing.
  /// Like `Http::post($url, $data)` in Laravel or `axios.post()` in Vue.
  /// [data] - Request body as a Map, JSON-encoded automatically.
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await dioClient.post(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Performs an authenticated PUT request with Firebase performance tracing.
  /// Like `Http::put($url, $data)` in Laravel or `axios.put()` in Vue.
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await dioClient.put(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Fetches grades filtered by subject, with optional academic year and limit.
  /// Like `Grade::where('subject_id', $id)->limit($limit)->get()` in Laravel.
  Future<List<dynamic>> getGradesBySubject(
    String subjectId, {
    String? academicYearId,
    int limit = 100, // Added limit
  }) async {
    try {
      // Use backend filtering
      String url = '${ApiEndpoints.grades}?subject_id=$subjectId&limit=$limit';
      if (academicYearId != null) {
        url += '&academic_year_id=$academicYearId';
      }

      final response = await get(url);

      // Handle paginated response (Map with 'data' key) or direct List
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        return response['data'] as List<dynamic>;
      } else if (response is List) {
        return response;
      }

      return [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching nilai: $e');
      return [];
    }
  }

  /// Performs an authenticated DELETE request with Firebase performance tracing.
  /// Like `Http::delete($url)` in Laravel or `axios.delete()` in Vue.
  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await dioClient.delete(endpoint);
      return response.data;
    } on DioException catch (e) {
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Downloads a file as raw bytes. Like `Storage::download()` in Laravel.
  /// Returns the file content as [Uint8List] for saving to disk.
  static Future<Uint8List> downloadFile(String endpoint) async {
    try {
      final response = await dioClient.get<List<int>>(
        endpoint,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? []);
    } on DioException catch (e) {
      AppLogger.error('api', 'Download Error on $endpoint: $e');
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Retrieves the stored auth token from SharedPreferences.
  /// Like `auth()->token()` in Laravel Sanctum.
  static Future<String?> getToken() async {
    final prefs = PreferencesService();
    return prefs.getString('token');
  }

  /// Public accessor for auth headers. Used by all other service classes.
  /// Like a shared middleware that injects auth context into every request.
  static Future<Map<String, String>> getHeaders() => _getHeaders();

  /// Builds request headers with Bearer token and X-School-ID.
  /// Like combining Laravel Sanctum auth middleware + tenant identification middleware.
  /// - Bearer token: from SharedPreferences (like session-based auth)
  /// - X-School-ID: multi-tenant school identifier (like Laravel tenant middleware)
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = PreferencesService();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // Add school_id header if available
    if (userJson != null) {
      try {
        AppLogger.debug('api', 'Checking headers - UserJson length: ${userJson.length}');
        AppLogger.debug('api', 'UserJson snippet: ${userJson.substring(0, userJson.length > 100 ? 100 : userJson.length)}',);

        final user = json.decode(userJson);

        if (user['school_id'] != null) {
          headers['X-School-ID'] = user['school_id'].toString();
          AppLogger.info('api', 'Injected X-School-ID: ${headers['X-School-ID']}');
        } else {
          AppLogger.warning('api', 'school_id missing in user object');
        }
      } catch (e) {
        // Ignore JSON parse errors
        AppLogger.error('api', 'Failed to parse user JSON for school_id: $e');
      }
    } else {
      AppLogger.warning('api', 'User JSON is null in SharedPreferences');
    }

    return headers;
  }

  // NOTE: _handleResponse(http.Response) has been removed.
  // All response handling (401 auto-logout, 403, 422 validation, etc.)
  // is now done by Dio's ErrorInterceptor in dio_client.dart.

  /// Handles authentication failures by clearing stored data and redirecting to login.
  /// Like Laravel's `auth()->logout()` + redirect, or Vue Router's navigation guard.
  /// Clears SharedPreferences (token, user data) and uses the global navigator key
  /// to push the LoginScreen with an error message.
  static Future<void> _handleAuthenticationErrorWithMessage(
    String errorMessage,
  ) async {
    try {
      AppLogger.error('api', 'Handling authentication error: $errorMessage');

      // Clear all stored data
      final prefs = PreferencesService();
      await prefs.clear();

      await Future.delayed(const Duration(milliseconds: 300));

      // Use go_router to navigate to login
      appRouter.go('/login');
    } catch (e) {
      AppLogger.error('api', 'Error during authentication cleanup: $e');
    }
  }

  /// Public method for other services to trigger logout with a custom message.
  /// Like calling `Auth::logout()` from anywhere in a Laravel app.
  static Future<void> logoutWithMessage(String message) async {
    await _handleAuthenticationErrorWithMessage(message);
  }

  Future<List<dynamic>> getData(String endpoint) async {
    try {
      final response = await dioClient.get('/$endpoint');
      final result = response.data;
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('api', 'getData Error on $endpoint: $e');
      return [];
    }
  }


  /// Fetches dashboard statistics (student count, teacher count, etc.) by role.
  /// Like a Laravel dashboard controller that aggregates stats per user role.
  static Future<Map<String, dynamic>> getDashboardStats({
    required String role,
    String? academicYearId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'role': role};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }

      final response = await dioClient.get(
        ApiEndpoints.dashboardStats,
        queryParameters: queryParams,
      );

      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        return Map<String, dynamic>.from(result['data'] ?? {});
      }
      return {};
    } catch (e) {
      AppLogger.error('api', 'Error fetching dashboard stats: $e');
      return {};
    }
  }

  /// Gets the count of unread announcements for badge display.
  /// Like a notification count endpoint. Returns 0 on error.
  static Future<int> getUnreadAnnouncementCount() async {
    try {
      final response = await dioClient.get(ApiEndpoints.announcementUnreadCount);
      final data = response.data;
      return data['count'] ?? 0;
    } catch (e) {
      AppLogger.error('api', 'Error fetching unread count: $e');
      return 0;
    }
  }

  static Future<bool> markAnnouncementRead(List<String> ids) async {
    try {
      await dioClient.post(ApiEndpoints.announcementMarkRead, data: {'ids': ids});
      return true;
    } catch (e) {
      AppLogger.error('api', 'Error marking announcement read: $e');
      return false;
    }
  }



  /// Fetches student grades (nilai) with multiple optional filters.
  /// Like `Grade::filter($request)->get()` in Laravel.
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
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;

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

  /// Creates a new grade entry. Like `Grade::create($data)` in Laravel.
  static Future<dynamic> createGrade(Map<String, dynamic> data) async {
    final response = await dioClient.post(ApiEndpoints.grade, data: data);
    return response.data;
  }

  /// Fetches RPP (lesson plans) with optional filters.
  /// Like `Rpp::filter($request)->get()` in Laravel.
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
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;

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
  ///
  /// This is useful to retrieve the full RPP record (including AI-generated fields)
  /// when the list endpoint only returns a summary.
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
    String? filterSubjectId, // Added based on queryParams
    String? date, // Added based on queryParams
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (teacherId != null && teacherId.isNotEmpty) {
      queryParams['teacher_id'] = teacherId;
    }
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (subjectId != null && subjectId.isNotEmpty) {
      queryParams['subject_id'] = subjectId;
    }
    if (filterSubjectId != null && filterSubjectId.isNotEmpty) {
      queryParams['mataPelajaranId'] = filterSubjectId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['classId'] = classId;
    }
    if (date != null && date.isNotEmpty) {
      queryParams['tanggal'] = date;
    }
    if (dateStart != null && dateStart.isNotEmpty) {
      queryParams['tanggalStart'] = dateStart;
    }
    if (dateEnd != null && dateEnd.isNotEmpty) {
      queryParams['tanggalEnd'] = dateEnd;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (semester != null && semester.isNotEmpty) {
      queryParams['semester'] = semester;
    }
    if (academicYear != null && academicYear.isNotEmpty) {
      queryParams['tahun_ajaran'] = academicYear;
    }

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

  // Get Tagihan with pagination & filters
  static Future<Map<String, dynamic>> getBillsPaginated({
    int page = 1,
    int limit = 10,
    String? status,
    String? studentId,
    String? paymentTypeId,
    String? classId,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (studentId != null && studentId.isNotEmpty) {
      queryParams['student_id'] = studentId;
    }
    if (paymentTypeId != null && paymentTypeId.isNotEmpty) {
      queryParams['payment_type_id'] = paymentTypeId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }

    final response = await dioClient.get(
      ApiEndpoints.bills,
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

  // Fix uploadLessonPlanFile function
  static Future<dynamic> uploadLessonPlanFile(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post(ApiEndpoints.uploadLessonPlan, data: formData);

      AppLogger.debug('api', 'Upload Response Status: ${response.statusCode}');
      AppLogger.debug('api', 'Upload Response Data: ${response.data}');

      return response.data;
    } catch (e) {
      AppLogger.error('api', 'Upload error details: $e');
      throw Exception('Upload error: $e');
    }
  }

  /// Fetches attendance (absensi) records with multiple optional filters.
  /// Like `Attendance::filter($request)->get()` in Laravel.
  /// Handles both formats: direct array or `{success, data, pagination}`.
  static Future<List<dynamic>> getAttendance({
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
    if (date != null) queryParams['tanggal'] = date;
    if (subjectId != null) queryParams['mataPelajaranId'] = subjectId;
    if (studentId != null) queryParams['student_id'] = studentId;
    if (classId != null) queryParams['classId'] = classId;
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;
    if (lessonHourId != null) queryParams['lesson_hour_id'] = lessonHourId;

    AppLogger.debug('api', '📍 Calling getAbsensi: ${ApiEndpoints.attendance} with params: $queryParams');

    final response = await dioClient.get(
      ApiEndpoints.attendance,
      queryParameters: queryParams,
    );

    final result = response.data;

    if (kDebugMode) {
      AppLogger.debug('api', 'Absensi response type: ${result.runtimeType}');
      if (result is Map) {
        AppLogger.debug('api', 'Response has data field: ${result.containsKey('data')}');
        if (result.containsKey('data')) {
          AppLogger.debug('api', 'Data is List: ${result['data'] is List}');
          AppLogger.debug('api', 'Data length: ${(result['data'] as List?)?.length ?? 0}');
        }
      } else if (result is List) {
        AppLogger.debug('api', 'Direct array, length: ${result.length}');
      }
    }

    // Handle both formats: direct array or {success, data, pagination}
    if (result is Map && result['data'] is List) {
      return result['data'];
    } else if (result is List) {
      return result;
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

    final apiService = ApiService();
    return await apiService.delete(query);
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
        params['tanggalStart'] = dateStart;
      }
      if (dateEnd != null && dateEnd.isNotEmpty) {
        params['tanggalEnd'] = dateEnd;
      }
      if (academicYearId != null && academicYearId.isNotEmpty) {
        params['academic_year_id'] = academicYearId;
      }

      final response = await dioClient.get(
        ApiEndpoints.attendance,
        queryParameters: params,
      );
      final result = response.data;

      if (result is Map<String, dynamic>) return result;

      // Fallback: wrap list in pagination-like object
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
    if (subjectId != null) queryParams['subjectId'] = subjectId;
    if (classId != null) queryParams['classId'] = classId;
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;

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

  // New method for paginated summary
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

      if (teacherId != null && teacherId.isNotEmpty) params['teacher_id'] = teacherId;
      if (subjectId != null && subjectId.isNotEmpty) {
        params['mataPelajaranId'] = subjectId;
      }
      if (classId != null && classId.isNotEmpty) params['classId'] = classId;
      if (date != null && date.isNotEmpty) params['tanggal'] = date;
      if (dateStart != null && dateStart.isNotEmpty) {
        params['tanggalStart'] = dateStart;
      }
      if (dateEnd != null && dateEnd.isNotEmpty) {
        params['tanggalEnd'] = dateEnd;
      }
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

      // Fallback if server returns list (should not happen with new endpoint)
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

  /// Creates a new attendance record. Like `Attendance::create($data)` in Laravel.
  static Future<dynamic> createAttendance(Map<String, dynamic> data) async {
    final response = await dioClient.post(ApiEndpoints.attendance, data: data);
    return response.data;
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
      AppLogger.error('api', 'ApiService.deleteAttendance error: $e');
      rethrow;
    }
  }

  /// Fetches the school's available grade levels (e.g., 1-6 for SD, 7-9 for SMP).
  /// Like `SchoolConfig::getGradeLevels()` in Laravel. Falls back to 1-12.
  Future<List<int>> getGradeLevels() async {
    try {
      final response = await dioClient.get(ApiEndpoints.schoolConfigGradeLevels);
      final result = response.data;
      return result is List
          ? result.cast<int>()
          : [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    } catch (e) {
      AppLogger.error('api', 'Error getting grade levels: $e');
      return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]; // fallback
    }
  }

  // Get kelas by mata pelajaran
  Future<List<dynamic>> getClassBySubjectId(String subjectId) async {
    try {
      final result = await get(
        '${ApiEndpoints.classBySubject}?subject_id=$subjectId',
      );

      // Handle Map format (pagination or error response)
      if (result is Map<String, dynamic>) {
        // Check if it's paginated response
        if (result.containsKey('data')) {
          return result['data'] ?? [];
        }
        // If Map but no 'data' key, return empty (error case)
        return [];
      }

      // Handle List format (direct response)
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('api', 'Error getting kelas by mata pelajaran: $e');
      return [];
    }
  }

  // Get mata pelajaran with kelas data
  Future<List<dynamic>> getSubjectsWithClasses() async {
    try {
      final result = await get(ApiEndpoints.subjectWithClass);
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('api', 'Error getting mata pelajaran with kelas: $e');
      return [];
    }
  }

  /// Uploads a file with optional form data via multipart request.
  /// Like Laravel's `$request->file()` handling. Auto-detects MIME type.
  /// [fileField] - The form field name (defaults to 'bukti_bayar' for payment receipts).
  Future<dynamic> uploadFile(
    String endpoint,
    File file, {
    Map<String, dynamic>? data,
    String fileField = 'bukti_bayar',
  }) async {
    try {
      // Detect the correct MIME type
      String mimeType;
      final extension = file.path.toLowerCase().split('.').last;

      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        default:
          mimeType = 'image/jpeg'; // fallback
      }

      AppLogger.debug('api', 'Uploading file: ${file.path}');
      AppLogger.debug('api', 'File extension: $extension');
      AppLogger.debug('api', 'MIME type: $mimeType');

      final formMap = <String, dynamic>{
        fileField: await MultipartFile.fromFile(
          file.path,
          contentType: DioMediaType.parse(mimeType),
        ),
      };

      // Add other data
      if (data != null) {
        data.forEach((key, value) {
          formMap[key] = value.toString();
        });
      }

      final formData = FormData.fromMap(formMap);

      AppLogger.debug('api', 'Request fields: ${formData.fields}');
      AppLogger.debug('api', 'Request files: ${formData.files.length}');

      final response = await dioClient.post(endpoint, data: formData);

      AppLogger.debug('api', 'Upload Response Status: ${response.statusCode}');
      AppLogger.debug('api', 'Upload Response Data: ${response.data}');

      return response.data;
    } catch (error) {
      AppLogger.error('api', 'Upload error: $error');
      throw Exception('Upload error: $error');
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

  static Future<void> markBillRead({
    String? studentId,
    List<String>? billIds,
  }) async {
    try {
      await dioClient.post(ApiEndpoints.billMarkRead, data: {
        if (studentId != null) 'student_id': studentId,
        if (billIds != null) 'bill_ids': billIds,
      });
    } catch (e) {
      AppLogger.error('api', 'Error marking bills read: $e');
    }
  }

  static Future<void> markSingleBillRead({required String billId}) async {
    try {
      await dioClient.post(
        ApiEndpoints.billMarkSingleRead,
        data: {'bill_id': billId},
      );
    } catch (e) {
      AppLogger.error('api', 'Error marking bill read: $e');
    }
  }

  static Future<int> getUnreadBillingCount() async {
    try {
      final response = await dioClient.get(ApiEndpoints.billUnreadCount);
      final result = response.data;
      return int.tryParse(result['count']?.toString() ?? '0') ?? 0;
    } catch (e) {
      AppLogger.error('api', 'Error getting unread billing count: $e');
      return 0;
    }
  }

  /// Checks server health. Intentionally does NOT use [_handleResponse]
  /// to avoid triggering auto-logout redirects that cause login screen loops.
  /// Like a simple ping endpoint. Used before login to verify server availability.
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await dioClient.get(
        ApiEndpoints.health,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'status': 'ok'};
    } on DioException catch (e) {
      throw Exception(
        'Server returned status ${e.response?.statusCode ?? 'unknown'}',
      );
    }
  }

  // Manual payment entry by admin (for offline/cash payments)
  Future<dynamic> inputManualPayment(Map<String, dynamic> data) async {
    try {
      return await post(ApiEndpoints.paymentManual, data);
    } catch (e) {
      AppLogger.error('api', 'Error input pembayaran manual: $e');
      rethrow;
    }
  }

  // Generate Bills for a specific Payment Type
  static Future<dynamic> generateBills({
    String? paymentTypeId,
    required String month,
    required String academicYearId,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'month': month,
        'academic_year_id': academicYearId,
      };
      if (paymentTypeId != null) {
        body['payment_type_id'] = paymentTypeId;
      }
      final apiService = ApiService();
      return await apiService.post(ApiEndpoints.generateBill, body);
    } catch (e) {
      AppLogger.error('api', 'Error generating bills: $e');
      rethrow;
    }
  }

  // Get Finance Dashboard Stats
  static Future<Map<String, dynamic>> getFinanceDashboardStats() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get(ApiEndpoints.financeDashboard);
      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } catch (e) {
      AppLogger.error('api', 'Error getting finance stats: $e');
      return {};
    }
  }

  // Get Generated Months
  static Future<List<String>> getGeneratedMonths({
    required String paymentTypeId,
    required String academicYearId,
  }) async {
    try {
      final apiService = ApiService();
      final response = await apiService.get(
        '${ApiEndpoints.financeGeneratedMonths}?payment_type_id=$paymentTypeId&academic_year_id=$academicYearId',
      );
      if (response is List) {
        return List<String>.from(response);
      }
      return [];
    } catch (e) {
      AppLogger.error('api', 'Error getting generated months: $e');
      return [];
    }
  }

  // Delete Bills for a specific Payment Type
  static Future<dynamic> deleteBillsByType(
    String paymentTypeId, {
    String? month,
  }) async {
    try {
      final apiService = ApiService();
      String url = '/bills/type/$paymentTypeId';
      if (month != null) {
        url += '?month=$month';
      }
      return await apiService.delete(url);
    } catch (e) {
      AppLogger.error('api', 'Error deleting bills by type: $e');
      rethrow;
    }
  }

  /// Registers the device's FCM token with the backend for push notifications.
  /// Like Laravel's notification channel registration. Called after Firebase init.
  static Future<Map<String, dynamic>> sendFCMToken(
    String token,
    String deviceType,
  ) async {
    try {
      final prefs = PreferencesService();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      AppLogger.debug('api', 'Sending to: /fcm/token');
      AppLogger.debug('api', 'Device type: $deviceType');
      AppLogger.debug('api', 'FCM Token length: ${token.length}');

      final response = await dioClient.post(
        ApiEndpoints.fcmTokenEndpoint,
        data: {'token': token, 'device_type': deviceType},
      );

      AppLogger.debug('api', '📥 FCM Response Status: ${response.statusCode}');
      AppLogger.debug('api', '📥 FCM Response Data: ${response.data}');

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      AppLogger.error('api', 'Error sending FCM token: $e');
      rethrow;
    }
  }

  /// Removes the device's FCM token from the backend (on logout).
  /// Like unregistering from a Laravel notification channel.
  static Future<Map<String, dynamic>> deleteFCMToken(String token) async {
    try {
      final prefs = PreferencesService();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      final response = await dioClient.delete(
        ApiEndpoints.fcmTokenEndpoint,
        data: {'token': token},
      );

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      AppLogger.error('api', 'Error deleting FCM token: $e');
      rethrow;
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
    if (date != null && date.isNotEmpty) queryParams['tanggal'] = date;
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

  static Future<Map<String, dynamic>> getFinanceBillStats({
    String? academicYearId,
    String? paymentTypeId,
    String? month,
    String? classId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (paymentTypeId != null && paymentTypeId.isNotEmpty) {
      queryParams['payment_type_id'] = paymentTypeId;
    }
    if (month != null && month.isNotEmpty) queryParams['month'] = month;
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }

    try {
      final response = await dioClient.get(
        ApiEndpoints.financeBillStats,
        queryParameters: queryParams,
      );

      final result = response.data;
      return result['data'] ?? {};
    } catch (e) {
      AppLogger.error('api', 'Error fetching finance bill stats: $e');
      return {};
    }
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
      await dioClient.post(ApiEndpoints.gradeMarkRead, data: {'grade_ids': gradeIds});
    } catch (e) {
      AppLogger.error('api', 'Error marking grades as read: $e');
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

  static Future<List<dynamic>> getFinanceDashboardChart({
    String? academicYearId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (academicYearId != null) params['academic_year_id'] = academicYearId;

      final response = await dioClient.get(
        ApiEndpoints.financeDashboardChart,
        queryParameters: params,
      );
      final result = response.data;

      if (result is List) return result;
      return [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching finance dashboard chart: $e');
      return [];
    }
  }
}
