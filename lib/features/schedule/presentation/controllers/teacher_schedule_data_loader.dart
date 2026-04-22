// Data loader helpers for TeacherScheduleController.
// Handles fetching reference data (days, semesters, academic years).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/'
    'school_day.dart';

/// Result of [TeacherScheduleDataLoader.loadDayData].
class LoadDayDataResult {
  final Map<String, String> dayIdMap;
  final List<String> dayOptions;

  const LoadDayDataResult({required this.dayIdMap, required this.dayOptions});
}

/// Result of [TeacherScheduleDataLoader.loadTermData].
///
/// [selectedSemester] is the resolved semester ID to use as default.
/// [error] is non-null when the load failed.
class LoadSemesterDataResult {
  final List<dynamic> semesterList;
  final String? selectedSemester;
  final String? error;

  const LoadSemesterDataResult({
    required this.semesterList,
    this.selectedSemester,
    this.error,
  });
}

/// Result of [TeacherScheduleDataLoader.loadAcademicYearData].
class LoadAcademicYearDataResult {
  final List<dynamic> academicYearList;
  final String? selectedAcademicYear;
  final String? error;

  const LoadAcademicYearDataResult({
    required this.academicYearList,
    this.selectedAcademicYear,
    this.error,
  });
}

/// Helper class for loading reference data.
class TeacherScheduleDataLoader {
  final Ref _ref;

  TeacherScheduleDataLoader(this._ref);

