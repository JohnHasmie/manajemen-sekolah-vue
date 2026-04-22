import 'package:manajemensekolah/features/attendance/data/helpers/attendance_analytics_helper.dart';
import 'package:manajemensekolah/features/attendance/data/helpers/attendance_query_helper.dart';
import 'package:manajemensekolah/features/attendance/data/helpers/attendance_write_helper.dart';
import 'package:manajemensekolah/features/attendance/domain/models/'
    'attendance.dart';

/// Main service facade for attendance operations.
/// Delegates to helper services for specific concerns.
class AttendanceService {
  static final _queryHelper = AttendanceQueryHelper();
  static final _writeHelper = AttendanceWriteHelper();
  static final _analyticsHelper = AttendanceAnalyticsHelper();

  /// Fetches attendance records with multiple optional filters.
  static Future<List<Attendance>> getAttendance({
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? academicYearId,
    String? lessonHourId,
  }) => _queryHelper.getAttendance(
    teacherId: teacherId,
    date: date,
    subjectId: subjectId,
    studentId: studentId,
    classId: classId,
    academicYearId: academicYearId,
    lessonHourId: lessonHourId,
  );

  /// Fetches paginated attendance records.
  static Future<Map<String, dynamic>> getAttendancePaginated({
    int page = 1,
    int limit = 20,
    String? teacherId,
    String? date,
    String? subjectId,
    String? studentId,
    String? classId,
    String? dateStart,
    String? dateEnd,
    String? academicYearId,
  }) => _queryHelper.getAttendancePaginated(
    page: page,
    limit: limit,
    teacherId: teacherId,
    date: date,
    subjectId: subjectId,
    studentId: studentId,
    classId: classId,
    dateStart: dateStart,
    dateEnd: dateEnd,
    academicYearId: academicYearId,
  );

  /// Fetches attendance grouped by class+subject for teacher overview.
  /// Pass [includeClasses] = true on the first call to piggy-back the
  /// teacher's class list, avoiding a separate /teacher/{id}/classes request.
  static Future<Map<String, dynamic>> getTeacherAttendanceSummary({
    String? teacherId,
    String? academicYearId,
    String? classId,
    String? subjectId,
    String? search,
    String? dateFilter,
    int page = 1,
    int perPage = 50,
    bool includeClasses = false,
    String? view,
  }) => _queryHelper.getTeacherAttendanceSummary(
    teacherId: teacherId,
    academicYearId: academicYearId,
    classId: classId,
    subjectId: subjectId,
    search: search,
    dateFilter: dateFilter,
    page: page,
    perPage: perPage,
    includeClasses: includeClasses,
    view: view,
  );

  /// Fetches basic attendance summary.
  static Future<List<dynamic>> getAttendanceSummary({
    String? teacherId,
    String? date,
    String? subjectId,
    String? classId,
    String? academicYearId,
  }) => _queryHelper.getAttendanceSummary(
    teacherId: teacherId,
    date: date,
    subjectId: subjectId,
    classId: classId,
    academicYearId: academicYearId,
  );

  /// Fetches paginated attendance summary with filters.
  static Future<Map<String, dynamic>> getAttendanceSummaryPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? subjectId,
    String? classId,
    String? date,
    String? dateStart,
    String? dateEnd,
    String? academicYearId,
    List<String>? dayIds,
    List<String>? lessonHourIds,
  }) => _queryHelper.getAttendanceSummaryPaginated(
    page: page,
    limit: limit,
    teacherId: teacherId,
    subjectId: subjectId,
    classId: classId,
    date: date,
    dateStart: dateStart,
    dateEnd: dateEnd,
    academicYearId: academicYearId,
    dayIds: dayIds,
    lessonHourIds: lessonHourIds,
  );

  /// Creates a single attendance record.
  static Future<dynamic> createAttendance(Map<String, dynamic> data) =>
      _writeHelper.createAttendance(data);

  /// Bulk creates/updates attendance for multiple students.
  static Future<Map<String, dynamic>> createBulkAttendance({
    required String teacherId,
    required String subjectId,
    required String classId,
    required String date,
    String? lessonHourId,
    required List<Map<String, dynamic>> attendances,
  }) => _writeHelper.createBulkAttendance(
    teacherId: teacherId,
    subjectId: subjectId,
    classId: classId,
    date: date,
    lessonHourId: lessonHourId,
    attendances: attendances,
  );

  /// Deletes attendance records by criteria.
  static Future<dynamic> deleteAttendance({
    required String subjectId,
    required String classId,
    required String date,
    String? lessonHourId,
  }) => _writeHelper.deleteAttendance(
    subjectId: subjectId,
    classId: classId,
    date: date,
    lessonHourId: lessonHourId,
  );

  /// Deletes attendance summary by teacher/subject/class/date.
  static Future<dynamic> deleteAttendanceSummary({
    required String teacherId,
    required String subjectId,
    required String date,
    String? classId,
    String? lessonHourId,
  }) => _writeHelper.deleteAttendanceSummary(
    teacherId: teacherId,
    subjectId: subjectId,
    date: date,
    classId: classId,
    lessonHourId: lessonHourId,
  );

  /// Marks a student's attendance as read.
  static Future<void> markAttendanceRead({required String studentId}) =>
      _writeHelper.markAttendanceRead(studentId: studentId);

  /// Marks multiple attendance records as read.
  static Future<void> markPresenceAsRead(List<String> attendanceIds) =>
      _writeHelper.markPresenceAsRead(attendanceIds);

  /// Fetches attendance statistics.
  static Future<Map<String, dynamic>> getAttendanceStats({
    String? date,
    String? classId,
    String? subjectId,
    String? teacherId,
    String? lessonHourId,
  }) => _analyticsHelper.getAttendanceStats(
    date: date,
    classId: classId,
    subjectId: subjectId,
    teacherId: teacherId,
    lessonHourId: lessonHourId,
  );

  /// Fetches count of unread attendance records.
  static Future<int> getUnreadPresenceCount() =>
      _analyticsHelper.getUnreadPresenceCount();

  /// Fetches attendance dashboard chart data.
  static Future<List<dynamic>> getAttendanceDashboardChart({
    String? academicYearId,
    String? month,
    String? week,
    String? role,
  }) => _analyticsHelper.getAttendanceDashboardChart(
    academicYearId: academicYearId,
    month: month,
    week: week,
    role: role,
  );
}
