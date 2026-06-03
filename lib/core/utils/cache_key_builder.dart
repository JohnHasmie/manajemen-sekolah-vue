/// cache_key_builder.dart - Centralized cache key construction.
/// Like Laravel's cache key conventions: `Cache::remember("user_{$id}_profile",
/// ...)`.
///
/// Replaces 15+ files manually building cache keys like:
/// `'grade_classes_${teacherId}_$yearId'`
///
/// Ensures consistent key naming and school-scoping across all features.
library;

/// Builds consistent, school-scoped cache keys for LocalCacheService.
/// All keys follow the pattern: `{feature}_{context}_{schoolId}`.
class CacheKeyBuilder {
  CacheKeyBuilder._();

  // ── Teacher ──
  static String teacherClasses(String teacherId, String yearId) =>
      'teacher_classes_${teacherId}_$yearId';

  static String teacherProfile(String userId) => 'teacher_profile_$userId';

  static String teacherList(String schoolId, [String? query]) =>
      'teacher_list_${schoolId}_${query ?? 'all'}';

  // ── Student ──
  static String studentList(String schoolId, [String? query]) =>
      'student_list_${schoolId}_${query ?? 'all'}';

  static String studentsByClass(String classId) => 'students_class_$classId';

  // ── Class ──
  static String classList(String schoolId, [String? query]) =>
      'class_list_${schoolId}_${query ?? 'all'}';

  // ── Subject ──
  static String subjectList(String schoolId, [String? query]) =>
      'subject_list_${schoolId}_${query ?? 'all'}';

  static String subjectFilters(String schoolId) => 'subject_filters_$schoolId';

  // ── Schedule ──
  static String scheduleList(String schoolId, [String? query]) =>
      'schedule_list_${schoolId}_${query ?? 'all'}';

  static String dailySchedule(String teacherId, String dayId, String yearId) =>
      'daily_schedule_${teacherId}_${dayId}_$yearId';

  // ── Attendance ──
  static String attendanceList(String classId, String subjectId, String date) =>
      'attendance_${classId}_${subjectId}_$date';

  // ── Grade ──
  static String gradeClasses(String teacherId, String yearId) =>
      'grade_classes_${teacherId}_$yearId';

  // ── Tour ──

  // ── Announcement ──
  static String announcementFilters(String schoolId) =>
      'announcement_filters_$schoolId';

  // ── Finance ──
  static String financeData(String schoolId, String yearId) =>
      'finance_${schoolId}_$yearId';

  // ── Generic ──
  static String custom(String feature, String context, [String? scope]) =>
      scope != null ? '${feature}_${context}_$scope' : '${feature}_$context';
}