  /// Returns the current academic year based on the current date.
  /// Academic year runs July→June, so `2024/2025` starts in July 2024.
  ///
  /// Pure function — like a PHP helper.
  static String getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    if (currentMonth >= 7) {
      return '$currentYear/${currentYear + 1}';
    } else {
      return '${currentYear - 1}/$currentYear';
    }
  }

  /// Loads the school day list (cache-first, 24h TTL).
  /// Returns a [LoadDayDataResult] the screen applies via setState.
  ///
  /// Like `Cache::remember('school_day_data', 86400, fn() => Day::all())`.
  Future<LoadDayDataResult?> loadDayData() async {
    try {
      final cached = await LocalCacheService.load(
        'school_day_data',
        ttl: const Duration(hours: 24),
      );

      List<dynamic> dayData;
      if (cached != null && cached is List) {
        dayData = List<dynamic>.from(cached);
        AppLogger.info('schedule', 'Day data loaded from cache');
      } else if (cached != null && cached is Map && cached['data'] is List) {
        dayData = List<dynamic>.from(cached['data']);
        AppLogger.info('schedule', 'Day data loaded from cache (wrapped)');
      } else {
        dayData = await getIt<ApiScheduleService>().getDays();
        if (dayData.isNotEmpty) {
          LocalCacheService.save('school_day_data', dayData);
        }
      }

      if (dayData.isNotEmpty) {
        final days = dayData
            .map((d) => SchoolDay.fromJson(Map<String, dynamic>.from(d)))
            .toList();
        final Map<String, String> newDayIdMap = {};
        final List<String> newDayOptions = ['Semua Hari'];

        for (final day in days) {
          if (day.name.isNotEmpty && day.id.isNotEmpty) {
            final displayName = dayNameToIndonesian(day.name);
            newDayIdMap[displayName] = day.id;
            newDayOptions.add(displayName);
          }
        }

        if (newDayIdMap.isNotEmpty) {
          return LoadDayDataResult(
            dayIdMap: newDayIdMap,
            dayOptions: newDayOptions,
          );
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('schedule', 'Error loading day data: $e');
      return null;
    }
  }

  /// Loads the semester list and resolves the default semester.
  /// Cache-first (12h for list, 6h for current-date-based selection).
  ///
  /// Like `Semester::current()` in Laravel.
  Future<LoadSemesterDataResult> loadTermData() async {
    try {
      List<dynamic> termData;
      final cachedSemester = await LocalCacheService.load(
        'school_semester_data',
        ttl: const Duration(hours: 12),
      );

      if (cachedSemester != null && cachedSemester is List) {
        termData = List<dynamic>.from(cachedSemester);
        AppLogger.info('schedule', 'Semester list loaded from cache');
      } else {
        termData = await getIt<ApiScheduleService>().getSemester();
        if (termData.isNotEmpty) {
          LocalCacheService.save('school_semester_data', termData);
        }
      }

      String? semesterId;

      // ─── Try cached current-date-based semester (6h TTL) ───
      try {
        Map<String, dynamic> result;
        final cachedDateBased = await LocalCacheService.load(
          'school_current_semester',
          ttl: const Duration(hours: 6),
        );

        if (cachedDateBased != null) {
          result = Map<String, dynamic>.from(cachedDateBased);
          AppLogger.info('schedule', 'Current semester loaded from cache');
        } else {
          result = await getIt<ApiScheduleService>().getDateBasedSemester();
          if (result.isNotEmpty) {
            LocalCacheService.save('school_current_semester', result);
          }
        }

        if (result.isNotEmpty && result.containsKey('semester')) {
          final targetSemesterName = result['semester'].toString();

          final dateBasedSemester = termData.firstWhere((s) {
            final name = (s['name'] ?? s['nama'] ?? '').toString();
            return name.contains(targetSemesterName);
          }, orElse: () => null);

          if (dateBasedSemester != null) {
            semesterId = dateBasedSemester['id'].toString();
          }
        }
      } catch (e) {
        AppLogger.error('schedule', 'Error fetching date based semester: $e');
      }

      // Fallback to backend 'current' flag
      if (semesterId == null) {
        final currentSem = termData.firstWhere(
          (s) =>
              s['current'] == true ||
              s['current'] == 1 ||
              s['current'].toString() == '1',
          orElse: () => null,
        );
        if (currentSem != null) {
          semesterId = currentSem['id'].toString();
        }
      }

      // Last fallback
      if (semesterId == null && termData.isNotEmpty) {
        semesterId = termData.first['id'].toString();
      }

      return LoadSemesterDataResult(
        semesterList: termData,
        selectedSemester: semesterId,
      );
    } catch (e) {
      AppLogger.error('schedule', 'Error loading semester data: $e');
      return LoadSemesterDataResult(
        semesterList: const [],
        error: e.toString(),
      );
    }
  }

  /// Loads the academic year list and resolves the default year.
  /// Reads from the AcademicYearProvider first (populated by Dashboard),
  /// falling back to API if empty.
  ///
  /// Like `AcademicYear::current()` in Laravel.
  Future<LoadAcademicYearDataResult> loadAcademicYearData() async {
    try {
      final academicYearProvider = _ref.read(academicYearRiverpod);
      List<dynamic> academicYears = academicYearProvider.academicYears;

      if (academicYears.isEmpty) {
        AppLogger.debug(
          'schedule',
          'AcademicYearProvider empty, fetching from API',
        );
        await academicYearProvider.fetchAcademicYears();
        academicYears = academicYearProvider.academicYears;
      } else {
        AppLogger.info(
          'schedule',
          'Academic years loaded from provider '
              '(${academicYears.length} items)',
        );
      }

      final globalSelectedYear = academicYearProvider.selectedAcademicYear;

      final filteredYears = academicYears
          .where((ay) => (ay['year'] ?? '').toString() != 'Status Kepegawaian')
          .toList();

      String? selectedAcademicYear;

      if (globalSelectedYear != null) {
        selectedAcademicYear = globalSelectedYear['year'].toString();
      } else {
        final currentAY = filteredYears.firstWhere(
          (ay) =>
              ay['current'] == true ||
              ay['current'] == 1 ||
              ay['current'].toString() == '1',
          orElse: () => null,
        );

        if (currentAY != null) {
          selectedAcademicYear = currentAY['year'].toString();
        } else if (filteredYears.isNotEmpty) {
          selectedAcademicYear = filteredYears.first['year'].toString();
        }
      }

      return LoadAcademicYearDataResult(
        academicYearList: filteredYears,
        selectedAcademicYear: selectedAcademicYear,
      );
    } catch (e) {
      AppLogger.error('schedule', 'Error loading academic year data: $e');
      return LoadAcademicYearDataResult(
        academicYearList: const [],
        error: e.toString(),
      );
    }
  }
}
