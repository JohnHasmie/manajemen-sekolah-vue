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
}
