// Controller for TeachingScheduleScreen.
// Like `pages/teacher/Schedule.vue`'s data-fetching logic extracted into its
// own composable, or a Laravel ScheduleController extracted from a fat route.
//
// Holds all API calls, cache logic, and pure helper methods so that
// teacher_schedule_screen.dart only concerns itself with widget rendering
// and `setState` calls.
//
// Usage in screen:
//   final ctrl = ref.read(teacherScheduleControllerProvider);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';

/// Riverpod provider for [TeacherScheduleController].
/// Use `ref.read(teacherScheduleControllerProvider)` from the screen.
///
/// Plain [Provider] (not AsyncNotifier) because the controller does not own
/// state — it provides methods that return structured results. State stays in
/// the screen's `setState` calls, matching the pattern used throughout this
/// codebase for ConsumerStatefulWidgets.
final teacherScheduleControllerProvider =
    Provider<TeacherScheduleController>((ref) {
  return TeacherScheduleController(ref);
});

// ---------------------------------------------------------------------------
// Result types — plain records returned by controller methods so the screen
// can apply them via setState without the controller ever calling setState.
// Think of these like DTOs from a Laravel Service returning structured data.
// ---------------------------------------------------------------------------

/// Result of [TeacherScheduleController.loadDayData].
/// The screen destructures this and applies every field via setState.
class LoadDayDataResult {
  final Map<String, String> dayIdMap;
  final List<String> dayOptions;

  const LoadDayDataResult({
    required this.dayIdMap,
    required this.dayOptions,
  });
}

/// Result of [TeacherScheduleController.loadSemesterData].
///
/// [selectedSemester] is the resolved semester ID to use as the default.
/// [error] is non-null when the load failed — the screen can decide whether
/// to show a snackbar. Keeps BuildContext out of the controller.
class LoadSemesterDataResult {
  final List<dynamic> semesterList;

  /// Resolved semester ID the screen should set as [_selectedSemester].
  final String? selectedSemester;
  final String? error;

  const LoadSemesterDataResult({
    required this.semesterList,
    this.selectedSemester,
    this.error,
  });
}

/// Result of [TeacherScheduleController.loadAcademicYearData].
class LoadAcademicYearDataResult {
  final List<dynamic> academicYearList;

  /// The academic year string the screen should set as [_selectedAcademicYear].
  final String? selectedAcademicYear;
  final String? error;

  const LoadAcademicYearDataResult({
    required this.academicYearList,
    this.selectedAcademicYear,
    this.error,
  });
}

/// Result of [TeacherScheduleController.loadSchedule].
///
/// [schedules] and [availableClasses] are non-null on success.
/// [error] is non-null on failure — screen shows snackbar if no cached data.
class LoadScheduleResult {
  final List<dynamic>? schedules;
  final List<Map<String, String>>? availableClasses;
  final String? error;

  const LoadScheduleResult({this.schedules, this.availableClasses, this.error});

  bool get isSuccess => error == null && schedules != null;
}

/// Cached schedule snapshot returned by [TeacherScheduleController.loadCachedSchedule].
/// If [found] is false the screen should not update state.
class CachedScheduleResult {
  final bool found;
  final List<dynamic> schedules;
  final List<Map<String, String>> availableClasses;

  const CachedScheduleResult({
    required this.found,
    this.schedules = const [],
    this.availableClasses = const [],
  });
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Plain Dart class that holds all data/logic for [TeachingScheduleScreen].
///
/// Analogy for a Laravel developer: this is the Controller class previously
/// inlined inside the View (teacher_schedule_screen.dart). It receives `ref`
/// (like Laravel's DI container) and explicit state parameters on each method
/// call so it stays stateless itself.
class TeacherScheduleController {
  /// Riverpod ref — reads providers the same way Laravel reads service
  /// container bindings.
  final Ref _ref;

  TeacherScheduleController(this._ref);

