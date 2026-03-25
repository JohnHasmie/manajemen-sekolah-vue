/// api_grade_recap_services.dart - Manages grade recaps (rekap nilai) for classes.
/// Like Laravel's GradeRecapController / Vue's gradeRecap store module.
///
/// Grade recaps aggregate student scores per class, subject, and academic year.
/// Supports fetching, saving individual recaps, and batch-saving multiple at once.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';

/// Service for grade recap (rekap nilai) API calls.
/// Like a Laravel controller with index, store, and batch-store actions.
class ApiGradeRecapService {
  /// Fetches grade recaps filtered by class, subject, and academic year.
  /// Like `GradeRecap::where(...)->get()` in Laravel.
  /// Returns a list of recap records from the 'data' key.
  Future<List<dynamic>> getGradeRecaps({
    required String classId,
    required String subjectId,
    required String academicYearId,
  }) async {
    final response = await dioClient.get(
      '/grade-recaps',
      queryParameters: {
        'class_id': classId,
        'subject_id': subjectId,
        'academic_year_id': academicYearId,
      },
    );

    final result = response.data;
    return result['data'] ?? [];
  }

  /// Saves a single grade recap entry.
  /// Like `GradeRecap::create($data)` in Laravel.
  Future<dynamic> saveGradeRecap(Map<String, dynamic> data) async {
    final response = await dioClient.post('/grade-recaps', data: data);
    return response.data;
  }

  /// Batch-saves multiple grade recap entries in a single request.
  /// Like a Laravel batch insert: `GradeRecap::insert($recaps)`.
  /// More efficient than calling [saveGradeRecap] in a loop.
  Future<dynamic> batchSaveGradeRecap(
    List<Map<String, dynamic>> recaps,
  ) async {
    final response = await dioClient.post(
      '/grade-recaps/batch',
      data: {'recaps': recaps},
    );
    return response.data;
  }
}
