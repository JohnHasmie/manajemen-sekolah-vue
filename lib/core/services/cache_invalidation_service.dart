/// Centralized cache invalidation after mutations.
///
/// Every CRUD operation should call the corresponding method here
/// so that stale data never persists in LocalCacheService.
///
/// Design: each feature has its own method that knows which cache
/// prefixes to clear (including cross-feature dependencies like
/// dashboard). This avoids scattered invalidation logic and makes
/// the dependency graph explicit.
///
/// Usage from any service or controller:
/// ```dart
/// await ApiAttendanceService.createAttendance(data);
/// await CacheInvalidationService.onAttendanceChanged();
/// ```
library;

import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

class CacheInvalidationService {
  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  /// Clear dashboard aggregated data.
  /// Called as a side-effect by most feature mutations since the dashboard
  /// displays summary stats from many sources.
  static Future<void> onDashboardChanged() async {
    _log('dashboard');
    await Future.wait([
      LocalCacheService.clearStartingWith('dashboard_'),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  /// After add / update / delete a teaching schedule or lesson hour.
  static Future<void> onScheduleChanged() async {
    _log('schedule');
    await Future.wait([
      LocalCacheService.clearStartingWith('schedule_'),
      LocalCacheService.clearStartingWith('school_day_data'),
      // Dashboard shows today's schedule count
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  /// After create / bulk-create / delete attendance records.
  static Future<void> onAttendanceChanged() async {
    _log('attendance');
    await Future.wait([
      LocalCacheService.clearStartingWith('presence_'),
      // Schedule cards show attendance fill state
      LocalCacheService.clearStartingWith('schedule_week_summary'),
      // Dashboard shows attendance summary
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Grades
  // ---------------------------------------------------------------------------

  /// After create / update / delete grades or assessments.
  static Future<void> onGradeChanged() async {
    _log('grades');
    await Future.wait([
      LocalCacheService.clearStartingWith('grade_book_'),
      // Parent views
      LocalCacheService.clearStartingWith('parent_grade_'),
      // Dashboard shows grade stats
      onDashboardChanged(),
    ]);
  }

  /// After create / submit / update grade recaps.
  static Future<void> onGradeRecapChanged() async {
    _log('grade_recap');
    await Future.wait([
      LocalCacheService.clearStartingWith('grade_book_'),
      LocalCacheService.clearStartingWith('parent_grade_'),
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Lesson Plans (RPP)
  // ---------------------------------------------------------------------------

  /// After create / update / delete / upload lesson plans.
  static Future<void> onLessonPlanChanged() async {
    _log('lesson_plan');
    await Future.wait([
      LocalCacheService.clearStartingWith('rpp_'),
      // Dashboard shows RPP count & status breakdown
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Materials
  // ---------------------------------------------------------------------------

  /// After create / update / delete chapters, sub-chapters, or content.
  static Future<void> onMaterialChanged() async {
    _log('material');
    await Future.wait([
      LocalCacheService.clearStartingWith('materi_'),
      // Dashboard shows material completion stats
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Class Activities
  // ---------------------------------------------------------------------------

  /// After create / update / delete class activities.
  static Future<void> onClassActivityChanged() async {
    _log('class_activity');
    await Future.wait([
      LocalCacheService.clearStartingWith('class_activity_'),
      // Parent views
      LocalCacheService.clearStartingWith('parent_activity_'),
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Announcements
  // ---------------------------------------------------------------------------

  /// After create / update / delete announcements.
  static Future<void> onAnnouncementChanged() async {
    _log('announcement');
    await Future.wait([
      LocalCacheService.clearStartingWith('announcement_'),
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Finance
  // ---------------------------------------------------------------------------

  /// After create / update / delete bills or payments.
  static Future<void> onFinanceChanged() async {
    _log('finance');
    await Future.wait([
      LocalCacheService.clearStartingWith('finance_'),
      LocalCacheService.clearStartingWith('parent_billing_'),
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Report Cards
  // ---------------------------------------------------------------------------

  /// After create / publish / update report cards.
  static Future<void> onReportCardChanged() async {
    _log('report_card');
    await Future.wait([
      LocalCacheService.clearStartingWith('raport_'),
      LocalCacheService.clearStartingWith('raport_students_'),
      LocalCacheService.clearStartingWith('parent_raport_'),
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Admin: Teachers / Students / Classes / Subjects
  // ---------------------------------------------------------------------------

  /// After create / update / delete / import teachers.
  static Future<void> onTeacherChanged() async {
    _log('teacher');
    await Future.wait([
      LocalCacheService.clearStartingWith('teacher_'),
      LocalCacheService.clearStartingWith('schedule_'),
      LocalCacheService.clearStartingWith('filter_options_'),
      onDashboardChanged(),
    ]);
  }

  /// After create / update / delete / import students.
  static Future<void> onStudentChanged() async {
    _log('student');
    await Future.wait([
      LocalCacheService.clearStartingWith('student_'),
      LocalCacheService.clearStartingWith('presence_'),
      LocalCacheService.clearStartingWith('grade_book_'),
      LocalCacheService.clearStartingWith('filter_options_'),
      onDashboardChanged(),
    ]);
  }

  /// After create / update / delete / import / promote classes.
  static Future<void> onClassChanged() async {
    _log('class');
    await Future.wait([
      LocalCacheService.clearStartingWith('class_'),
      LocalCacheService.clearStartingWith('teacher_classes_'),
      LocalCacheService.clearStartingWith('schedule_'),
      LocalCacheService.clearStartingWith('filter_options_'),
      onDashboardChanged(),
    ]);
  }

  /// After create / update / delete subjects or subject-class assignments.
  static Future<void> onSubjectChanged() async {
    _log('subject');
    await Future.wait([
      LocalCacheService.clearStartingWith('subject_'),
      LocalCacheService.clearStartingWith('materi_subjects'),
      LocalCacheService.clearStartingWith('schedule_'),
      LocalCacheService.clearStartingWith('filter_options_'),
      onDashboardChanged(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Bulk / Pull-to-refresh
  // ---------------------------------------------------------------------------

  /// Smart refresh: clears feature data caches but preserves UI preferences
  /// (view modes, tour states). Use on dashboard pull-to-refresh.
  static Future<void> onPullToRefresh() async {
    _log('pull_to_refresh');
    await Future.wait([
      LocalCacheService.clearStartingWith('dashboard_'),
      LocalCacheService.clearStartingWith('schedule_'),
      LocalCacheService.clearStartingWith('presence_'),
      LocalCacheService.clearStartingWith('grade_book_'),
      LocalCacheService.clearStartingWith('rpp_'),
      LocalCacheService.clearStartingWith('materi_'),
      LocalCacheService.clearStartingWith('class_activity_'),
      LocalCacheService.clearStartingWith('announcement_'),
      LocalCacheService.clearStartingWith('finance_'),
      LocalCacheService.clearStartingWith('raport_'),
      LocalCacheService.clearStartingWith('parent_'),
      LocalCacheService.clearStartingWith('teacher_classes_'),
      LocalCacheService.clearStartingWith('teacher_profile_'),
      LocalCacheService.clearStartingWith('filter_options_'),
      // Deliberately NOT clearing: *_view_preference, tour_*, school_semester_data
    ]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static void _log(String feature) {
    AppLogger.debug(
      'cache_invalidation',
      'Invalidating caches for: $feature',
    );
  }
}