  // ─── Academic year helper ─────────────────────────────────────────────────

  /// Returns the current academic year string based on the current date.
  /// Academic year runs July→June, so `2024/2025` starts in July 2024.
  ///
  /// Pure function — no side effects. Like a PHP helper
  /// `getAcademicYear(Carbon::now())`.
  String getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    if (currentMonth >= 7) {
      return '$currentYear/${currentYear + 1}';
    } else {
      return '${currentYear - 1}/$currentYear';
    }
  }

  // ─── Cache key builder ────────────────────────────────────────────────────

  /// Builds the local-cache key for the schedule given the current filter
  /// state. Returns `null` when caching should be skipped (active filters).
  ///
  /// Like `Cache::tags(['schedule'])->key(...)` in Laravel.
  String? buildScheduleCacheKey({
    required String teacherId,
    required List<String> selectedDayIds,
    required String? selectedClassId,
    required String searchText,
    required String? selectedFilterSemester,
    required String selectedSemester,
    required String selectedAcademicYear,
    required bool isHomeroomView,
    required Map<String, dynamic>? selectedHomeroomClass,
  }) {
    // Don't cache when filters or search are active
    if (selectedDayIds.isNotEmpty ||
        selectedClassId != null ||
        searchText.isNotEmpty ||
        (selectedFilterSemester != null &&
            selectedFilterSemester != selectedSemester)) {
      return null;
    }
    if (teacherId.isEmpty) return null;

    final semesterToUse = selectedFilterSemester ?? selectedSemester;
    if (isHomeroomView && selectedHomeroomClass != null) {
      final classId = selectedHomeroomClass['id'].toString();
      return 'schedule_homeroom_${classId}_${semesterToUse}_$selectedAcademicYear';
    }
    return 'schedule_teacher_${teacherId}_${semesterToUse}_$selectedAcademicYear';
  }

  // ─── Reference data loaders ───────────────────────────────────────────────

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
      if (cached != null) {
        dayData = List<dynamic>.from(cached);
        AppLogger.info('schedule', 'Day data loaded from cache');
      } else {
        dayData = await getIt<ApiScheduleService>().getDays();
        if (dayData.isNotEmpty) {
          LocalCacheService.save('school_day_data', dayData);
        }
      }

