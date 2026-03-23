/// api_academic_services.dart - Manages academic year CRUD and student promotion.
/// Like Laravel's AcademicYearService / Vue's academicYear store module.
///
/// Handles operations related to academic years (tahun ajaran) such as
/// creating, activating, and managing student promotions between years.
/// All methods are static -- no instance needed, similar to a Laravel facade.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/core/services/api_service.dart';

/// Service class for academic year management API calls.
/// Like Laravel's `AcademicYearController` -- each static method maps to
/// a single controller action / API endpoint.
///
/// Uses [ApiService.baseUrl] and [ApiService.getHeaders] for auth tokens,
/// similar to how Laravel services use dependency injection for HTTP clients.
class ApiAcademicServices {
  /// Base URL inherited from the central ApiService.
  /// Like accessing `config('app.url')` in Laravel.
  static String get baseUrl => ApiService.baseUrl;

  /// Retrieves auth headers (Bearer token + X-School-ID).
  /// Like Laravel's `Http::withToken()` or an Axios interceptor in Vue.
  static Future<Map<String, String>> _getHeaders() => ApiService.getHeaders();

  /// Decodes the HTTP response and throws on non-2xx status.
  /// Like a shared response handler in a Laravel Http macro or
  /// an Axios response interceptor in Vue.
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

  /// Fetches all academic years from the backend.
  /// Like `AcademicYear::all()` in Laravel or a Vuex `fetchAcademicYears` action.
  /// Returns a list of academic year maps, or an empty list on unexpected format.
  static Future<List<dynamic>> getAcademicYears() async {
    final response = await http.get(
      Uri.parse('$baseUrl/academic-years'),
      headers: await _getHeaders(),
    );
    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  /// Fetches the currently active academic year.
  /// Like `AcademicYear::where('status', 'active')->first()` in Laravel.
  /// Returns null if no active year (HTTP 204 or empty body).
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

  /// Creates a new academic year record.
  /// Like `AcademicYear::create()` in Laravel or dispatching a Vuex `createAcademicYear` action.
  /// [year] - The academic year label (e.g. "2024/2025").
  /// [current] - Whether this should be the current year.
  /// [status] - 'active' or 'inactive'.
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

  /// Promotes a batch of students to a target class for a given academic year.
  /// Like a Laravel job/action that bulk-updates student class assignments.
  /// Similar to a Vuex action that dispatches a batch mutation.
  /// [studentIds] - List of student UUIDs to promote.
  /// [targetClassId] - The class they are moving into.
  /// [academicYearId] - The academic year for the promotion.
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

  /// Updates the status of an academic year (e.g. 'active' / 'inactive').
  /// Like `AcademicYear::find($id)->update(['status' => $status])` in Laravel.
  static Future<dynamic> updateAcademicYearStatus(
    String id,
    String status,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/academic-years/$id/status'),
      headers: await _getHeaders(),
      body: json.encode({'status': status}),
    );
    return _handleResponse(response);
  }

  /// Sets a specific academic year as the "current" one across the system.
  /// Like calling a Laravel `SetCurrentAcademicYear` action that unsets
  /// all others and marks this one as current.
  static Future<dynamic> setCurrentAcademicYear(String id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/academic-years/$id/set-current'),
      headers: await _getHeaders(),
    );
    return _handleResponse(response);
  }
}
