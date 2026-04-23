import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/cache_helper.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/day_utils_helper.dart';

/// Helper for loading and caching today's schedules.
class ScheduleLoaderHelper {
  /// Pre-loads today's schedules from cache or API.
  static Future<List<dynamic>> preloadTodaySchedules(
    Ref ref,
    dynamic teacherId,
  ) async {
    try {
      // Load school days
      List<dynamic> days = [];
      final cachedDays = await LocalCacheService.load(
        'school_day_data',
        ttl: const Duration(hours: 24),
      );
      if (cachedDays != null) {
        days = List<dynamic>.from(cachedDays);
      } else {
        days = await getIt<ApiScheduleService>().getDays();
        if (days.isNotEmpty) {
          LocalCacheService.save('school_day_data', days);
        }
      }

      // Build day ID map
      final Map<String, String> dayIdMap = {};
      for (final day in days) {
        dayIdMap[day['nama'] ?? day['name'] ?? ''] = day['id'].toString();
      }

      // Find current day ID
      final currentDayIndo = DayUtilsHelper.normalizeDayName();
      String? currentDayId;
      dayIdMap.forEach((key, value) {
        if (DayUtilsHelper.normalizeDayName(key) == currentDayIndo) {
          currentDayId = value;
        }
      });

      // Load schedules
      final academicYear = ref.read(academicYearRiverpod).selectedAcademicYear;
      final academicYearId = academicYear?['id']?.toString();
      final semester = academicYear?['semester']?.toString() ?? '1';

      List<dynamic> allSchedules = [];
      final scheduleCacheKey = CacheHelper.buildScheduleCacheKey(
        teacherId,
        semester,
        academicYearId,
      );
      final cachedSched = await LocalCacheService.load(
        scheduleCacheKey,
        ttl: const Duration(hours: 3),
      );

      if (cachedSched != null) {
        allSchedules = List<dynamic>.from(
          Map<String, dynamic>.from(cachedSched)['jadwal'] ?? [],
        );
      } else {
        final schedules = await getIt<ApiScheduleService>()
            .getSchedulesPaginated(
              limit: 100,
              teacherId: teacherId,
              academicYearId: academicYearId,
            );
        allSchedules = schedules['data'] ?? [];
      }

      // Filter today's schedules
      return allSchedules.where((s) {
        final ids = DayUtilsHelper.extractDayIds(s);
        if (currentDayId != null && ids.contains(currentDayId)) {
          return true;
        }
        return ids.any((id) {
          final entry = dayIdMap.entries.firstWhere(
            (e) => e.value == id,
            orElse: () => const MapEntry('', ''),
          );
          return entry.key.isNotEmpty &&
              DayUtilsHelper.normalizeDayName(entry.key) == currentDayIndo;
        });
      }).toList();
    } catch (e) {
      AppLogger.error('grades', e);
      return [];
    }
  }
}
