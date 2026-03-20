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
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:manajemensekolah/main.dart';
import 'package:manajemensekolah/screen/login_screen.dart';
import 'package:manajemensekolah/services/performance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // static const String baseUrl = 'http://localhost:3001/api'; // iOS simulator atau web

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
      if (kDebugMode) {
        print('📡 API Base URL from .env: $baseUrl');
      }
      return;
    }

    // if (kIsWeb) {
    //   baseUrl = 'http://127.0.0.1:8000/api';
    // } else if (Platform.isAndroid) {
    //   baseUrl = 'http://127.0.0.1:8000/api';
    // } else {
    //   baseUrl = 'http://127.0.0.1:8000/api';
    // }
  }

  /// Performs an authenticated GET request with Firebase performance tracing.
  /// Like `Http::get($url)` in Laravel or `axios.get()` in Vue.
  /// [endpoint] - Relative path (e.g., '/student'). Appended to [baseUrl].
  /// [params] - Optional query parameters (like `$request->query()` in Laravel).
  /// Returns the parsed JSON response body.
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? params}) async {
    final metric = await PerformanceService.startHttpMetric(
      '$baseUrl$endpoint',
      HttpMethod.Get,
    );
    try {
      Uri uri = Uri.parse('$baseUrl$endpoint');
      if (params != null && params.isNotEmpty) {
        uri = uri.replace(queryParameters: params);
      }
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(const Duration(seconds: 30));
      await PerformanceService.stopHttpMetric(
        metric,
        httpResponseCode: response.statusCode,
        responsePayloadSize: response.contentLength,
      );
      return _handleResponse(response);
    } catch (e) {
      await PerformanceService.stopHttpMetric(metric, httpResponseCode: 0);
      if (kDebugMode) {
        print('❌ GET Error on $endpoint: $e');
      }
      rethrow;
    }
  }

  /// Performs an authenticated POST request with Firebase performance tracing.
  /// Like `Http::post($url, $data)` in Laravel or `axios.post()` in Vue.
  /// [data] - Request body as a Map, JSON-encoded automatically.
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final metric = await PerformanceService.startHttpMetric(
      '$baseUrl$endpoint',
      HttpMethod.Post,
    );
    try {
      final body = json.encode(data);
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _getHeaders(),
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      await PerformanceService.stopHttpMetric(
        metric,
        httpResponseCode: response.statusCode,
        requestPayloadSize: body.length,
        responsePayloadSize: response.contentLength,
      );
      return _handleResponse(response);
    } catch (e) {
      await PerformanceService.stopHttpMetric(metric, httpResponseCode: 0);
      if (kDebugMode) {
        print('❌ POST Error on $endpoint: $e');
      }
      rethrow;
    }
  }

  /// Performs an authenticated PUT request with Firebase performance tracing.
  /// Like `Http::put($url, $data)` in Laravel or `axios.put()` in Vue.
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final metric = await PerformanceService.startHttpMetric(
      '$baseUrl$endpoint',
      HttpMethod.Put,
    );
    try {
      final body = json.encode(data);
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _getHeaders(),
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      await PerformanceService.stopHttpMetric(
        metric,
        httpResponseCode: response.statusCode,
        requestPayloadSize: body.length,
        responsePayloadSize: response.contentLength,
      );
      return _handleResponse(response);
    } catch (e) {
      await PerformanceService.stopHttpMetric(metric, httpResponseCode: 0);
      if (kDebugMode) {
        print('❌ PUT Error on $endpoint: $e');
      }
      rethrow;
    }
  }

  /// Fetches grades filtered by subject, with optional academic year and limit.
  /// Like `Grade::where('subject_id', $id)->limit($limit)->get()` in Laravel.
  Future<List<dynamic>> getNilaiByMataPelajaran(
    String mataPelajaranId, {
    String? academicYearId,
    int limit = 100, // Added limit
  }) async {
    try {
      // Use backend filtering
      String url = '/grades?subject_id=$mataPelajaranId&limit=$limit';
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
      print('Error fetching nilai: $e');
      return [];
    }
  }

  /// Performs an authenticated DELETE request with Firebase performance tracing.
  /// Like `Http::delete($url)` in Laravel or `axios.delete()` in Vue.
  Future<dynamic> delete(String endpoint) async {
    final metric = await PerformanceService.startHttpMetric(
      '$baseUrl$endpoint',
      HttpMethod.Delete,
    );
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl$endpoint'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 30));
      await PerformanceService.stopHttpMetric(
        metric,
        httpResponseCode: response.statusCode,
        responsePayloadSize: response.contentLength,
      );
      return _handleResponse(response);
    } catch (e) {
      await PerformanceService.stopHttpMetric(metric, httpResponseCode: 0);
      if (kDebugMode) {
        print('❌ DELETE Error on $endpoint: $e');
      }
      rethrow;
    }
  }

  /// Downloads a file as raw bytes. Like `Storage::download()` in Laravel.
  /// Returns the file content as [Uint8List] for saving to disk.
  static Future<Uint8List> downloadFile(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Download Error on $endpoint: $e');
      }
      rethrow;
    }
  }

  /// Retrieves the stored auth token from SharedPreferences.
  /// Like `auth()->token()` in Laravel Sanctum.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // Add school_id header if available
    if (userJson != null) {
      try {
        if (kDebugMode) {
          print('🔍 Checking headers - UserJson length: ${userJson.length}');
          print(
            '🔍 UserJson snippet: ${userJson.substring(0, userJson.length > 100 ? 100 : userJson.length)}',
          );
        }

        final user = json.decode(userJson);

        if (user['school_id'] != null) {
          headers['X-School-ID'] = user['school_id'].toString();
          if (kDebugMode) {
            print('✅ Injected X-School-ID: ${headers['X-School-ID']}');
          }
        } else {
          if (kDebugMode) print('⚠️ school_id missing in user object');
        }
      } catch (e) {
        // Ignore JSON parse errors
        if (kDebugMode) {
          print('⚠️ Failed to parse user JSON for school_id: $e');
        }
      }
    } else {
      if (kDebugMode) print('⚠️ User JSON is null in SharedPreferences');
    }

    return headers;
  }

  /// Central response handler for ALL API calls in the app.
  /// Like Laravel's exception handler (`Handler::render()`) combined with
  /// an Axios response interceptor. Handles:
  /// - 204 No Content -> returns null
  /// - 2xx Success -> returns parsed JSON body
  /// - 401 Unauthorized -> auto-logout with redirect to login screen
  /// - 403 Forbidden -> distinguishes school access denied vs real forbidden
  /// - 422 Validation -> extracts first validation error message (Laravel format)
  /// - 500+ Server errors -> throws without logging out
  static dynamic _handleResponse(http.Response response) {
    try {
      if (response.statusCode == 204) {
        return null;
      }

      final responseBody = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        // Handle Laravel validation errors (422)
        if (response.statusCode == 422) {
          if (responseBody['errors'] != null) {
            final errors = responseBody['errors'] as Map<String, dynamic>;
            final firstError = errors.values.first;
            final errorMessage = firstError is List
                ? firstError.first
                : firstError.toString();
            throw Exception(errorMessage);
          } else if (responseBody['message'] != null) {
            throw Exception(responseBody['message']);
          }
        }

        final errorMessage =
            responseBody['error'] ??
            responseBody['message'] ??
            'Request failed with status: ${response.statusCode}';

        // Handle specific authentication errors (should logout)
        if (response.statusCode == 401) {
          _handleAuthenticationErrorWithMessage(
            'Session expired. Please login again.',
          );
        } else if (response.statusCode == 403) {
          // Differentiate: school context error vs genuine forbidden
          final is403SchoolContext =
              responseBody is Map &&
              (responseBody['error'] ?? '').toString().contains(
                'Anda tidak memiliki akses ke sekolah ini',
              );
          if (is403SchoolContext) {
            // Don't logout — just signal that school context is invalid
            // so the calling screen can handle gracefully
            throw Exception('SCHOOL_ACCESS_DENIED: ${responseBody['error']}');
          } else {
            _handleAuthenticationErrorWithMessage(
              'Access forbidden. Please login again.',
            );
          }
        }
        // For 500+ errors, just throw the exception without logging out
        // The UI will handle displaying the error to the user

        throw Exception(errorMessage);
      }
    } catch (e) {
      // FormatException = server returned non-JSON (e.g. HTML error page)
      // Don't logout - just rethrow so UI can handle it
      rethrow;
    }
  }

  /// Handles authentication failures by clearing stored data and redirecting to login.
  /// Like Laravel's `auth()->logout()` + redirect, or Vue Router's navigation guard.
  /// Clears SharedPreferences (token, user data) and uses the global navigator key
  /// to push the LoginScreen with an error message.
  static Future<void> _handleAuthenticationErrorWithMessage(
    String errorMessage,
  ) async {
    try {
      if (kDebugMode) {
        print('🔴 Handling authentication error: $errorMessage');
      }

      // Clear all stored data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Delay sedikit untuk memastikan context sudah ready
      await Future.delayed(const Duration(milliseconds: 300));

      // Navigate to login with error message
      if (navigatorKey.currentState != null &&
          navigatorKey.currentState!.mounted) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(initialError: errorMessage),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during authentication cleanup: $e');
      }
      // Fallback ke named route
      try {
        navigatorKey.currentState?.pushReplacementNamed('/auth/login');
      } catch (_) {
        // If all navigation fails, we're likely in a bad state
        if (kDebugMode) {
          print('🚨 Critical: Unable to navigate to login');
        }
      }
    }
  }

  /// Public method for other services to trigger logout with a custom message.
  /// Like calling `Auth::logout()` from anywhere in a Laravel app.
  static Future<void> logoutWithMessage(String message) async {
    await _handleAuthenticationErrorWithMessage(message);
  }

  Future<List<dynamic>> getData(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await _getHeaders(),
      );
      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ getData Error on $endpoint: $e');
      }
      return [];
    }
  }

  /// Authenticates a user with email/password, optionally with school and role selection.
  /// Like Laravel's `Auth::attempt()` but with a multi-step flow:
  /// 1. May return `pilih_sekolah: true` -> user must select a school first
  /// 2. May return `pilih_role: true` -> user must select a role
  /// 3. May return `require_otp: true` -> OTP verification needed
  /// 4. On success: returns `{token, user}` for storage
  /// Similar to a Vuex `login` action that handles multiple auth flows.
  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? schoolId,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> body = {'email': email, 'password': password};

      if (schoolId != null) {
        body['school_id'] = schoolId;
      }

      if (role != null) {
        body['role'] = role;
      }

      if (kDebugMode) {
        print('📤 Login request: ${body.keys}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );

      if (kDebugMode) {
        print('📥 Login response status: ${response.statusCode}');
        print('📥 Login response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle semua kemungkinan flow
        if (responseData['pilih_sekolah'] == true) {
          if (kDebugMode) {
            print('🔄 Login flow: Need to select school');
          }
          return responseData;
        }

        // PERBAIKAN: Handle jika setelah pilih sekolah, perlu pilih role
        if (responseData['pilih_role'] == true) {
          if (kDebugMode) {
            print('🔄 Login flow: Need to select role after school selection');
          }
          return responseData;
        }

        if (responseData['require_otp'] == true ||
            responseData['otp_debug'] != null ||
            responseData['message'] == 'OTP sent to email') {
          if (kDebugMode) {
            print('🔄 Login flow: OTP required');
          }
          return responseData;
        }

        // Hanya validasi token untuk login sukses langsung
        if (responseData['token'] == null) {
          throw Exception('Server tidak mengembalikan token');
        }

        if (responseData['user'] == null) {
          throw Exception('Server tidak mengembalikan data user');
        }

        return responseData;
      } else {
        final errorResponse = json.decode(response.body);
        throw Exception(
          errorResponse['error'] ??
              'Login failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ApiService login error: $e');
      }
      rethrow;
    }
  }

  /// Verifies the OTP code sent to the user's email during login.
  /// Like a Laravel OTP verification endpoint. Part of the multi-step auth flow.
  static Future<Map<String, dynamic>> verifyOtp(
    String email,
    String otp, {
    String? schoolId,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> body = {'email': email, 'otp': otp};

      if (schoolId != null) {
        body['school_id'] = schoolId;
      }

      if (role != null) {
        body['role'] = role;
      }

      if (kDebugMode) {
        print('📤 Verify OTP request: ${body.keys}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (kDebugMode) {
        print('📥 Verify OTP response status: ${response.statusCode}');
        print('📥 Verify OTP response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        final errorResponse = json.decode(response.body);
        throw Exception(
          errorResponse['error'] ??
              'OTP verification failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ApiService Verify OTP error: $e');
      }
      rethrow;
    }
  }

  /// Authenticates via Google OAuth. Sends Google ID token for server-side verification.
  /// Like Laravel Socialite's Google driver. Backend verifies the ID token
  /// against Google's tokeninfo API for security.
  static Future<Map<String, dynamic>> googleLogin({
    required String email,
    String? displayName,
    String? photoUrl,
    String? idToken, // Google ID Token (JWT) for server-side verification
  }) async {
    try {
      final Map<String, dynamic> body = {
        'email': email,
        'name': displayName,
        'avatar': photoUrl,
        'id_token':
            idToken, // Backend verifies this against Google tokeninfo API
      };

      if (kDebugMode) {
        print('📤 Google Login request: $email');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google-login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept':
              'application/json', // Force JSON response to avoid 302 Redirect on validation error
        },
        body: json.encode(body),
      );

      if (kDebugMode) {
        print('📥 Google Login response status: ${response.statusCode}');
        print('📥 Google Login response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        final errorResponse = json.decode(response.body);
        throw Exception(
          errorResponse['error'] ??
              errorResponse['message'] ?? // Laravel often returns 'message' for validation errors
              'Google Login failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ApiService Google login error: $e');
      }
      rethrow;
    }
  }

  /// Fetches the available roles for the current user (e.g., admin, guru, siswa).
  /// Like `auth()->user()->roles` in Laravel with Spatie Permission.
  static Future<List<dynamic>> getUserRoles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/roles'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result['available_roles'] is List ? result['available_roles'] : [];
  }

  /// Switches the user's active role within the same school.
  /// Reuses [switchSchool] logic. Like changing the active guard in Laravel.
  static Future<Map<String, dynamic>> switchRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null) throw Exception('User data not found');

    final user = json.decode(userJson);
    final schoolId =
        user['school_id'] ?? user['sekolah_id']; // Handle key variations

    if (schoolId == null) throw Exception('School ID not found');

    return switchSchool(schoolId.toString(), role: role);
  }

  /// Fetches the list of schools accessible to the current user.
  /// Like a multi-tenant school selector. Returns school objects.
  static Future<List<dynamic>> getUserSchools() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/schools'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  /// Fetches dashboard statistics (student count, teacher count, etc.) by role.
  /// Like a Laravel dashboard controller that aggregates stats per user role.
  static Future<Map<String, dynamic>> getDashboardStats({
    required String role,
    String? academicYearId,
  }) async {
    try {
      String url = '$baseUrl/dashboard/stats?role=$role';
      if (academicYearId != null && academicYearId.isNotEmpty) {
        url += '&academic_year_id=$academicYearId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      if (result is Map<String, dynamic> && result['success'] == true) {
        return Map<String, dynamic>.from(result['data'] ?? {});
      }
      return {};
    } catch (e) {
      if (kDebugMode) print('Error fetching dashboard stats: $e');
      return {};
    }
  }

  /// Gets the count of unread announcements for badge display.
  /// Like a notification count endpoint. Returns 0 on error.
  static Future<int> getUnreadAnnouncementCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/announcement/unread-count'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) print('Error fetching unread count: $e');
      return 0;
    }
  }

  static Future<bool> markAnnouncementRead(List<String> ids) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/announcement/mark-read'),
        headers: await _getHeaders(),
        body: json.encode({'ids': ids}),
      );
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Error marking announcement read: $e');
      return false;
    }
  }

  /// Switches the user's active school context (multi-tenant).
  /// Like changing the active tenant in a Laravel multi-tenancy setup.
  /// Returns a new token scoped to the selected school.
  static Future<Map<String, dynamic>> switchSchool(
    String schoolId, {
    String? role,
  }) async {
    final Map<String, dynamic> body = {'school_id': schoolId};
    if (role != null) {
      body['role'] = role;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/switch-school'),
      headers: await _getHeaders(),
      body: json.encode(body),
    );

    return _handleResponse(response);
  }

  /// Fetches student grades (nilai) with multiple optional filters.
  /// Like `Grade::filter($request)->get()` in Laravel.
  static Future<List<dynamic>> getNilai({
    String? siswaId,
    String? guruId,
    String? mataPelajaranId,
    String? jenis,
    String? academicYearId,
  }) async {
    String url = '$baseUrl/grades?';
    if (siswaId != null) url += 'student_id=$siswaId&';
    if (guruId != null) url += 'teacher_id=$guruId&';
    if (mataPelajaranId != null) url += 'subject_id=$mataPelajaranId&';
    if (jenis != null) url += 'grade_type=$jenis&';
    if (academicYearId != null) url += 'academic_year_id=$academicYearId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    if (result is List) return result;
    if (result is Map && result.containsKey('data') && result['data'] is List) {
      return result['data'];
    }
    return [];
  }

  /// Creates a new grade entry. Like `Grade::create($data)` in Laravel.
  static Future<dynamic> tambahNilai(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/grade'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  /// Fetches RPP (lesson plans) with optional filters.
  /// Like `Rpp::filter($request)->get()` in Laravel.
  static Future<List<dynamic>> getRPP({
    String? teacherId,
    String? status,
    String? search,
    String? academicYearId,
  }) async {
    String url = '$baseUrl/rpp?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (status != null) url += 'status=$status&';
    if (search != null) url += 'search=$search&';
    if (academicYearId != null) url += 'academic_year_id=$academicYearId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);

    if (result is Map && result.containsKey('data')) {
      return result['data'] is List ? result['data'] : [];
    }

    return result is List ? result : [];
  }

  /// Get a single RPP by its ID.
  ///
  /// This is useful to retrieve the full RPP record (including AI-generated fields)
  /// when the list endpoint only returns a summary.
  static Future<Map<String, dynamic>> getRppById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/rpp/$id'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is Map<String, dynamic> ? result : {};
  }

  // Get RPP with pagination & filters (recommended)
  static Future<Map<String, dynamic>> getRppPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? status,
    String? search,
    String? subjectId,
    String? classId,
    String? semester,
    String? tahunAjaran,
    String? tanggalStart,
    String? tanggalEnd,
    String? academicYearId,
    String? mataPelajaranId, // Added based on queryParams
    String? tanggal, // Added based on queryParams
  }) async {
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (teacherId != null && teacherId.isNotEmpty)
      queryParams['teacher_id'] = teacherId;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (subjectId != null && subjectId.isNotEmpty) {
      queryParams['subject_id'] = subjectId;
    }
    if (mataPelajaranId != null && mataPelajaranId.isNotEmpty) {
      queryParams['mataPelajaranId'] = mataPelajaranId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['classId'] = classId;
    }
    if (tanggal != null && tanggal.isNotEmpty) {
      queryParams['tanggal'] = tanggal;
    }
    if (tanggalStart != null && tanggalStart.isNotEmpty) {
      queryParams['tanggalStart'] = tanggalStart;
    }
    if (tanggalEnd != null && tanggalEnd.isNotEmpty) {
      queryParams['tanggalEnd'] = tanggalEnd;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (semester != null && semester.isNotEmpty) {
      queryParams['semester'] = semester;
    }
    if (tahunAjaran != null && tahunAjaran.isNotEmpty) {
      queryParams['tahun_ajaran'] = tahunAjaran;
    }

    final queryString = Uri(queryParameters: queryParams).query;

    final response = await http.get(
      Uri.parse('$baseUrl/rpp?$queryString'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);

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
  static Future<Map<String, dynamic>> getTagihanPaginated({
    int page = 1,
    int limit = 10,
    String? status,
    String? siswaId,
    String? jenisPembayaranId,
    String? classId,
  }) async {
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (siswaId != null && siswaId.isNotEmpty) {
      queryParams['student_id'] = siswaId;
    }
    if (jenisPembayaranId != null && jenisPembayaranId.isNotEmpty) {
      queryParams['payment_type_id'] = jenisPembayaranId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }

    final queryString = Uri(queryParameters: queryParams).query;

    final response = await http.get(
      Uri.parse('$baseUrl/bills?$queryString'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);

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

  static Future<dynamic> tambahRPP(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rpp'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> updateRPP(
    String rppId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/rpp/$rppId'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> updateStatusRPP(
    String rppId,
    String status, {
    String? catatan,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/rpp/$rppId/status'),
      headers: await _getHeaders(),
      body: json.encode({'status': status, 'catatan': catatan}),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> deleteRPP(String rppId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/rpp/$rppId'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  // Di api_services.dart - Perbaiki fungsi uploadFileRPP
  static Future<dynamic> uploadFileRPP(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/rpp'),
      );

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add file dengan cara yang benar
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Nama field harus sesuai dengan backend
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      // Send request dan dapatkan response
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Upload Response Status: ${response.statusCode}');
      print('Upload Response Body: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Upload failed with status: ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      print('Upload error details: $e');
      throw Exception('Upload error: $e');
    }
  }

  /// Fetches attendance (absensi) records with multiple optional filters.
  /// Like `Attendance::filter($request)->get()` in Laravel.
  /// Handles both formats: direct array or `{success, data, pagination}`.
  static Future<List<dynamic>> getAbsensi({
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? academicYearId,
    String? lessonHourId,
  }) async {
    String url = '$baseUrl/attendance?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (date != null) url += 'tanggal=$date&';
    if (subjectId != null) url += 'mataPelajaranId=$subjectId&';
    if (studentId != null) url += 'student_id=$studentId&';
    if (classId != null) url += 'classId=$classId&';
    if (academicYearId != null) url += 'academic_year_id=$academicYearId&';
    if (lessonHourId != null) url += 'lesson_hour_id=$lessonHourId&';

    if (kDebugMode) {
      print('📍 Calling getAbsensi: $url');
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);

    if (kDebugMode) {
      print('📦 Absensi response type: ${result.runtimeType}');
      if (result is Map) {
        print('📦 Response has data field: ${result.containsKey('data')}');
        if (result.containsKey('data')) {
          print('📦 Data is List: ${result['data'] is List}');
          print('📦 Data length: ${(result['data'] as List?)?.length ?? 0}');
        }
      } else if (result is List) {
        print('📦 Direct array, length: ${result.length}');
      }
    }

    // Handle both formats: direct array or {success, data, pagination}
    if (result is Map && result['data'] is List) {
      return result['data'];
    } else if (result is List) {
      return result;
    } else {
      if (kDebugMode) {
        print('⚠️ Unexpected response format for absensi');
      }
      return [];
    }
  }

  // Delete absences by summary (teacher, subject, class, date)
  static Future<dynamic> deleteAbsensiSummary({
    required String teacherId,
    required String subjectId,
    required String date,
    String? classId,
    String? lessonHourId,
  }) async {
    String query =
        '/attendance?teacher_id=$teacherId&subject_id=$subjectId&date=$date';
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
  static Future<Map<String, dynamic>> getAbsensiPaginated({
    int page = 1,
    int limit = 20,
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? tanggalStart,
    String? tanggalEnd,
    String? academicYearId,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (teacherId != null && teacherId.isNotEmpty)
        params['teacher_id'] = teacherId;
      if (date != null && date.isNotEmpty) params['date'] = date;
      if (subjectId != null && subjectId.isNotEmpty) {
        params['subject_id'] = subjectId;
      }
      if (studentId != null && studentId.isNotEmpty)
        params['student_id'] = studentId;
      if (classId != null && classId.isNotEmpty) params['class_id'] = classId;
      if (tanggalStart != null && tanggalStart.isNotEmpty) {
        params['tanggalStart'] = tanggalStart;
      }
      if (tanggalEnd != null && tanggalEnd.isNotEmpty) {
        params['tanggalEnd'] = tanggalEnd;
      }
      if (academicYearId != null && academicYearId.isNotEmpty) {
        params['academic_year_id'] = academicYearId;
      }

      final uri = Uri.parse(
        '$baseUrl/attendance',
      ).replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      ); // Fixed headers
      final result = _handleResponse(response);

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
      if (kDebugMode) print('Error getAbsensiPaginated: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getAbsensiSummary({
    String? teacherId,
    String? date,
    String? subjectId,
    String? classId,
    String? academicYearId,
  }) async {
    String url = '$baseUrl/attendance/summary?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (date != null) url += 'date=$date&';
    if (subjectId != null) url += 'subjectId=$subjectId&';
    if (classId != null) url += 'classId=$classId&';
    if (academicYearId != null) url += 'academic_year_id=$academicYearId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    if (result is Map && result['data'] is List) {
      return result['data'];
    }
    return result is List ? result : [];
  }

  // New method for paginated summary
  static Future<Map<String, dynamic>> getAbsensiSummaryPaginated({
    int page = 1,
    int limit = 10,
    String? guruId,
    String? mataPelajaranId,
    String? classId,
    String? tanggal,
    String? tanggalStart,
    String? tanggalEnd,
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

      if (guruId != null && guruId.isNotEmpty) params['teacher_id'] = guruId;
      if (mataPelajaranId != null && mataPelajaranId.isNotEmpty) {
        params['mataPelajaranId'] = mataPelajaranId;
      }
      if (classId != null && classId.isNotEmpty) params['classId'] = classId;
      if (tanggal != null && tanggal.isNotEmpty) params['tanggal'] = tanggal;
      if (tanggalStart != null && tanggalStart.isNotEmpty) {
        params['tanggalStart'] = tanggalStart;
      }
      if (tanggalEnd != null && tanggalEnd.isNotEmpty) {
        params['tanggalEnd'] = tanggalEnd;
      }
      if (dayIds != null && dayIds.isNotEmpty) {
        params['day_ids'] = dayIds.join(',');
      }
      if (lessonHourIds != null && lessonHourIds.isNotEmpty) {
        params['lesson_hour_ids'] = lessonHourIds.join(',');
      }

      final uri = Uri.parse(
        '$baseUrl/attendance/summary',
      ).replace(queryParameters: params);

      final response = await http.get(uri, headers: await _getHeaders());
      final result = _handleResponse(response);

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
      if (kDebugMode) print('Error getAbsensiSummaryPaginated: $e');
      rethrow;
    }
  }

  /// Creates a new attendance record. Like `Attendance::create($data)` in Laravel.
  static Future<dynamic> tambahAbsensi(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> deleteAbsensi({
    required String subjectId,
    required String classId,
    required String date,
    String? lessonHourId,
  }) async {
    try {
      final params = <String, String>{
        'subject_id': subjectId,
        'class_id': classId,
        'date': date,
      };
      if (lessonHourId != null) params['lesson_hour_id'] = lessonHourId;

      final uri = Uri.parse(
        '$baseUrl/attendance',
      ).replace(queryParameters: params);
      final response = await http.delete(uri, headers: await _getHeaders());

      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print('ApiService.deleteAbsensi error: $e');
      rethrow;
    }
  }

  /// Fetches the school's available grade levels (e.g., 1-6 for SD, 7-9 for SMP).
  /// Like `SchoolConfig::getGradeLevels()` in Laravel. Falls back to 1-12.
  Future<List<int>> getGradeLevels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/school-configs/grade-levels'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List
          ? result.cast<int>()
          : [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting grade levels: $e');
      }
      return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]; // fallback
    }
  }

  // Get kelas by mata pelajaran
  Future<List<dynamic>> getClassBySubjectId(String subjectId) async {
    try {
      final result = await get(
        '/class-by-mata-pelajaran?subject_id=$subjectId',
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
      print('Error getting kelas by mata pelajaran: $e');
      return [];
    }
  }

  Future<dynamic> createNilai(Map<String, dynamic> data) async {
    // Sanitize data - ubah undefined menjadi null
    final sanitizedData = _sanitizeData(data);
    return await post('/grade', sanitizedData);
  }

  Future<dynamic> updateNilai(String id, Map<String, dynamic> data) async {
    // Sanitize data - ubah undefined menjadi null
    final sanitizedData = _sanitizeData(data);
    return await put('/grade/$id', sanitizedData);
  }

  /// Sanitizes form data by removing null and 'undefined' string values.
  /// Prevents sending invalid data to the Laravel backend.
  /// Like a Laravel FormRequest's `prepareForValidation()` method.
  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized.removeWhere(
      (key, value) => value == null || value == 'undefined',
    );
    sanitized.forEach((key, value) {
      if (value == 'undefined') {
        sanitized[key] = null;
      }
    });
    return sanitized;
  }

  // Get mata pelajaran with kelas data
  Future<List<dynamic>> getMataPelajaranWithKelas() async {
    try {
      final result = await get('/subject-with-class');
      return result is List ? result : [];
    } catch (e) {
      print('Error getting mata pelajaran with kelas: $e');
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
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );

      // Add headers dengan authorization
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Deteksi MIME type yang benar
      String? mimeType;
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

      print('Uploading file: ${file.path}');
      print('File extension: $extension');
      print('MIME type: $mimeType');

      // Add file dengan MIME type yang benar
      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Add other data
      if (data != null) {
        data.forEach((key, value) {
          request.fields[key] = value.toString();
        });
      }

      print('Request fields: ${request.fields}');
      print('Request files: ${request.files.length}');

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print('Upload Response Status: ${response.statusCode}');
      print('Upload Response Body: $responseData');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(responseData);
      } else {
        throw Exception(
          'Upload failed: ${response.statusCode} - $responseData',
        );
      }
    } catch (error) {
      print('Upload error: $error');
      throw Exception('Upload error: $error');
    }
  }

  static Future<void> markAttendanceRead({required String studentId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/mark-read'),
        headers: await _getHeaders(),
        body: jsonEncode({'student_id': studentId}),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Error marking attendance as read: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking attendance read: $e');
      }
    }
  }

  static Future<void> markBillRead({
    String? studentId,
    List<String>? billIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bill/mark-read'),
        headers: await _getHeaders(),
        body: jsonEncode({
          if (studentId != null) 'student_id': studentId,
          if (billIds != null) 'bill_ids': billIds,
        }),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Error marking bills as read: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking bills read: $e');
      }
    }
  }

  static Future<void> markSingleBillRead({required String billId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bill/mark-single-read'),
        headers: await _getHeaders(),
        body: jsonEncode({'bill_id': billId}),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Error marking bill as read: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking bill read: $e');
      }
    }
  }

  static Future<int> getUnreadBillingCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bill/unread-count'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return int.tryParse(result['count']?.toString() ?? '0') ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting unread billing count: $e');
      }
      return 0;
    }
  }

  /// Checks server health. Intentionally does NOT use [_handleResponse]
  /// to avoid triggering auto-logout redirects that cause login screen loops.
  /// Like a simple ping endpoint. Used before login to verify server availability.
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {'status': 'ok'};
        }
      } else {
        throw Exception(
          'Server returned status ${response.statusCode}',
        );
      }
    } on Exception {
      rethrow;
    }
  }

  // Manual payment entry by admin (for offline/cash payments)
  Future<dynamic> inputPembayaranManual(Map<String, dynamic> data) async {
    try {
      return await post('/payment/manual', data);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error input pembayaran manual: $e');
      }
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
      return await apiService.post('/generate-bill', body);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error generating bills: $e');
      }
      rethrow;
    }
  }

  // Get Finance Dashboard Stats
  static Future<Map<String, dynamic>> getFinanceDashboardStats() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/finance/dashboard');
      if (response is Map<String, dynamic>) {
        return response;
      }
      return {};
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting finance stats: $e');
      }
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
        '/finance/generated-months?payment_type_id=$paymentTypeId&academic_year_id=$academicYearId',
      );
      if (response is List) {
        return List<String>.from(response);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting generated months: $e');
      }
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
      if (kDebugMode) {
        print('❌ Error deleting bills by type: $e');
      }
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
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      if (kDebugMode) {
        print('📤 Sending to: $baseUrl/fcm/token');
        print('📤 Device type: $deviceType');
        print('📤 FCM Token length: ${token.length}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/fcm/token'),
        headers: await _getHeaders(),
        body: json.encode({'token': token, 'device_type': deviceType}),
      );

      if (kDebugMode) {
        print('📥 FCM Response Status: ${response.statusCode}');
        print('📥 FCM Response Body: ${response.body}');
      }

      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending FCM token: $e');
      }
      rethrow;
    }
  }

  /// Removes the device's FCM token from the backend (on logout).
  /// Like unregistering from a Laravel notification channel.
  static Future<Map<String, dynamic>> deleteFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/fcm/token'),
        headers: await _getHeaders(),
        body: json.encode({'token': token}),
      );

      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting FCM token: $e');
      }
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
    Map<String, dynamic> queryParams = {};
    if (date != null && date.isNotEmpty) queryParams['tanggal'] = date;
    if (classId != null && classId.isNotEmpty)
      queryParams['class_id'] = classId;
    if (subjectId != null && subjectId.isNotEmpty) {
      queryParams['subject_id'] = subjectId;
    }
    if (teacherId != null && teacherId.isNotEmpty) {
      queryParams['teacher_id'] = teacherId;
    }
    if (lessonHourId != null && lessonHourId.isNotEmpty) {
      queryParams['lesson_hour_id'] = lessonHourId;
    }

    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/stats?$queryString'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result['data'] ?? {};
    } catch (e) {
      if (kDebugMode) print('Error fetching attendance stats: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getFinanceBillStats({
    String? academicYearId,
    String? paymentTypeId,
    String? month,
    String? classId,
  }) async {
    Map<String, dynamic> queryParams = {};
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (paymentTypeId != null && paymentTypeId.isNotEmpty) {
      queryParams['payment_type_id'] = paymentTypeId;
    }
    if (month != null && month.isNotEmpty) queryParams['month'] = month;
    if (classId != null && classId.isNotEmpty)
      queryParams['class_id'] = classId;

    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/finance/bills/stats?$queryString'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result['data'] ?? {};
    } catch (e) {
      if (kDebugMode) print('Error fetching finance bill stats: $e');
      return {};
    }
  }

  static Future<int> getUnreadGradeCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/grade/unread-count'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return int.tryParse(result['count']?.toString() ?? '0') ?? 0;
    } catch (e) {
      if (kDebugMode) print('Error fetching unread grade count: $e');
      return 0;
    }
  }

  static Future<void> markGradeAsRead(List<String> gradeIds) async {
    if (gradeIds.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/grade/mark-read'),
        headers: await _getHeaders(),
        body: json.encode({'grade_ids': gradeIds}),
      );
    } catch (e) {
      if (kDebugMode) print('Error marking grades as read: $e');
    }
  }

  static Future<int> getUnreadPresenceCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/unread-count'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return int.tryParse(result['count']?.toString() ?? '0') ?? 0;
    } catch (e) {
      if (kDebugMode) print('Error fetching unread presence count: $e');
      return 0;
    }
  }

  static Future<void> markPresenceAsRead(List<String> attendanceIds) async {
    if (attendanceIds.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/attendance/mark-read'),
        headers: await _getHeaders(),
        body: json.encode({'attendance_ids': attendanceIds}),
      );
    } catch (e) {
      if (kDebugMode) print('Error marking presence as read: $e');
    }
  }

  static Future<List<dynamic>> getAttendanceDashboardChart({
    String? academicYearId,
    String? month,
    String? week,
    String? role,
  }) async {
    try {
      final params = <String, String>{};
      if (academicYearId != null) params['academic_year_id'] = academicYearId;
      if (month != null) params['month'] = month;
      if (week != null) params['week'] = week;
      if (role != null) params['role'] = role;

      final uri = Uri.parse(
        '$baseUrl/attendance/dashboard-chart',
      ).replace(queryParameters: params);

      final response = await http.get(uri, headers: await _getHeaders());
      final result = _handleResponse(response);

      if (result is List) return result;
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching attendance dashboard chart: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getFinanceDashboardChart({
    String? academicYearId,
  }) async {
    try {
      final params = <String, String>{};
      if (academicYearId != null) params['academic_year_id'] = academicYearId;

      final uri = Uri.parse(
        '$baseUrl/finance/dashboard-chart',
      ).replace(queryParameters: params);

      final response = await http.get(uri, headers: await _getHeaders());
      final result = _handleResponse(response);

      if (result is List) return result;
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching finance dashboard chart: $e');
      return [];
    }
  }
}
