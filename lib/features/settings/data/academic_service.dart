/// api_academic_services.dart - Manages academic year CRUD and student
/// promotion.
/// Like Laravel's AcademicYearService / Vue's academicYear store module.
///
/// Handles operations related to academic years (tahun ajaran) such as
/// creating, activating, and managing student promotions between years.
/// Registered as a singleton via get_it, similar to a Laravel facade.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';

/// Service class for academic year management API calls.
/// Like Laravel's `AcademicYearController` -- each method maps to
/// a single controller action / API endpoint.
///
/// Uses [ApiService.baseUrl] and [ApiService.getHeaders] for auth tokens,
/// similar to how Laravel services use dependency injection for HTTP clients.
class ApiAcademicServices {
  /// Fetches all academic years from the backend.
  /// Like `AcademicYear::all()` in Laravel or a Vuex `fetchAcademicYears`
  /// action.
  /// Returns a list of academic year maps, or an empty list on unexpected
  /// format.
  Future<List<dynamic>> getAcademicYears() async {
    final response = await dioClient.get('/academic-years');
    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches the currently active academic year.
  /// Like `AcademicYear::where('status', 'active')->first()` in Laravel.
  /// Returns null if no active year (HTTP 204 or empty body).
  Future<Map<String, dynamic>?> getActiveAcademicYear() async {
    final response = await dioClient.get('/academic-year/active');

    // Handle 204 or empty
    if (response.statusCode == 204 ||
        response.data == null ||
        response.data == '') {
      return null;
    }

    final result = response.data;
    return result is Map<String, dynamic> ? result : null;
  }

  /// One-shot summary powering the Kelola Tahun Ajaran KPI strip.
  /// Returns `{ total, current_count, active_count, inactive_count,
  /// archived_count }`. Backed by GET /academic-years/kpi-summary
  /// which counts each bucket in a single GROUP BY query.
  Future<Map<String, dynamic>> getAcademicYearKpiSummary() async {
    final response = await dioClient.get('/academic-years/kpi-summary');
    final result = response.data;
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  /// Creates a new academic year record.
  /// Like `AcademicYear::create()` in Laravel or dispatching a Vuex
  /// `createAcademicYear` action.
  /// [year] - The academic year label (e.g. "2024/2025").
  /// [semester] - 'ganjil' or 'genap' (nullable for legacy callers).
  /// [current] - Whether this should be the current year.
  /// [status] - 'active' or 'inactive'.
  Future<dynamic> createAcademicYear(
    String year, {
    String? semester,
    bool current = false,
    String status = 'inactive',
    String? startDate,
    String? endDate,
  }) async {
    final response = await dioClient.post(
      '/academic-years',
      data: {
        'year': year,
        if (semester != null) 'semester': semester,
        'current': current,
        'status': status,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    return response.data;
  }

  /// Updates an academic year record.
  Future<dynamic> updateAcademicYear(
    String id, {
    String? year,
    String? semester,
    bool? current,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    final response = await dioClient.put(
      '/academic-years/$id',
      data: {
        if (year != null) 'year': year,
        if (semester != null) 'semester': semester,
        if (current != null) 'current': current,
        if (status != null) 'status': status,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    return response.data;
  }

  /// Moves an academic year to `status = 'archived'`. Backend refuses
  /// if the year is the canonical `current` — admin must transfer
  /// current first. Errors surface as Dio 422 with a friendly message.
  Future<dynamic> archiveAcademicYear(String id) async {
    final response = await dioClient.post('/academic-years/$id/archive');
    return response.data;
  }

  /// Reverse of [archiveAcademicYear]. Brings the year back to
  /// `status = 'inactive'` so it can be edited or re-activated.
  Future<dynamic> unarchiveAcademicYear(String id) async {
    final response = await dioClient.post('/academic-years/$id/unarchive');
    return response.data;
  }

  /// Deletes an academic year record.
  Future<dynamic> deleteAcademicYear(String id) async {
    final response = await dioClient.delete('/academic-years/$id');
    return response.data;
  }

  /// Promotes a batch of students to a target class for a given academic year.
  /// Like a Laravel job/action that bulk-updates student class assignments.
  /// Similar to a Vuex action that dispatches a batch mutation.
  /// [studentIds] - List of student UUIDs to promote.
  /// [targetClassId] - The class they are moving into.
  /// [academicYearId] - The academic year for the promotion.
  Future<dynamic> promoteStudents({
    required List<String> studentIds,
    required String targetClassId,
    required String academicYearId,
    String status = 'promoted',
  }) async {
    final response = await dioClient.post(
      '/promotion/promote',
      data: {
        'student_ids': studentIds,
        'target_class_id': targetClassId,
        'academic_year_id': academicYearId,
        'status': status,
      },
    );
    return response.data;
  }

  /// Updates the status of an academic year (e.g. 'active' / 'inactive').
  /// Like `AcademicYear::find($id)->update(['status' => $status])` in Laravel.
  Future<dynamic> updateAcademicYearStatus(String id, String status) async {
    final response = await dioClient.put(
      '/academic-years/$id/status',
      data: {'status': status},
    );
    return response.data;
  }

  /// Sets a specific academic year as the "current" one across the system.
  /// Like calling a Laravel `SetCurrentAcademicYear` action that unsets
  /// all others and marks this one as current.
  Future<dynamic> setCurrentAcademicYear(String id) async {
    final response = await dioClient.put('/academic-years/$id/set-current');
    return response.data;
  }
}
