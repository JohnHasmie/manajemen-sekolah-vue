import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

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

      if (responseData['pilih_sekolah'] == true) {
        return Map<String, dynamic>.from(responseData);
      }
      if (responseData['pilih_role'] == true) {
        return Map<String, dynamic>.from(responseData);
      }
      if (responseData['require_otp'] == true ||
          responseData['otp_debug'] != null ||
          responseData['message'] == 'OTP sent to email') {
        return Map<String, dynamic>.from(responseData);
      }

      if (responseData['token'] == null)
        throw Exception('Server tidak mengembalikan token');
      if (responseData['user'] == null)
        throw Exception('Server tidak mengembalikan data user');

      return Map<String, dynamic>.from(responseData);
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
      return Map<String, dynamic>.from(response.data);
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
  }) async {
    try {
      final Map<String, dynamic> body = {
        'email': email,
        'name': displayName,
        'avatar': photoUrl,
        'id_token': idToken,
      };

      final response = await dioClient.post(
        ApiEndpoints.googleLogin,
        data: body,
      );
      return Map<String, dynamic>.from(response.data);
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

    final user = json.decode(userJson);
    final schoolId = user['school_id'] ?? user['sekolah_id'];

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
    return Map<String, dynamic>.from(response.data);
  }
}
