import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';

class AuthService {
  /// Authenticates a user with email/password, optionally with school and role selection.
  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? schoolId,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> body = {'email': email, 'password': password};

      if (schoolId != null) body['school_id'] = schoolId;
      if (role != null) body['role'] = role;

      AppLogger.debug('auth_api', 'Login request: ${body.keys}');

      final response = await dioClient.post(ApiEndpoints.login, data: body);
      final responseData = response.data;

      AppLogger.debug(
        'auth_api',
        '📥 Login response status: ${response.statusCode}',
      );
      AppLogger.debug('auth_api', '📥 Login response data: $responseData');

      final normalized = _normalizeFlags(responseData);

      if (normalized['require_otp'] == true ||
          normalized['otp_debug'] != null ||
          normalized['message'] == 'OTP sent to email') {
        return normalized;
      }

      if (normalized['needsSchoolSelection'] == true ||
          normalized['needsRoleSelection'] == true) {
        return normalized;
      }

      if (normalized['token'] == null) {
        throw Exception('Server tidak mengembalikan token');
      }
      if (normalized['user'] == null) {
        throw Exception('Server tidak mengembalikan data user');
      }

      return normalized;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        throw Exception(
          responseData['error'] ??
              responseData['message'] ??
              'Login failed with status: ${e.response?.statusCode}',
        );
      }
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Verifies the OTP code sent to the user's email during login.
  static Future<Map<String, dynamic>> verifyOtp(
    String email,
    String otp, {
    String? schoolId,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> body = {'email': email, 'otp': otp};

      if (schoolId != null) body['school_id'] = schoolId;
      if (role != null) body['role'] = role;

      final response = await dioClient.post(ApiEndpoints.verifyOtp, data: body);
      return _normalizeFlags(response.data);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        throw Exception(
          responseData['error'] ??
              'OTP verification failed with status: ${e.response?.statusCode}',
        );
      }
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Authenticates via Google OAuth. Sends Google ID token for server-side verification.
  static Future<Map<String, dynamic>> googleLogin({
    required String email,
    String? displayName,
    String? photoUrl,
    String? idToken,
    String? serverAuthCode,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'email': email,
        'name': displayName,
        'avatar': photoUrl,
        'id_token': idToken,
        'server_auth_code': serverAuthCode,
      };

      final response = await dioClient.post(
        ApiEndpoints.googleLogin,
        data: body,
      );
      return _normalizeFlags(response.data);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        throw Exception(
          responseData['error'] ??
              responseData['message'] ??
              'Google Login failed with status: ${e.response?.statusCode}',
        );
      }
      if (e.error is Exception) throw e.error as Exception;
      rethrow;
    }
  }

  /// Fetches the available roles for the current user.
  static Future<List<dynamic>> getUserRoles() async {
    final response = await dioClient.get(ApiEndpoints.userRolesList);
    final result = response.data;
    return result['available_roles'] is List ? result['available_roles'] : [];
  }

  /// Switches the user's active role within the same school.
  static Future<Map<String, dynamic>> switchRole(String role) async {
    final secureStorage = SecureStorageService();
    var userJson = await secureStorage.getUserDataJson();

    // Fallback to PreferencesService if missing
    if (userJson == null) {
      final prefs = PreferencesService();
      userJson = prefs.getString('user');
    }

    if (userJson == null) throw Exception('User data not found');

    final user = User.fromJson(json.decode(userJson));
    final schoolId = user.schoolId;

    if (schoolId == null) throw Exception('School ID not found');

    return switchSchool(schoolId.toString(), role: role);
  }

  /// Fetches the list of schools accessible to the current user.
  static Future<List<dynamic>> getUserSchools() async {
    final response = await dioClient.get(ApiEndpoints.userSchoolsList);
    final result = response.data;
    return result is List ? result : [];
  }

  /// Switches the user's active school context (multi-tenant).
  static Future<Map<String, dynamic>> switchSchool(
    String schoolId, {
    String? role,
  }) async {
    try {
      final Map<String, dynamic> body = {'school_id': schoolId};
      if (role != null) body['role'] = role;

      final response = await dioClient.post(
        ApiEndpoints.switchSchool,
        data: body,
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return _normalizeFlags(response.data);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      // If role was invalid, retry without role to let the backend decide
      if (role != null &&
          responseData is Map &&
          (responseData['error']?.toString().contains('Role tidak valid') ==
                  true ||
              responseData['message']?.toString().contains(
                    'Role tidak valid',
                  ) ==
                  true)) {
        AppLogger.info(
          'auth_api',
          'Role invalid for school, retrying without role',
        );
        return switchSchool(schoolId);
      }
      if (responseData is Map) {
        throw Exception(
          responseData['error'] ??
              responseData['message'] ??
              'Switch school failed',
        );
      }
      rethrow;
    }
  }

  /// "Lupa kata sandi?" — POST /auth/forgot-password.
  ///
  /// Always resolves with `{success, message}` even when the email
  /// doesn't match a known user (the backend collapses the response to
  /// a neutral message to prevent email enumeration). Throttled at
  /// 6/min on the server, plus an extra 429 path here in case the
  /// broker rate-limit kicks in before the throttle.
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.forgotPassword,
        data: {'email': email},
      );
      final body = response.data;
      if (body is Map) return Map<String, dynamic>.from(body);
      return {'success': true};
    } on DioException catch (e) {
      final body = e.response?.data;
      if (e.response?.statusCode == 429 && body is Map) {
        // Surface throttle message instead of the generic Dio dump.
        throw Exception(
          body['message'] ?? 'Terlalu banyak permintaan. Coba lagi nanti.',
        );
      }
      if (body is Map) {
        throw Exception(
          body['message'] ?? body['error'] ?? 'Gagal mengirim tautan reset.',
        );
      }
      throw Exception('Gagal mengirim tautan reset. Periksa koneksi Anda.');
    }
  }

  /// "Bantuan masuk" — POST /auth/help-request.
  ///
  /// Public endpoint, audit-logged on the server. Resolves with
  /// `{success, message}`. Each user is throttled to 3 requests per
  /// minute; if hit we surface the generic throttle message so the
  /// UI can show it inline.
  static Future<Map<String, dynamic>> helpRequest({
    required String name,
    required String email,
    String? phone,
    String? schoolName,
    required String message,
  }) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.helpRequest,
        data: {
          'name': name,
          'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (schoolName != null && schoolName.isNotEmpty)
            'school_name': schoolName,
          'message': message,
        },
      );
      final body = response.data;
      if (body is Map) return Map<String, dynamic>.from(body);
      return {'success': true};
    } on DioException catch (e) {
      final body = e.response?.data;
      if (e.response?.statusCode == 429 && body is Map) {
        throw Exception(
          body['message'] ??
              'Terlalu banyak permintaan. Coba lagi dalam beberapa menit.',
        );
      }
      if (body is Map) {
        throw Exception(
          body['message'] ??
              body['error'] ??
              'Gagal mengirim permintaan bantuan.',
        );
      }
      throw Exception(
        'Gagal mengirim permintaan bantuan. Periksa koneksi Anda.',
      );
    }
  }

  /// Normalizes Indonesian backend flags to the keys used by _handleLoginResponse.
  static Map<String, dynamic> _normalizeFlags(dynamic data) {
    final responseData = Map<String, dynamic>.from(data);
    if (responseData['pilih_sekolah'] == true) {
      responseData['needsSchoolSelection'] = true;
    }
    if (responseData['pilih_role'] == true) {
      responseData['needsRoleSelection'] = true;
    }
    return responseData;
  }
}
