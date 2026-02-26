import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';

class ApiGradeRecapService {
  static String get baseUrl => ApiService.baseUrl;

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      print('ApiGradeRecapService Error Body: ${response.body}');
      throw Exception('Request failed with status: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getGradeRecaps({
    required String classId,
    required String subjectId,
    required String academicYearId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/grade-recaps?class_id=$classId&subject_id=$subjectId&academic_year_id=$academicYearId',
      ),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);
    return result['data'] ?? [];
  }

  static Future<dynamic> saveGradeRecap(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/grade-recaps'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> batchSaveGradeRecap(
    List<Map<String, dynamic>> recaps,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/grade-recaps/batch'),
      headers: await ApiService.getHeaders(),
      body: json.encode({'recaps': recaps}),
    );

    return _handleResponse(response);
  }
}
