/// schedule_admin_actions_service.dart — Admin-only mutation endpoints
/// added for the admin Jadwal redesign.
///
/// Backs Frame E (drag-and-drop reschedule) and Frame F (bulk-select
/// mode) of the redesigned admin Jadwal hub. Each method invalidates
/// the schedule cache so the next list-load is fresh.
///
/// All endpoints return raw `dynamic` maps so callers can inspect
/// the per-row conflict payload returned on 409 / when force=false.
library;

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule_kpi_summary.dart';

/// Service for admin-only schedule actions (KPI summary + reschedule + bulk).
class ScheduleAdminActionsService {
  // ── KPI summary ───────────────────────────────────────────────────────

  /// Fetches the admin Jadwal KPI summary used by the redesigned hub.
  ///
  /// Hits `GET /teaching-schedule/stats?semester_id&academic_year_id` —
  /// the same endpoint the legacy stats card uses; TR.1 extended the
  /// response with `today` and `conflicts`.
  Future<ScheduleKpiSummary> fetchKpiSummary({
    String? semesterId,
    String? academicYearId,
  }) async {
    final query = <String, String>{
      if (semesterId != null) 'semester_id': semesterId,
      if (academicYearId != null) 'academic_year_id': academicYearId,
    };

    try {
      final response = await dioClient.get(
        '/teaching-schedule/stats',
        queryParameters: query,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ScheduleKpiSummary.fromJson(data);
      }
      return const ScheduleKpiSummary.empty();
    } on DioException catch (e) {
      AppLogger.error('schedule', 'fetchKpiSummary failed: ${e.message}');
      return const ScheduleKpiSummary.empty();
    }
  }

  // ── Single reschedule (drag-and-drop) ─────────────────────────────────

  /// Moves an existing schedule to a new lesson_hour slot.
  ///
  /// Returns the updated schedule payload on 200. Re-throws on 409 with
  /// a structured `{error, conflicts: [...]}` body so the caller can
  /// render a red conflict toast with Undo + offer "paksa simpan"
  /// (re-call with `force: true`).
  Future<Map<String, dynamic>> rescheduleSession({
    required String scheduleId,
    required String lessonHourDaysId,
    bool force = false,
  }) async {
    final response = await dioClient.patch(
      '/teaching-schedule/$scheduleId/reschedule',
      data: {
        'lesson_hour_days_id': lessonHourDaysId,
        if (force) 'force': true,
      },
    );
    await CacheInvalidationService.onScheduleChanged();
    final data = response.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ── Bulk move ─────────────────────────────────────────────────────────

  /// Bulk-reschedules N sessions to the equivalent lesson_hour on
  /// [targetDayId] (preserving each session's hour_number).
  ///
  /// Returns `{moved_count, moved: [ids], skipped: [{id, reason, conflicts?}]}`
  /// so the caller can render a granular result snack and offer to
  /// retry the skipped ones with force=true.
  Future<Map<String, dynamic>> bulkMoveSessions({
    required List<String> ids,
    required String targetDayId,
    bool force = false,
  }) async {
    final response = await dioClient.patch(
      '/teaching-schedule/bulk/move',
      data: {
        'ids': ids,
        'target_day_id': targetDayId,
        if (force) 'force': true,
      },
    );
    await CacheInvalidationService.onScheduleChanged();
    final data = response.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ── Bulk change teacher ───────────────────────────────────────────────

  /// Bulk-reassigns N sessions to [teacherId]. Skips rows where the new
  /// teacher already has a conflicting slot (unless force=true).
  Future<Map<String, dynamic>> bulkChangeTeacher({
    required List<String> ids,
    required String teacherId,
    bool force = false,
  }) async {
    final response = await dioClient.patch(
      '/teaching-schedule/bulk/change-teacher',
      data: {
        'ids': ids,
        'teacher_id': teacherId,
        if (force) 'force': true,
      },
    );
    await CacheInvalidationService.onScheduleChanged();
    final data = response.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ── Bulk delete ───────────────────────────────────────────────────────

  /// Bulk-deletes N sessions. Replaces the per-row loop the admin UI
  /// used to do.
  Future<int> bulkDeleteSessions(List<String> ids) async {
    final response = await dioClient.delete(
      '/teaching-schedule/bulk',
      data: {'ids': ids},
    );
    await CacheInvalidationService.onScheduleChanged();
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final count = data['deleted_count'];
      if (count is num) return count.toInt();
    }
    return 0;
  }
}
