import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:manajemensekolah/main.dart';
import 'package:manajemensekolah/screen/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:3001/api'; // iOS simulator atau web

  // static const String baseUrl = 'https://backendmanajemensekolah2.vercel.app/api';
  // static const String baseUrl = 'https://libra.web.id/apimanajemen';

  // static const String baseUrl = 'http://aieasytech.id/api';
  // static const String baseUrl = 'http://192.168.1.100:3000/api';

  static late final String baseUrl;

  static Future<void> init() async {
    if (kIsWeb) {
      // web pakai localhost
      baseUrl = 'http://127.0.0.1:8000/api';
    } else if (Platform.isAndroid) {
      // pakai IP LAN server
      // PENTING: Ganti IP ini jika Mac Anda pindah jaringan
      // Cek IP Mac dengan: ifconfig | grep "inet " | grep -v 127.0.0.1
      baseUrl = 'http://127.0.0.1:8000/api';
      if (kDebugMode) {
        print('📡 API Base URL (Android): $baseUrl');
        print('💡 Pastikan Android dan Mac di jaringan Wi-Fi yang sama!');
      }
    } else {
      baseUrl = 'http://127.0.0.1:8000/api';
      if (kDebugMode) {
        print('📡 API Base URL (iOS/Other): $baseUrl');
      }
    }
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ GET Error on $endpoint: $e');
      }
      // If it's a network error or critical error, logout user
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        await _handleAuthenticationErrorWithMessage(
          'Connection failed. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('Timeout')) {
        await _handleAuthenticationErrorWithMessage(
          'Request timeout. Please try again.',
        );
      }
      rethrow;
    }
  }

  // Instance method untuk POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ POST Error on $endpoint: $e');
      }
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        await _handleAuthenticationErrorWithMessage(
          'Connection failed. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('Timeout')) {
        await _handleAuthenticationErrorWithMessage(
          'Request timeout. Please try again.',
        );
      }
      rethrow;
    }
  }

  // Instance method untuk PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ PUT Error on $endpoint: $e');
      }
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        await _handleAuthenticationErrorWithMessage(
          'Connection failed. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('Timeout')) {
        await _handleAuthenticationErrorWithMessage(
          'Request timeout. Please try again.',
        );
      }
      rethrow;
    }
  }

  // Dalam ApiService class
  Future<List<dynamic>> getNilaiByMataPelajaran(
    String mataPelajaranId, {
    String? academicYearId,
  }) async {
    try {
      // Use backend filtering
      String url = '/grades?subject_id=$mataPelajaranId';
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

  // Instance method untuk DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ DELETE Error on $endpoint: $e');
      }
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        await _handleAuthenticationErrorWithMessage(
          'Connection failed. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('Timeout')) {
        await _handleAuthenticationErrorWithMessage(
          'Request timeout. Please try again.',
        );
      }
      rethrow;
    }
  }

  // File Download
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

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Expose headers for other services
  static Future<Map<String, String>> getHeaders() => _getHeaders();

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
          if (kDebugMode)
            print('✅ Injected X-School-ID: ${headers['X-School-ID']}');
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
          _handleAuthenticationErrorWithMessage(
            'Access forbidden. Please login again.',
          );
        }
        // For 500+ errors, just throw the exception without logging out
        // The UI will handle displaying the error to the user

        throw Exception(errorMessage);
      }
    } catch (e) {
      // Handle JSON decode errors
      if (e is FormatException) {
        _handleAuthenticationErrorWithMessage(
          'Invalid server response. Please try again.',
        );
      }
      rethrow;
    }
  }

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

  // Public method untuk logout dengan custom message
  static Future<void> logoutWithMessage(String message) async {
    await _handleAuthenticationErrorWithMessage(message);
  }

  Future<List<dynamic>> getData(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        // Add authorization header if needed
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load data');
    }
  }

  // Login dengan sekolah
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

  static Future<Map<String, dynamic>> googleLogin({
    required String email,
    String? displayName,
    String? photoUrl,
    String? googleToken,
  }) async {
    try {
      // Backend expects 'google_id', so we map 'googleToken' to it
      final Map<String, dynamic> body = {
        'email': email,
        'name': displayName, // Backend uses 'name', not 'displayName'
        'avatar': photoUrl, // Backend uses 'avatar', not 'photoUrl'
        'google_id': googleToken, // Backend uses 'google_id', not 'googleToken'
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

  static Future<List<dynamic>> getUserRoles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/roles'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result['available_roles'] is List ? result['available_roles'] : [];
  }

  // Switch role reuse switchSchool logic
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

  // Get sekolah yang bisa diakses user
  static Future<List<dynamic>> getUserSchools() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/schools'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Switch sekolah
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

  // Nilai
  static Future<List<dynamic>> getNilai({
    String? siswaId,
    String? guruId,
    String? mataPelajaranId,
    String? jenis,
  }) async {
    String url = '$baseUrl/grade?';
    if (siswaId != null) url += 'student_id=$siswaId&';
    if (guruId != null) url += 'teacher_id=$guruId&';
    if (mataPelajaranId != null) url += 'subject_id=$mataPelajaranId&';
    if (jenis != null) url += 'grade_type=$jenis&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<dynamic> tambahNilai(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/grade'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // RPP methods
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      request.headers['Authorization'] = 'Bearer $token';

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

  // Absensi
  static Future<List<dynamic>> getAbsensi({
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? academicYearId,
  }) async {
    String url = '$baseUrl/attendance?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (date != null) url += 'date=$date&';
    if (subjectId != null) url += 'subject_id=$subjectId&';
    if (studentId != null) url += 'student_id=$studentId&';
    if (classId != null) url += 'class_id=$classId&';
    if (academicYearId != null) url += 'academic_year_id=$academicYearId&';

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
  }) async {
    String query =
        '/attendance?teacher_id=$teacherId&subject_id=$subjectId&date=$date';
    if (classId != null && classId.isNotEmpty) {
      query += '&class_id=$classId';
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

      final uri = Uri.parse(
        '$baseUrl/attendance',
      ).replace(queryParameters: params);
      final response = await http.get(uri, headers: await _getHeaders());
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

  static Future<List<dynamic>> getAbsensiSummary({String? guruId}) async {
    String url = '$baseUrl/attendance-summary?';
    if (guruId != null) url += 'teacher_id=$guruId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
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
        params['subject_id'] = mataPelajaranId;
      }
      if (classId != null && classId.isNotEmpty) params['class_id'] = classId;
      if (tanggal != null && tanggal.isNotEmpty) params['date'] = tanggal;
      if (tanggalStart != null && tanggalStart.isNotEmpty) {
        params['start_date'] = tanggalStart;
      }
      if (tanggalEnd != null && tanggalEnd.isNotEmpty) {
        params['end_date'] = tanggalEnd;
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

  static Future<dynamic> tambahAbsensi(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Dalam class ApiService di api_services.dart
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

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

  // Check server health
  static Future<Map<String, dynamic>> checkHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    return _handleResponse(response);
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

  // Send FCM token to backend
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
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

  // Delete FCM token from backend
  static Future<Map<String, dynamic>> deleteFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        throw Exception('No auth token found');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/fcm/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
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
}
