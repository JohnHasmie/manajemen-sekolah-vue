/// schedule_teacher_service.dart - Teacher-specific schedule operations
/// and daily summaries.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for teacher-specific schedule operations.
class ScheduleTeacherService {
  /// Fetches schedules for a specific teacher with optional filters.
  /// Like `TeachingSchedule::where('teacher_id', $id)->get()` in Laravel.
  Future<List<dynamic>> getScheduleByTeacher({
    required String teacherId,
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) async {
    try {
      String url = '/teaching-schedule/teacher/$teacherId?';
      if (dayId != null && dayId.isNotEmpty) {
        url += 'day_id=$dayId&';
      }
      if (semesterId != null) {
        url += 'semester_id=$semesterId&';
      }
      if (academicYear != null) {
        url += 'academic_year_id=$academicYear&';
      }

      final response = await dioClient.get(url);
      final result = response.data;
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('schedule', 'Error loading schedule by guru: $e');
      return [];
    }
  }

  /// Fetches schedules for the currently authenticated user.
  /// Like `auth()->user()->teachingSchedules` in Laravel.
  Future<List<dynamic>> getCurrentUserSchedule({
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) async {
    try {
      String url = '/teaching-schedule/current?';
      if (dayId != null && dayId.isNotEmpty) {
        url += 'day_id=$dayId&';
      }
      if (semesterId != null) {
        url += 'semester_id=$semesterId&';
      }
      if (academicYear != null) {
        url += 'academic_year_id=$academicYear&';
      }

      final response = await dioClient.get(url);
      final result = response.data;
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('schedule', 'Error loading current user schedule: $e');
      return [];
    }
  }

  /// Fetches daily summary (attendance, activity, material progress) for
  /// all of a teacher's class+subject combos. Cached for 5 minutes.
  /// Returns a map keyed by "{class_id}__{subject_id}".
  Future<Map<String, dynamic>> getDailySummary({
    required String teacherId,
    String? date,
    String? academicYearId,
  }) async {
    final dateStr = date ?? DateTime.now().toIso8601String().split('T').first;
    final cacheKey = 'schedule_daily_summary_${teacherId}_$dateStr';

    // Try cache first
    final cached = await LocalCacheService.load(
      cacheKey,
      ttl: const Duration(minutes: 5),
    );
    if (cached != null && cached is Map) {
      AppLogger.debug('schedule', 'Daily summary loaded from cache');
      return Map<String, dynamic>.from(cached);
    }

    try {
      final params = <String, dynamic>{
        'teacher_id': teacherId,
        'date': dateStr,
      };
      if (academicYearId != null) {
        params['academic_year_id'] = academicYearId;
      }
      final response = await dioClient.get(
        '/teaching-schedule/daily-summary',
        queryParameters: params,
      );

      final result = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      await LocalCacheService.save(cacheKey, result);
      return result;
    } catch (e) {
      AppLogger.error('schedule', 'Error fetching daily summary: $e');
      return {};
    }
  }

  /// Fetches week summary (attendance, activity, material progress) for
  /// all of a teacher's class+subject combos for the entire week in one call.
  /// Replaces N separate getDailySummary calls with a single request.
  /// Returns a map with 'days' (keyed by date) and 'progress' (shared).
  Future<Map<String, dynamic>> getWeekSummary({
    required String teacherId,
    String? weekStart,
    String? academicYearId,
  }) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStartStr =
        weekStart ??
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    final cacheKey = 'schedule_week_summary_${teacherId}_$weekStartStr';

    // Try cache first (5 minute TTL)
    final cached = await LocalCacheService.load(
      cacheKey,
      ttl: const Duration(minutes: 5),
    );
    if (cached != null && cached is Map) {
      AppLogger.debug('schedule', 'Week summary loaded from cache');
      return Map<String, dynamic>.from(cached);
    }

    try {
      final response = await dioClient.get(
        '/teaching-schedule/week-summary',
        queryParameters: {
          'teacher_id': teacherId,
          'week_start': weekStartStr,
          if (academicYearId != null) 'academic_year_id': academicYearId,
        },
      );

      final result = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      await LocalCacheService.save(cacheKey, result);
      return result;
    } catch (e) {
      AppLogger.error('schedule', 'Error fetching week summary: $e');
      return {};
    }
  }

  /// Records that a teacher viewed material from a schedule slot.
  /// Idempotent — the backend uses updateOrCreate.
  /// Clears the week-summary cache so the next load picks up the change.
  Future<void> recordMaterialView({
    required String teacherId,
    required String classId,
    required String subjectId,
    required String date,
    String? lessonHourId,
  }) async {
    try {
      await dioClient.post(
        '/teaching-schedule/record-material-view',
        data: {
          'teacher_id': teacherId,
          'class_id': classId,
          'subject_id': subjectId,
          'date': date,
          if (lessonHourId != null) 'lesson_hour_id': lessonHourId,
        },
      );
      await LocalCacheService.clearStartingWith('schedule_week_summary');
    } catch (e) {
      AppLogger.error('schedule', 'Error recording material view: $e');
    }
  }
}
