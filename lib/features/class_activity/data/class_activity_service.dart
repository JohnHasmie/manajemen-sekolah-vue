/// api_class_activity_services.dart - Manages class activities (kegiatan
/// kelas) CRUD. Like Laravel's ClassActivityController / Vue's classActivity
/// store module.
///
/// Class activities represent daily teaching events: what was taught, by
/// whom, in which class, for which subject. Teachers create them;
/// students/parents view them. Supports paginated listing, filtering, export,
/// read-tracking, and schedule lookups.
library;

import 'package:dio/dio.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_crud_helper.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_query_helper.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_metadata_helper.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_export_helper.dart';

/// Service for class activity (kegiatan kelas) API interactions.
/// Like a Laravel Resource Controller with additional custom actions
/// (export, unread-count, mark-read). Delegates to focused helpers.
///
/// In Vue terms, this is like a Pinia/Vuex store actions file that handles
/// all API calls related to class activities.
class ApiClassActivityService {
  static final _crudHelper = CrudHelper();
  static final _queryHelper = QueryHelper();
  static final _metadataHelper = MetadataHelper();
  static final _exportHelper = ExportHelper();

  /// Fetches a single class activity by ID with full detail fields.
  /// Like `GET /class-activity/{id}` in Laravel — returns the full record
  /// including description, material_title, student_count, and
  /// submission_count that the list summary endpoint omits.
  Future<Map<String, dynamic>> getActivity(String id) =>
      _crudHelper.getActivity(id);

  /// Creates a new class activity record.
  /// Like `ClassActivity::create($data)` in Laravel or a Vuex `store`
  /// action.
  /// [data] - Activity fields (teacher_id, class_id, subject_id, date,
  /// description, etc.).
  Future<dynamic> createActivity(Map<String, dynamic> data) =>
      _crudHelper.createActivity(data);

  /// Updates an existing class activity by ID.
  /// Like `ClassActivity::find($id)->update($data)` in Laravel.
  Future<dynamic> updateActivity(String id, Map<String, dynamic> data) =>
      _crudHelper.updateActivity(id, data);

  /// Deletes a class activity by ID.
  /// Like `ClassActivity::find($id)->delete()` in Laravel.
  Future<dynamic> deleteActivity(String id) => _crudHelper.deleteActivity(id);

  /// Returns audience + per-student submission rows for an activity.
  /// Used by the Catat Submit picker sheet on the detail screen.
  Future<List<Map<String, dynamic>>> getSubmissions(String activityId) =>
      _crudHelper.getSubmissions(activityId);

  /// Bulk-upserts per-student submission status for an activity.
  /// Payload: list of { student_id, status, note?, score? }.
  Future<void> saveSubmissions(
    String activityId,
    List<Map<String, dynamic>> rows,
  ) => _crudHelper.saveSubmissions(activityId, rows);

