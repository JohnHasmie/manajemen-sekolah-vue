/// api_raport_services.dart - Manages student report cards (raport/rapor).
/// Like Laravel's RaportController / Vue's raport store module.
///
/// Handles fetching raport lists, initial data for raport creation,
/// raport detail views, and saving raport data.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';

/// Service for raport (report card) API calls.
/// Like a Laravel Resource Controller with show, store, and custom initial-data actions.
/// In Vue terms, this is a store module that handles all raport-related API state.
class ApiReportCardService {
  /// Fetches homeroom classes with raport completion stats.
  static Future<List<dynamic>> getTeacherRaportSummary({
    required String teacherId,
    String? academicYearId,
    String? semesterId,
  }) async {
    final params = <String, dynamic>{'teacher_id': teacherId};
    if (academicYearId != null) params['academic_year_id'] = academicYearId;
    if (semesterId != null) params['semester_id'] = semesterId;

    final response = await dioClient.get('/raports/teacher-summary', queryParameters: params);
    final result = response.data;
    if (result is Map && result['data'] is List) return result['data'];
    if (result is List) return result;
    return [];
  }

  /// Fetches a list of raports filtered by class, academic year, and semester.
  /// Like `Raport::where(...)->get()` in Laravel.
  /// Returns the 'data' array, or empty list if unsuccessful.
  Future<List<dynamic>> getRaports({
    required String classId,
    required String academicYearId,
    required String semesterId,
  }) async {
    final response = await dioClient.get(
      '/raports',
      queryParameters: {
        'class_id': classId,
        'academic_year_id': academicYearId,
        'semester_id': semesterId,
      },
    );

    if (response.data != null && response.data['success'] == true) {
      return response.data['data'] as List<dynamic>;
    }
    return [];
  }

  /// Fetches initial data needed to populate a new raport form.
  /// Like a Laravel controller method that returns form defaults and relationships.
  /// Similar to a Vue `mounted()` hook that loads prerequisite data.
  Future<Map<String, dynamic>?> getInitialData({
    required String studentClassId,
    required String academicYearId,
    required String semesterId,
  }) async {
    final response = await dioClient.get(
      '/raport/initial-data',
      queryParameters: {
        'student_class_id': studentClassId,
        'academic_year_id': academicYearId,
        'semester_id': semesterId,
      },
    );

    if (response.data != null &&
        response.data['success'] == true &&
        response.data['data'] != null) {
      return response.data['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Fetches the full detail of an existing raport for viewing/editing.
  /// Like `Raport::with('grades', 'student')->findOrFail($id)` in Laravel.
  /// Returns null if no raport exists for the given parameters.
  Future<Map<String, dynamic>?> getRaportDetail({
    required String studentClassId,
    required String academicYearId,
    required String semesterId,
  }) async {
    // Note: The backend route is /raport/show but we use show method in controller
    final response = await dioClient.get(
      '/raport/show',
      queryParameters: {
        'student_class_id': studentClassId,
        'academic_year_id': academicYearId,
        'semester_id': semesterId,
      },
    );

    if (response.data != null &&
        response.data['success'] == true &&
        response.data['data'] != null) {
      return response.data['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Creates or updates a raport record.
  /// Like `Raport::updateOrCreate($data)` in Laravel.
  /// Returns the saved raport data, or null if unsuccessful.
  Future<Map<String, dynamic>?> saveReportCard(
    Map<String, dynamic> data,
  ) async {
    final response = await dioClient.post('/raport', data: data);

    if (response.data != null && response.data['success'] == true) {
      return response.data['data'] as Map<String, dynamic>;
    }
    return null;
  }
}
