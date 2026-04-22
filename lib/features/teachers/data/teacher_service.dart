/// api_teacher_services.dart - Facade for teacher management operations.
/// Like Laravel's TeacherController / Vue's teacher store module.
///
/// Delegates to helper classes for CRUD, pagination, subjects, and imports.
/// Centralized cache invalidation. Access via `getIt<ApiTeacherService>()`.
library;

import 'dart:io';

import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/features/teachers/data/helpers/teacher_crud_helper.dart';
import 'package:manajemensekolah/features/teachers/data/helpers/teacher_subject_helper.dart';
import 'package:manajemensekolah/features/teachers/data/helpers/teacher_import_helper.dart';
import 'package:manajemensekolah/features/teachers/data/helpers/teacher_pagination_helper.dart';

/// Service facade for teacher management with helper delegation.
/// All methods are instance methods; access via `getIt<ApiTeacherService>()`.
/// Handles cache invalidation across all operations.
class ApiTeacherService {
  // ========== Pagination & Statistics ==========

  /// Fetches teachers with pagination, filters, and local caching.
  /// Like `Teacher::filter($request)->paginate()` in Laravel.
  /// Supports classId, gender, employmentStatus, teachingClassId,
  /// search, academicYearId, teacherId filters.
  Future<Map<String, dynamic>> getTeachersPaginated({
    int page = 1,
    int limit = 10,
    String? classId,
    String? gender,
    String? employmentStatus,
    String? teachingClassId,
    String? search,
    String? academicYearId,
    String? teacherId,
    bool useCache = true,
  }) => TeacherPaginationHelper.getTeachersPaginated(
    page: page,
    limit: limit,
    classId: classId,
    gender: gender,
    employmentStatus: employmentStatus,
    teachingClassId: teachingClassId,
    search: search,
    academicYearId: academicYearId,
    teacherId: teacherId,
    useCache: useCache,
  );

  /// Fetches aggregated teacher statistics.
  /// Like a Laravel aggregate query endpoint.
  Future<Map<String, dynamic>> getTeacherStats({
    String? gender,
    String? employmentStatus,
    String? name,
    String? employeeNumber,
    String? academicYearId,
  }) => TeacherPaginationHelper.getTeacherStats(
    gender: gender,
    employmentStatus: employmentStatus,
    name: name,
    employeeNumber: employeeNumber,
    academicYearId: academicYearId,
  );

  // ========== CRUD Operations ==========

  /// Fetches all teachers as a flat list.
  /// Like `Teacher::all()` in Laravel.
  /// Use getTeachersPaginated for new code.
  Future<List<dynamic>> getTeacher() => TeacherCrudHelper.getTeacher();

  /// Fetches a single teacher by ID.
  /// Like `Teacher::findOrFail($id)` in Laravel.
  Future<dynamic> getTeacherById(String id, {String? academicYearId}) =>
      TeacherCrudHelper.getTeacherById(id, academicYearId: academicYearId);

  /// Finds a teacher by their linked user account ID.
  /// Like `Teacher::where('user_id', $userId)->first()`.
  /// Returns null if not found.
  Future<Map<String, dynamic>?> getTeacherByUserId(
    String userId, {
    String? academicYearId,
  }) => TeacherCrudHelper.getTeacherByUserId(
    userId,
    academicYearId: academicYearId,
  );

  /// Fetches filter dropdown options for teacher listings.
  Future<Map<String, dynamic>> getTeacherFilterOptions({
    String? academicYearId,
  }) =>
      TeacherCrudHelper.getTeacherFilterOptions(academicYearId: academicYearId);

  /// Creates a new teacher. Clears cache.
  /// Like `Teacher::create($data)` in Laravel.
  Future<dynamic> addTeacher(Map<String, dynamic> data) async {
    final result = await TeacherCrudHelper.addTeacher(data);
    await _clearTeacherCache();
    return result;
  }

  /// Updates a teacher by ID. Clears cache.
  /// Like `Teacher::find($id)->update()`.
  Future<void> updateTeacher(String id, Map<String, dynamic> data) async {
    await TeacherCrudHelper.updateTeacher(id, data);
    await _clearTeacherCache();
  }

  /// Deletes a teacher by ID. Clears cache.
  /// Like `Teacher::find($id)->delete()`.
  Future<void> deleteTeacher(String id) async {
    await TeacherCrudHelper.deleteTeacher(id);
    await _clearTeacherCache();
  }

  // ========== Subject Assignment ==========

  /// Fetches subjects assigned to a teacher.
  /// Like `$teacher->subjects()->get()` in Laravel.
  Future<List<dynamic>> getSubjectByTeacher(
    String teacherId, {
    String? classId,
  }) => TeacherSubjectHelper.getSubjectByTeacher(teacherId, classId: classId);

  /// Fetches classes assigned to a teacher.
  /// Like `$teacher->classes()->get()` in Laravel.
  Future<List<dynamic>> getTeacherClasses(
    String teacherId, {
    String? academicYearId,
  }) => TeacherSubjectHelper.getTeacherClasses(
    teacherId,
    academicYearId: academicYearId,
  );

  /// Fetches subjects by teacher with pagination.
  /// Like `$teacher->subjects()->paginate()` in Laravel.
  Future<Map<String, dynamic>> getSubjectsByTeacherPaginated({
    required String teacherId,
    int page = 1,
    int limit = 10,
    String? search,
    List<String>? subjectIds,
    String? academicYearId,
  }) => TeacherSubjectHelper.getSubjectsByTeacherPaginated(
    teacherId: teacherId,
    page: page,
    limit: limit,
    search: search,
    subjectIds: subjectIds,
    academicYearId: academicYearId,
  );

  /// Assigns a subject to a teacher. Clears cache.
  /// Like `$teacher->subjects()->attach($subjectId)`.
  Future<dynamic> addSubjectToTeacher(
    String teacherId,
    String subjectId,
  ) async {
    final result = await TeacherSubjectHelper.addSubjectToTeacher(
      teacherId,
      subjectId,
    );
    await _clearTeacherCache();
    return result;
  }

  /// Removes a subject from a teacher. Clears cache.
  /// Like `$teacher->subjects()->detach($subjectId)`.
  Future<void> removeSubjectFromTeacher(
    String teacherId,
    String subjectId,
  ) async {
    await TeacherSubjectHelper.removeSubjectFromTeacher(teacherId, subjectId);
    await _clearTeacherCache();
  }

  // ========== Excel Import & Templates ==========

  /// Downloads the teacher Excel import template.
  /// Returns the local file path where template is saved.
  Future<String> downloadTemplate() => TeacherImportHelper.downloadTemplate();

  /// Legacy template download endpoint wrapper.
  /// Deprecated: use downloadTemplate() instead.
  Future<void> downloadTeacherTemplate() =>
      TeacherImportHelper.downloadTeacherTemplate();

  /// Imports teachers from an Excel file. Clears cache.
  /// Like Laravel's `Excel::import()` with Maatwebsite package.
  Future<Map<String, dynamic>> importTeachersFromExcel(File file) async {
    final result = await TeacherImportHelper.importTeachersFromExcel(file);
    await _clearTeacherCache();
    return result;
  }

  // ========== Cache Management ==========

  /// Invalidates all teacher-related cache entries.
  /// Like Laravel's `Cache::tags('teachers')->flush()`.
  Future<void> _clearTeacherCache() async {
    await CacheInvalidationService.onTeacherChanged();
  }
}