      if (dayData.isNotEmpty) {
        final Map<String, String> newDayIdMap = {};
        final List<String> newDayOptions = ['Semua Hari'];

        for (var day in dayData) {
          final name =
              day['name_id']?.toString() ?? day['name']?.toString() ?? '';
          final id = day['id']?.toString() ?? '';
          if (name.isNotEmpty && id.isNotEmpty) {
            newDayIdMap[name] = id;
            newDayOptions.add(name);
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

  /// Loads the semester list and resolves which semester should be the default.
  /// Cache-first (12h for list, 6h for current-date-based selection).
  ///
  /// Like `Semester::current()` in Laravel.
  Future<LoadSemesterDataResult> loadSemesterData() async {
    try {
      List<dynamic> semesterData;
      final cachedSemester = await LocalCacheService.load(
        'school_semester_data',
        ttl: const Duration(hours: 12),
      );

      if (cachedSemester != null) {
        semesterData = List<dynamic>.from(cachedSemester);
        AppLogger.info('schedule', 'Semester list loaded from cache');
      } else {
        semesterData = await getIt<ApiScheduleService>().getSemester();
        if (semesterData.isNotEmpty) {
          LocalCacheService.save('school_semester_data', semesterData);
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

          final dateBasedSemester = semesterData.firstWhere((s) {
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
        final currentSem = semesterData.firstWhere(
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
      if (semesterId == null && semesterData.isNotEmpty) {
        semesterId = semesterData.first['id'].toString();
      }

      return LoadSemesterDataResult(
        semesterList: semesterData,
        selectedSemester: semesterId,
      );
    } catch (e) {
      AppLogger.error('schedule', 'Error loading semester data: $e');
      return LoadSemesterDataResult(semesterList: const [], error: e.toString());
    }
  }

  /// Loads the academic year list and resolves which year should be default.
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
          'Academic years loaded from provider (${academicYears.length} items)',
        );
      }

      final globalSelectedYear = academicYearProvider.selectedAcademicYear;

      final filteredYears = academicYears
          .where(
            (ay) => (ay['year'] ?? '').toString() != 'Status Kepegawaian',
          )
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
        } else if (academicYears.isNotEmpty) {
          selectedAcademicYear = academicYears.last['year'].toString();
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

  // ─── Schedule cache helpers ───────────────────────────────────────────────

  /// Tries to load a schedule snapshot from the local cache.
  /// Returns [CachedScheduleResult.found] == false if nothing is cached.
  ///
  /// Like `Cache::get('schedule_teacher_...')` in Laravel.
  Future<CachedScheduleResult> loadCachedSchedule(String cacheKey) async {
    try {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );
      if (cached != null) {
        final cachedData = Map<String, dynamic>.from(cached);
        return CachedScheduleResult(
          found: true,
          schedules: List<dynamic>.from(cachedData['jadwal'] ?? []),
          availableClasses:
              (cachedData['availableClasses'] as List<dynamic>?)
                  ?.map((e) => Map<String, String>.from(e))
                  .toList() ??
              [],
        );
      }
    } catch (e) {
      AppLogger.error('schedule', 'Schedule cache load failed: $e');
    }
    return const CachedScheduleResult(found: false);
  }

  // ─── Schedule fetch ───────────────────────────────────────────────────────

  /// Fetches the teacher's schedule from the API.
  /// Cache writing and static memory cache updates are done inside the screen
  /// after a successful fetch so the screen controls its own memory fields.
  ///
  /// Returns [LoadScheduleResult]; check [LoadScheduleResult.error] to detect
  /// failure — screen shows the snackbar itself (no BuildContext here).
  ///
  /// Like `ScheduleController@index` in Laravel returning JSON to the frontend.
  Future<LoadScheduleResult> fetchScheduleFromApi({
    required String teacherId,
    required String semesterToUse,
    required String academicYearToUse,
    required bool isHomeroomView,
    required Map<String, dynamic>? selectedHomeroomClass,
  }) async {
    try {
      AppLogger.debug('schedule', 'FETCHING SCHEDULE WITH:');
      AppLogger.debug('schedule', '- Teacher ID: $teacherId');
      AppLogger.debug('schedule', '- Semester: $semesterToUse');
      AppLogger.debug('schedule', '- Academic Year: $academicYearToUse');

      dynamic scheduleData;

      if (isHomeroomView && selectedHomeroomClass != null) {
        final classId = selectedHomeroomClass['id'].toString();
        final result = await getIt<ApiScheduleService>().getSchedulesPaginated(
          classId: classId,
          semesterId: semesterToUse,
          academicYearId: academicYearToUse,
          limit: 100,
        );
        scheduleData = result['data'] ?? [];
      } else {
        scheduleData = await getIt<ApiScheduleService>().getFilteredSchedule(
          teacherId: teacherId,
          semester: semesterToUse,
          academicYear: academicYearToUse,
        );
      }

      final schedules = scheduleData is List ? scheduleData : [];

      AppLogger.info(
        'schedule',
        'Total schedule items loaded: ${schedules.length}',
      );

      // Extract unique classes for filter dropdown
      final uniqueClasses = <String, String>{};
      for (var item in schedules) {
        final id =
            item['class_id']?.toString() ?? item['kelas_id']?.toString() ?? '';
        final name =
            item['class_name']?.toString() ??
            item['kelas_nama']?.toString() ??
            '';
        if (id.isNotEmpty && name.isNotEmpty) {
          uniqueClasses[id] = name;
        }
      }
      final classes = uniqueClasses.entries
          .map((e) => {'id': e.key, 'name': e.value})
          .toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));

      return LoadScheduleResult(schedules: schedules, availableClasses: classes);
    } catch (e) {
      AppLogger.error('schedule', 'Error load jadwal: $e');
      return LoadScheduleResult(error: e.toString());
    }
  }

  /// Invalidates the cached schedule and all related cache entries.
  /// Called by the screen's "force refresh" menu item.
  ///
  /// Like `Cache::tags(['schedule'])->flush()` in Laravel.
  Future<void> invalidateScheduleCache(String? cacheKey) async {
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('schedule_');
  }

  /// Saves a freshly-fetched schedule to the local cache.
  /// Also persists the cache key to SharedPreferences for early loading on the
  /// next app launch.
  void saveScheduleToCache({
    required String cacheKey,
    required List<dynamic> schedules,
    required List<Map<String, String>> availableClasses,
    required String prefKeyLastCacheKey,
  }) {
    LocalCacheService.save(cacheKey, {
      'jadwal': schedules,
      'availableClasses': availableClasses,
    });
    PreferencesService().setString(prefKeyLastCacheKey, cacheKey);
  }

  // ─── Filter / display helpers ─────────────────────────────────────────────

  /// Normalises a day name to its canonical Indonesian form.
  /// Accepts English names and common variants.
  ///
  /// Pure function — like a PHP `normalise_day_name()` helper.
  String normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) return 'Selasa';
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    if (name.contains('minggu') || name.contains('sunday')) return 'Minggu';
    return name;
  }

  /// Extracts the list of day-ID strings from a schedule item.
  /// Handles both Array and serialised-string formats from the API.
  ///
  /// Like a PHP accessor on the Schedule model: `getDaysIdsAttribute()`.
  List<String> extractDayIds(dynamic schedule) {
    final List<String> ids = [];
    final rawDaysIds = schedule['days_ids'];

    if (rawDaysIds != null) {
      if (rawDaysIds is List) {
        ids.addAll(rawDaysIds.map((id) => id.toString()));
      } else if (rawDaysIds is String) {
        try {
          final clean = rawDaysIds
              .replaceAll('[', '')
              .replaceAll(']', '')
              .trim();
          if (clean.isNotEmpty) {
            ids.addAll(
              clean
                  .split(',')
                  .map((id) => id.trim())
                  .where((id) => id.isNotEmpty),
            );
          }
        } catch (e) {} // ignore: empty_catches
      }
    }

    // Fallback to single day_id field
    if (ids.isEmpty) {
      final fallbackId = schedule['day_id'] ?? schedule['hari_id'];
      if (fallbackId != null) {
        ids.add(fallbackId.toString());
      }
    }
    return ids;
  }

  /// Filters and sorts the raw schedule list according to search text, day,
  /// class filters, and "today first" priority ordering.
  ///
  /// Pure function — like a Laravel `ScheduleFilter` pipeline class.
  List<dynamic> getFilteredSchedules({
    required List<dynamic> scheduleList,
    required String searchText,
    required List<String> selectedDayIds,
    required String? selectedClassId,
    required Map<String, String> dayIdMap,
  }) {
    final searchTerm = searchText.toLowerCase();
    final now = DateTime.now();

    // Standard day mappings for stable sorting
    final dayNamesISO = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    final dayOrder = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];
    final weekdayToIndo = {
      1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis',
      5: 'Jumat', 6: 'Sabtu', 7: 'Minggu',
    };

    final currentDayISO = dayNamesISO[now.weekday - 1];
    final currentDayIndo = normalizeDayName(currentDayISO);

    // Resolve current-day ID from dynamic map
    String? currentDayId;
    dayIdMap.forEach((key, value) {
      if (normalizeDayName(key) == currentDayIndo) {
        currentDayId = value.toString();
      }
    });

    final filtered = scheduleList.where((schedule) {
      final subjectName =
          schedule['mata_pelajaran_nama']?.toString().toLowerCase() ?? '';
      final className = schedule['kelas_nama']?.toString().toLowerCase() ?? '';
      final daysIds = extractDayIds(schedule);

      final dayNamesStr = daysIds
          .map((id) {
            final entry = dayIdMap.entries.firstWhere(
              (e) => e.value.toString() == id,
              orElse: () => MapEntry('', ''),
            );
            return entry.key.isNotEmpty
                ? entry.key
                : (weekdayToIndo[int.tryParse(id) ?? 0] ?? '');
          })
          .where((k) => k.isNotEmpty)
          .join(' ')
          .toLowerCase();

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          className.contains(searchTerm) ||
          dayNamesStr.contains(searchTerm);

      final matchesDay =
          selectedDayIds.isEmpty ||
          selectedDayIds.any((selectedId) {
            return daysIds.any(
              (dId) => dId.toString() == selectedId.toString(),
            );
          });

      final matchesClass =
          selectedClassId == null ||
          selectedClassId.isEmpty ||
          (schedule['class_id']?.toString() == selectedClassId ||
              schedule['kelas_id']?.toString() == selectedClassId);

      return matchesSearch && matchesDay && matchesClass;
    }).toList();

    // Sort: today first, then sequential weekday, then start time
    filtered.sort((a, b) {
      final dayIdA = extractDayIds(a);
      final dayIdB = extractDayIds(b);

      bool belongsToToday(dynamic item, List<String> ids) {
        // Tier 1: Direct hari_nama field
        final dayName = (item['hari_nama'] ?? item['day_name'] ?? '').toString();
        if (dayName.isNotEmpty && normalizeDayName(dayName) == currentDayIndo) {
          return true;
        }
        // Tier 2: ID match via dynamic map
        if (currentDayId != null && ids.any((id) => id == currentDayId)) {
          return true;
        }
        // Tier 3: Direct ISO weekday number match
        if (ids.any((id) => id == now.weekday.toString())) {
          return true;
        }
        // Tier 4: Map key normalized match
        return ids.any((id) {
          final entry = dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('', ''),
          );
          return entry.key.isNotEmpty &&
              normalizeDayName(entry.key) == currentDayIndo;
        });
      }

      final isTodayA = belongsToToday(a, dayIdA);
      final isTodayB = belongsToToday(b, dayIdB);

      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;

      int getMinDayRank(List<String> ids) {
        if (ids.isEmpty) return 99;
        int minIdx = 99;
        for (var id in ids) {
          String name = '';
          final entry = dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('', ''),
          );
          if (entry.key.isNotEmpty) {
            name = normalizeDayName(entry.key);
          } else {
            name = weekdayToIndo[int.tryParse(id) ?? 0] ?? '';
          }
          final int idx = dayOrder.indexOf(name);
          if (idx != -1 && idx < minIdx) minIdx = idx;
        }
        return minIdx;
      }

      final rankA = getMinDayRank(dayIdA);
      final rankB = getMinDayRank(dayIdB);
      if (rankA != rankB) return rankA.compareTo(rankB);

      if (dayIdA.length != dayIdB.length) {
        return dayIdA.length.compareTo(dayIdB.length);
      }

      final timeA = (a['jam_mulai'] ?? a['start_time'] ?? '00:00').toString();
      final timeB = (b['jam_mulai'] ?? b['start_time'] ?? '00:00').toString();
      return timeA.compareTo(timeB);
    });

    return filtered;
  }

  // ─── Color helpers ────────────────────────────────────────────────────────

  /// Returns the primary theme color for the teacher role.
  /// Like a Vue computed `primaryColor` that maps a role to a brand color.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  /// Returns the gradient used on the screen header card.
  LinearGradient getCardGradient() {
    final primaryColor = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
    );
  }
}