  /// Fetches class activities with server-side pagination and multiple
  /// filters. Like `ClassActivity::filter($request)->paginate()` in Laravel.
  /// Similar to a Vuex action that calls the paginated index endpoint.
  /// Returns a Map with 'data' (list) and 'pagination' metadata.
  Future<Map<String, dynamic>> getClassActivityPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? classId,
    String? subjectId,
    String? target,
    String? date,
    String? search,
    String? chapterId,
    String? subChapterId,
    String? academicYearId,
    String? startDate,
    String? endDate,
  }) => _queryHelper.getClassActivityPaginated(
    page: page,
    limit: limit,
    teacherId: teacherId,
    classId: classId,
    subjectId: subjectId,
    target: target,
    date: date,
    search: search,
    chapterId: chapterId,
    subChapterId: subChapterId,
    academicYearId: academicYearId,
    startDate: startDate,
    endDate: endDate,
  );

  /// Fetches activities created by a specific teacher.
  /// Like `ClassActivity::where('teacher_id', $teacherId)->get()` in Laravel.
  /// [teacherId] - The teacher's UUID.
  Future<List<dynamic>> getActivityByTeacher(String teacherId) =>
      _queryHelper.getActivityByTeacher(teacherId);

  /// Fetches activities for a specific class, optionally filtered by student
  /// and academic year.
  /// Used by students/parents to see what happened in their class.
  /// Like `ClassActivity::where('class_id', $classId)->get()` in Laravel.
  Future<List<dynamic>> getActivityByClass(
    String classId, {
    String? studentId,
    String? academicYearId,
  }) => _queryHelper.getActivityByClass(
    classId,
    studentId: studentId,
    academicYearId: academicYearId,
  );

  /// Fetches activities grouped by class+subject with pagination.
  /// When [includeContext] is true, also returns homeroom_classes,
  /// schedules, and class_list in one call (cached for 5 min).
  /// Returns {'data': [...], 'pagination': {...}} or
  /// {'data': [], 'pagination': null}.
  Future<Map<String, dynamic>> getTeacherActivitySummary({
    String? teacherId,
    String? academicYearId,
    String? classId,
    String? subjectId,
    String? search,
    String? dateFilter,
    int page = 1,
    int perPage = 20,
    bool includeContext = false,
    String? view,
  }) => _metadataHelper.getTeacherActivitySummary(
    teacherId: teacherId,
    academicYearId: academicYearId,
    classId: classId,
    subjectId: subjectId,
    search: search,
    dateFilter: dateFilter,
    page: page,
    perPage: perPage,
    includeContext: includeContext,
    view: view,
  );

  /// Clears cached teacher activity summary.
  static Future<void> clearSummaryCache(String teacherId) =>
      MetadataHelper.clearSummaryCache(teacherId);

  /// Fetches the teacher's schedule to populate form dropdowns.
  /// Like loading relationship data for a Laravel form.
  /// Used to show which class/subject/day options are available when
  /// creating activities.
  Future<List<dynamic>> getScheduleForForm({
    required String teacherId,
    String? day,
    String? academicYear,
  }) => _metadataHelper.getScheduleForForm(
    teacherId: teacherId,
    day: day,
    academicYear: academicYear,
  );

  /// Fetches students belonging to a specific class.
  /// Like `Student::where('class_id', $classId)->get()` in Laravel.
  /// Used to select which students an activity targets.
  Future<List<dynamic>> getStudentsByClass(String classId) =>
      _metadataHelper.getStudentsByClass(classId);

  /// Tests API connectivity by hitting the health endpoint.
  /// Like Laravel's `/api/health` route. Useful for debugging.
  Future<dynamic> testConnection() => _metadataHelper.testConnection();

  /// Fetches filter dropdown options for the activity list screen.
  /// Like a Laravel endpoint returning distinct values for filter selects.
  /// Similar to a Vue composable that loads filter metadata on mount.
  Future<Map<String, dynamic>> getActivityFilterOptions({
    String? teacherId,
    String? classId,
    String? date,
    String? month,
    String? year,
    String? subjectId,
  }) => _metadataHelper.getActivityFilterOptions(
    teacherId: teacherId,
    classId: classId,
    date: date,
    month: month,
    year: year,
    subjectId: subjectId,
  );

  /// Exports class activities to a downloadable format.
  /// Like Laravel's export endpoint that returns a file response.
  /// Returns raw Response so the caller can handle the file bytes.
  Future<Response> exportClassActivities(
    List<Map<String, dynamic>> activities,
  ) => _exportHelper.exportClassActivities(activities);

  /// Gets the count of unread class activities for badge display.
  /// Like a Laravel notification count endpoint. Returns 0 on error.
  Future<int> getUnreadCount() => _exportHelper.getUnreadCount();

  /// Marks specific class activities as read (like Laravel's notification
  /// markAsRead).
  /// [activityIds] - List of activity UUIDs to mark. Returns true on success.
  Future<bool> markAsRead(List<String> activityIds) =>
      _exportHelper.markAsRead(activityIds);
}
