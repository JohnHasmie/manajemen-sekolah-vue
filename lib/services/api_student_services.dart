import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiStudentService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  static dynamic _handleResponse(http.Response response) {
    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      String? errorMessage = responseBody['error'] ?? responseBody['message'];

      if (errorMessage == null && responseBody['errors'] != null) {
        final errors = responseBody['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstKey = errors.keys.first;
          final firstError = errors[firstKey];
          if (firstError is List && firstError.isNotEmpty) {
            errorMessage = firstError.first;
          } else {
            errorMessage = firstError.toString();
          }
        }
      }

      errorMessage ??= 'Request failed with status: ${response.statusCode}';

      if (response.statusCode == 401) {
        _handleAuthenticationError();
      }

      throw Exception(errorMessage);
    }
  }

  static void _handleAuthenticationError() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); // Clear invalid token
    // You can also navigate to login page here
    // Navigator.of(context).pushReplacementNamed('/login');
  }

  static Future<Map<String, dynamic>> importStudentsFromExcel(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/students/import'),
      );

      // Add headers
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      request.headers['Authorization'] = 'Bearer $token';

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (kDebugMode) {
        print('Import Response Status: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('Import Response Body: $responseBody');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = json.decode(responseBody);

        // Check for specific import result structure
        if (body is Map && body['results'] != null) {
          final results = body['results'];
          if (results['failed'] is int && results['failed'] > 0) {
            // Handle failures
            List<dynamic> errors = results['errors'] ?? [];
            String errorMsg = errors.isNotEmpty
                ? errors.first.toString()
                : 'Import failed';

            // Optional: Clean up "Row X: " prefix if desired, but user likely just wants the error.
            // Let's try to strip "Row \d+: " to match user expectation exactly if possible,
            // but keeping it is safer for context.
            // User said: "seharusbya keluar Data siswa dengan nama 'Indri' sudah ada"
            // Backend sends: "Row 2: Data siswa dengan nama 'Indri' sudah ada."
            // I will try to remove the prefix for cleaner UI.
            final rowPrefixRegex = RegExp(r'^Row \d+: ');
            if (errorMsg.startsWith(rowPrefixRegex)) {
              errorMsg = errorMsg.replaceFirst(rowPrefixRegex, '');
            }

            throw Exception(errorMsg);
          }
        }

        return body;
      } else {
        String msg = 'Import failed with status: ${response.statusCode}';
        try {
          final body = json.decode(responseBody);
          if (body is Map) {
            if (body['message'] != null) {
              msg = body['message'];
            } else if (body['error'] != null) {
              msg = body['error'];
            }
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Import error details: $e');
      }
      throw Exception('Import error: $e');
    }
  }

  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/template'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory?.path}/template_import_siswa.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        if (kDebugMode) {
          print('Template downloaded to: $filePath');
        }
        return filePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Download template error: $e');
      }
      throw Exception('Failed to download template: $e');
    }
  }

  static Future<Directory?> getExternalStorageDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getParentUser(String studentId) async {
    try {
      final response = await ApiService().get('users?student_id=$studentId');
      if (response != null && response is List && response.isNotEmpty) {
        return response.first;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting parent user: $e');
      }
      return null;
    }
  }

  static Future<List<dynamic>> getStudent({String? academicYearId}) async {
    String url = '$baseUrl/student';
    if (academicYearId != null) {
      url += '?academic_year_id=$academicYearId';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);

    if (result is Map<String, dynamic>) {
      return (result['data'] as List?) ?? [];
    }

    return result is List ? result : [];
  }

  static Future<dynamic> getStudentById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/student/$id'),
      headers: await ApiService.getHeaders(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getStudentFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/filter-options'),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      return {
        'success': false,
        'data': {
          'grade_levels': [],
          'kelas': [],
          'gender_options': [
            {'value': 'L', 'label': 'Laki-laki'},
            {'value': 'P', 'label': 'Perempuan'},
          ],
          'status_options': [
            {'value': 'active', 'label': 'Aktif'},
            {'value': 'inactive', 'label': 'Tidak Aktif'},
          ],
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting filter options: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getStudentPaginated({
    int page = 1,
    int limit = 10,
    String? classId,
    String? gradeLevel,
    String? gender,
    String? search,
    String? academicYearId,
    String? guardianName,
  }) async {
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (gender != null && gender.isNotEmpty) {
      queryParams['gender'] = gender;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (guardianName != null && guardianName.isNotEmpty) {
      queryParams['guardian_name'] = guardianName;
    }

    String queryString = Uri(queryParameters: queryParams).query;

    final response = await http.get(
      Uri.parse('$baseUrl/student?$queryString'),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'data': result is List ? result : [],
      'pagination': {
        'total_items': result is List ? result.length : 0,
        'total_pages': 1,
        'current_page': 1,
        'per_page': limit,
        'has_next_page': false,
        'has_prev_page': false,
      },
    };
  }

  static Future<dynamic> addStudent(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/student'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<void> updateStudent(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/student/$id'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );
    _handleResponse(response);
  }

  static Future<void> deleteStudent(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/student/$id'),
      headers: await ApiService.getHeaders(),
    );
    _handleResponse(response);
  }

  static Future<List<dynamic>> getStudentByClass(String classId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/class/$classId'),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting students by class: $e');
      }
      return [];
    }
  }

  static Future<List<String>> getGuardians(String query) async {
    try {
      final response = await ApiService().get(
        '/student/guardians?search=${Uri.encodeComponent(query)}',
      );
      if (response['success'] == true && response['data'] != null) {
        return List<String>.from(response['data']);
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Error loading guardians: $e');
      return [];
    }
  }
}
