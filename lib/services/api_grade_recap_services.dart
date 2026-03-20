/// api_grade_recap_services.dart - Manages grade recaps (rekap nilai) for classes.
/// Like Laravel's GradeRecapController / Vue's gradeRecap store module.
///
/// Grade recaps aggregate student scores per class, subject, and academic year.
/// Supports fetching, saving individual recaps, and batch-saving multiple at once.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';

/// Service for grade recap (rekap nilai) API calls.
/// Like a Laravel controller with index, store, and batch-store actions.
/// All methods are static -- no instance needed.
class ApiGradeRecapService {
  /// Base URL from central config.
  static String get baseUrl => ApiService.baseUrl;

  /// Parses JSON response and throws on non-2xx status.
  /// Like an Axios interceptor in Vue.
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      print('ApiGradeRecapService Error Body: ${response.body}');
      throw Exception('Request failed with status: ${response.statusCode}');
    }
  }

  /// Fetches grade recaps filtered by class, subject, and academic year.
  /// Like `GradeRecap::where(...)->get()` in Laravel.
  /// Returns a list of recap records from the 'data' key.
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

  /// Saves a single grade recap entry.
  /// Like `GradeRecap::create($data)` in Laravel.
  static Future<dynamic> saveGradeRecap(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/grade-recaps'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  /// Batch-saves multiple grade recap entries in a single request.
  /// Like a Laravel batch insert: `GradeRecap::insert($recaps)`.
  /// More efficient than calling [saveGradeRecap] in a loop.
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
