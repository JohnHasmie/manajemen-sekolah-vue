import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiAcademicServices {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _handleResponse(http.Response response) {
    var responseBody;
    try {
      responseBody = json.decode(response.body);
    } catch (e) {
      responseBody = {'error': 'Failed to parse response'};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      throw Exception(
        responseBody['error'] ??
            'Request failed with status: ${response.statusCode}',
      );
    }
  }

  // Get All Academic Years
  static Future<List<dynamic>> getAcademicYears() async {
    final response = await http.get(
      Uri.parse('$baseUrl/academic-years'),
      headers: await _getHeaders(),
    );
    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Get Active Academic Year
  static Future<Map<String, dynamic>?> getActiveAcademicYear() async {
    final response = await http.get(
      Uri.parse('$baseUrl/academic-year/active'),
      headers: await _getHeaders(),
    );

    // Handle 204 or empty
    if (response.statusCode == 204 || response.body.isEmpty) return null;

    final result = _handleResponse(response);
    return result is Map<String, dynamic> ? result : null;
  }

  // Create Academic Year
  static Future<dynamic> createAcademicYear(
    String year, {
    bool current = false,
    String status = 'inactive',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/academic-years'),
      headers: await _getHeaders(),
      body: json.encode({'year': year, 'current': current, 'status': status}),
    );
    return _handleResponse(response);
  }

  // Promotion: Promote Students
  static Future<dynamic> promoteStudents({
    required List<String> studentIds,
    required String targetClassId,
    required String academicYearId,
    String status = 'promoted',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/promotion/promote'),
      headers: await _getHeaders(),
      body: json.encode({
        'student_ids': studentIds,
        'target_class_id': targetClassId,
        'academic_year_id': academicYearId,
        'status': status,
      }),
    );
    return _handleResponse(response);
  }
}
