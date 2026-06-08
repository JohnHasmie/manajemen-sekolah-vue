// teacher_attendance_admin_service.dart — the ADMIN-side data layer for
// "Presensi Guru" (teacher daily attendance) reporting. Talks to the
// backend Attendance module's TeacherAttendanceController admin routes
// (backend MR !108 for the per-row list, MR !110 for the rekap) via the
// shared `dioClient` (which injects the Bearer token + X-School-ID header
// through AuthInterceptor — see core/network/dio_client.dart).
//
// Two read endpoints, both school-scoped server-side:
//   GET /teacher-attendance/admin          → getReport()  (per-row list)
//   GET /teacher-attendance/admin/summary  → getSummary() (per-teacher rekap)
//
// This is the mobile parity of the web's `TeacherAttendanceService`
// `adminReport()` / `adminSummary()` (see web-vue
// src/services/teacher-attendance.service.ts). All aggregation, date
// defaulting (start-of-month → today), and school-scoping live SERVER
// side — this layer only shapes the query params and parses the typed
// response, exactly like the teacher-facing service alongside it.
//
// Analogy for the Laravel/Vue reader: a thin read-only Service wrapping
// `Http::withToken(...)->get(...)` — no business logic, just request
// shaping + response parsing.
library;

import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/features/teacher_attendance/domain/models/'
    'teacher_attendance_models.dart';

/// Service facade for the admin teacher-attendance report (rekap + detail).
class TeacherAttendanceAdminService {
  /// GET /teacher-attendance/admin/summary — the per-TEACHER rekap over a
  /// date range. Status columns are dynamic (read `meta.statuses`). The
  /// [teacherId] filter accepts a Teacher ID OR a User ID; the server
  /// resolves it within the active school. Date bounds default to
  /// start-of-month → today server-side when omitted (pass null/empty).
  Future<TeacherAttendanceAdminSummary> getSummary({
    String? startDate,
    String? endDate,
    String? teacherId,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;
    final teacher = teacherId?.trim();
    if (teacher != null && teacher.isNotEmpty) params['teacher_id'] = teacher;

    final response = await dioClient.get(
      ApiEndpoints.teacherAttendanceAdminSummary,
      queryParameters: params,
    );
    return TeacherAttendanceAdminSummary.fromJson(response.data);
  }

  /// GET /teacher-attendance/admin — the school-scoped per-row detail
  /// list, paginated. [teacherId] accepts a Teacher ID OR a User ID;
  /// [status] narrows to 'present' / 'late'. [date] pins a single day;
  /// [startDate]/[endDate] bound a range (the server applies whichever it
  /// is given). Returns the parsed records plus pagination meta.
  Future<TeacherAttendanceListResult> getReport({
    String? date,
    String? startDate,
    String? endDate,
    String? teacherId,
    String? status,
    int perPage = 25,
    int page = 1,
  }) async {
    final params = <String, dynamic>{'page': page, 'per_page': perPage};
    if (date != null && date.isNotEmpty) params['date'] = date;
    if (startDate != null && startDate.isNotEmpty) {
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;
    final teacher = teacherId?.trim();
    if (teacher != null && teacher.isNotEmpty) params['teacher_id'] = teacher;
    if (status != null && status.isNotEmpty) params['status'] = status;

    final response = await dioClient.get(
      ApiEndpoints.teacherAttendanceAdmin,
      queryParameters: params,
    );
    return TeacherAttendanceListResult.fromJson(response.data);
  }
}
