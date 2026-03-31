/// api_service.dart - Core HTTP infrastructure for the app.
///
/// This is the foundational service that ALL other API services depend on.
/// It provides:
/// - Base URL configuration (from .env)
/// - Authenticated HTTP methods (GET, POST, PUT, DELETE)
/// - Shared auth headers (Bearer token + X-School-ID)
/// - File upload/download utilities
/// - Health check endpoint
/// - Logout handling
///
/// Domain-specific logic has been extracted into dedicated services:
/// - AuthService (login, OTP, OAuth, roles, schools)
/// - LessonPlanService (RPP CRUD)
/// - AttendanceService (attendance CRUD, stats)
/// - FinanceService (bills, payments, charts)
/// - GradeService (grades CRUD, read tracking)
/// - DashboardService (dashboard statistics)
/// - AnnouncementService (announcement read tracking)
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Core HTTP infrastructure class — the backbone of all API communication.
///
/// Provides generic HTTP primitives (get/post/put/delete), auth header
/// management, file transfer utilities, health check, and logout handling.
/// Domain-specific services use these primitives via [dioClient].
class ApiService {
  /// The base URL for all API calls. Loaded once from `.env` at app startup.
  static late final String baseUrl;

  /// Initializes the base URL. Resolution order:
  /// 1. `--dart-define=API_BASE_URL=...` (compile-time, preferred for CI/CD)
  /// 2. `.env` file via flutter_dotenv (development convenience)
  ///
  /// Must be called before any API usage. Called from `main()` during startup.
  static Future<void> init() async {
    // 1. Compile-time define (flutter run --dart-define=API_BASE_URL=https://...)
    const defineUrl = String.fromEnvironment('API_BASE_URL');
    if (defineUrl.isNotEmpty) {
      baseUrl = defineUrl;
      AppLogger.debug('api', 'API Base URL from --dart-define: $baseUrl');
      return;
    }

    // 2. .env file fallback (development)
    final envBaseUrl = dotenv.env['API_BASE_URL'];
    if (envBaseUrl != null && envBaseUrl.isNotEmpty) {
      baseUrl = envBaseUrl;
      AppLogger.debug('api', 'API Base URL from .env: $baseUrl');
      return;
    }
  }

  /// Performs an authenticated GET request.
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? params}) async {
    try {
      final response = await dioClient.get(endpoint, queryParameters: params);
      return response.data;
    } on DioException catch (e) {
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Performs an authenticated POST request.
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await dioClient.post(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Performs an authenticated PUT request.
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await dioClient.put(endpoint, data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Performs an authenticated DELETE request.
  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await dioClient.delete(endpoint);
      return response.data;
    } on DioException catch (e) {
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Downloads a file as raw bytes.
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
  static Future<String?> getToken() async {
    final prefs = PreferencesService();
    return prefs.getString('token');
  }

  /// Public accessor for auth headers.
  static Future<Map<String, String>> getHeaders() => _getHeaders();

  /// Builds request headers with Bearer token and X-School-ID.
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = PreferencesService();
    final token = prefs.getString('token');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Handles authentication failures by clearing stored data and redirecting to login.
  static Future<void> _handleAuthenticationErrorWithMessage(
    String errorMessage,
  ) async {
    try {
      AppLogger.error('api', 'Handling authentication error: $errorMessage');

      final prefs = PreferencesService();
      await prefs.clear();

      await Future.delayed(const Duration(milliseconds: 300));

      appRouter.go('/login');
    } catch (e) {
      AppLogger.error('api', 'Error during authentication cleanup: $e');
    }
  }

  /// Public method for other services to trigger logout with a custom message.
  static Future<void> logoutWithMessage(String message) async {
    await _handleAuthenticationErrorWithMessage(message);
  }

  /// Uploads a file with optional form data via multipart request.
  /// Auto-detects MIME type from file extension.
  Future<dynamic> uploadFile(
    String endpoint,
    File file, {
    Map<String, dynamic>? data,
    String fileField = 'bukti_bayar',
  }) async {
    try {
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
          mimeType = 'image/jpeg';
      }

      final formMap = <String, dynamic>{
        fileField: await MultipartFile.fromFile(
          file.path,
          contentType: DioMediaType.parse(mimeType),
        ),
      };

      if (data != null) {
        data.forEach((key, value) {
          formMap[key] = value.toString();
        });
      }

      final formData = FormData.fromMap(formMap);
      final response = await dioClient.post(endpoint, data: formData);

      return response.data;
    } catch (error) {
      AppLogger.error('api', 'Upload error: $error');
      throw Exception('Upload error: $error');
    }
  }

  /// Checks server health. Used before login to verify server availability.
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
}
