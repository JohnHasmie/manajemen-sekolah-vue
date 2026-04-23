/// schedule_mutation_service.dart - Create, update, and delete schedule
/// operations with cache invalidation.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for schedule mutation operations (CRUD write operations).
class ScheduleMutationService {
  /// Clears all schedule-related cache entries.
  /// Called after any mutation to ensure fresh data on next load.
  /// Like Laravel's `Cache::tags('schedules')->flush()`.
  Future<void> invalidateCache() async {
    await CacheInvalidationService.onScheduleChanged();
  }

  /// Creates a new teaching schedule entry. Invalidates cache.
  /// Like `TeachingSchedule::create($data)` in Laravel.
  Future<dynamic> addSchedule(Map<String, dynamic> data) async {
    AppLogger.debug('schedule', 'DEBUG: addSchedule request body: $data');

    final response = await dioClient.post('/teaching-schedule', data: data);

    AppLogger.debug(
      'schedule',
      'DEBUG: addSchedule response: ${response.statusCode} - '
          '${response.data}',
    );

    // Always invalidate cache after POST, even if response is an error
    // (backend may have saved the data despite returning 500)
    await invalidateCache();

    return response.data;
  }

  /// Updates an existing schedule entry. Invalidates cache.
  /// Like `TeachingSchedule::find($id)->update($data)` in Laravel.
  Future<void> updateSchedule(String id, Map<String, dynamic> data) async {
    await dioClient.put('/teaching-schedule/$id', data: data);
    await invalidateCache();
  }

  /// Deletes a schedule entry. Invalidates cache.
  /// Like `TeachingSchedule::find($id)->delete()` in Laravel.
  Future<void> deleteSchedule(String id) async {
    await dioClient.delete('/teaching-schedule/$id');
    await invalidateCache();
  }

  /// Fetches all schedules without pagination (for exports or full views).
  /// Like `TeachingSchedule::all()` in Laravel. Use sparingly for
  /// large datasets.
  Future<Map<String, dynamic>> getAllSchedules({
    String? semesterId,
    String? academicYearId,
  }) async {
    final queryParameters = {
      if (semesterId != null) 'semester_id': semesterId,
      if (academicYearId != null) 'academic_year_id': academicYearId,
    };

    String url = '/teaching-schedule/all';
    if (queryParameters.isNotEmpty) {
      final qs = Uri(queryParameters: queryParameters).query;
      url += '?$qs';
    }

    AppLogger.debug(
      'schedule',
      'DEBUG: Calling getAllSchedules with URL: $url',
    );
    final response = await dioClient.get(url);

    AppLogger.debug(
      'schedule',
      'DEBUG: getAllSchedules Response Status: ${response.statusCode}',
    );
    final dynamic data = response.data;

    if (data is List) {
      AppLogger.debug(
        'schedule',
        'DEBUG: getAllSchedules received List, wrapping in data object. '
            'Count: ${data.length}',
      );
      return {'data': data};
    } else if (data is Map<String, dynamic>) {
      AppLogger.debug(
        'schedule',
        'DEBUG: getAllSchedules received Map. '
            'Data count: ${(data['data'] as List?)?.length ?? 0}',
      );
      return data;
    }

    AppLogger.debug(
      'schedule',
      'DEBUG: getAllSchedules received unexpected type: '
          '${data.runtimeType}',
    );
    return {'data': []};
  }
}
