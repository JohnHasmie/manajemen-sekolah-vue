// Controller for AdminScheduleManagementScreen — holds all data/logic that
// does NOT touch Flutter widgets or setState.
//
// In Laravel terms, this is like a controller class that handles business logic
// while the screen (View) handles rendering. The screen owns state variables
// (_scheduleList, _isLoading, etc.) and calls setState after each method returns.
//
// Pattern: plain Dart class with a Riverpod Provider, matching how
// TeacherGradeController is wired but without AsyncNotifier since the screen
// manages its own loading state via setState.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/exports/schedule_export_service.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/timetable_data_source.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';

/// Riverpod provider — use `ref.read(adminScheduleControllerProvider)` in the
/// screen to get the controller instance. Like a Laravel service container
/// binding: one instance per screen lifecycle.
final adminScheduleControllerProvider = Provider<AdminScheduleController>((ref) {
  return AdminScheduleController(ref);
});

/// Result returned by [AdminScheduleController.loadData] so the screen can
/// unpack it with setState in one call (like a PHP controller returning a
/// JSON response that the frontend deserialises).
class ScheduleLoadResult {
  final List<dynamic> scheduleList;
  final List<dynamic> teacherList;
  final List<dynamic> subjectList;
  final List<dynamic> classList;
  final List<dynamic> dayList;
  final List<dynamic> semesterList;
  final List<dynamic> lessonHourList;
  final bool hasMoreData;
  final bool isLoading;

  const ScheduleLoadResult({
    required this.scheduleList,
    required this.teacherList,
    required this.subjectList,
    required this.classList,
    required this.dayList,
    required this.semesterList,
    required this.lessonHourList,
    required this.hasMoreData,
    required this.isLoading,
  });
}

/// Result returned by [AdminScheduleController.loadMoreData].
class ScheduleLoadMoreResult {
  final List<dynamic> newItems;
  final bool hasMoreData;

  const ScheduleLoadMoreResult({
    required this.newItems,
    required this.hasMoreData,
  });
}

/// Result returned by [AdminScheduleController.loadFilterOptions].
class FilterOptionsResult {
  final List<dynamic> teachers;
  final List<dynamic> classes;
  final List<dynamic> days;
  final List<dynamic> semesters;
  final List<dynamic> academicYears;

  const FilterOptionsResult({
    required this.teachers,
    required this.classes,
    required this.days,
    required this.semesters,
    required this.academicYears,
  });
}

/// Result returned by [AdminScheduleController.updateGridData].
class GridUpdateResult {
  final List<ScheduleGridData> gridData;
  final TimetableDataSource timetableDataSource;

  const GridUpdateResult({
    required this.gridData,
    required this.timetableDataSource,
  });
}

/// Controller that owns every data/logic method extracted from
/// [TeachingScheduleManagementScreenState].
///
/// Think of this like a Laravel Controller class: it calls Services and returns
/// plain data. The screen (View) calls setState with that data to re-render.
/// No BuildContext is stored — it is passed as a parameter only when a method
/// needs to show dialogs/snackbars.
class AdminScheduleController {
  /// Riverpod [Ref] — used to read other providers, e.g. language, academic year.
  /// Like Laravel's `app()->make()` but scoped to the current widget tree.
  final Ref ref;

  // Service dependencies injected via GetIt (like Laravel service container).
  final ApiSubjectService _apiSubjectService = getIt<ApiSubjectService>();
  final ApiTeacherService _apiTeacherService = getIt<ApiTeacherService>();
  final ApiService _apiService = ApiService();

  AdminScheduleController(this.ref);

  // ---------------------------------------------------------------------------
  // Cache helpers
  // ---------------------------------------------------------------------------

  /// Generates the cache key for the schedule list. Returns null when filters
  /// or search are active — like a conditional HTTP cache header.
  ///
  /// [currentPage], [showTableView], filters and search are passed in because
  /// they live as state fields on the screen, not here.
  String? buildScheduleCacheKey({
    required int currentPage,
    required bool showTableView,
    required String selectedAcademicYear,
    required String selectedSemester,
    required String? selectedTeacherId,
    required String? selectedClassId,
    required String? selectedDayId,
    required String? selectedJamPelajaran,
    required String? selectedFilterSemester,
    required String searchText,
    required String? lastCachedAcademicYear,
    required String? lastCachedSemester,
  }) {
    if (currentPage != 1) return null;
    if (showTableView) return null;
    if (selectedTeacherId != null ||
        selectedClassId != null ||
        selectedDayId != null ||
        selectedJamPelajaran != null ||
        selectedFilterSemester != null ||
        searchText.trim().isNotEmpty) {
      return null;
    }

    final key = 'schedule_list_${selectedAcademicYear}_$selectedSemester';

    // Persist current values so early cache load works on next app launch.
    if (selectedAcademicYear != lastCachedAcademicYear ||
        selectedSemester != lastCachedSemester) {
      final prefs = PreferencesService();
      prefs.setString('schedule_last_year_id', selectedAcademicYear);
      prefs.setString('schedule_last_semester_id', selectedSemester);
    }

    return key;
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  /// Loads cached schedule data (used on startup for instant display before
  /// the API call completes). Returns null if nothing is cached yet.
  ///
  /// Equivalent to reading from Laravel's Redis cache before hitting the DB.
  Future<ScheduleLoadResult?> loadCachedScheduleData() async {
    try {
      final prefs = PreferencesService();
      final lastYear = prefs.getString('schedule_last_year_id');
      final lastSemester = prefs.getString('schedule_last_semester_id');

      if (lastYear == null || lastSemester == null) return null;

      final cacheKey = 'schedule_list_${lastYear}_$lastSemester';
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );

      if (cached == null) return null;

      final cachedData = Map<String, dynamic>.from(cached);
      final result = applyScheduleData(
        scheduleResponse: {
          'data': List<dynamic>.from(cachedData['schedules'] ?? []),
          'pagination': cachedData['pagination'] != null
              ? Map<String, dynamic>.from(cachedData['pagination'])
              : null,
        },
        teacher: List<dynamic>.from(cachedData['teachers'] ?? []),
        subject: List<dynamic>.from(cachedData['subjects'] ?? []),
        classData: List<dynamic>.from(cachedData['classes'] ?? []),
        days: List<dynamic>.from(cachedData['hari'] ?? []),
        semester: List<dynamic>.from(cachedData['semester'] ?? []),
        lessonHours: List<dynamic>.from(cachedData['jamPelajaran'] ?? []),
        availableDays: [],
      );
      AppLogger.info('schedule', 'Schedules loaded from persisted cache (early)');
      return result;
    } catch (e) {
      AppLogger.error('schedule', e);
      return null;
    }
  }

  /// Pure data-mapping method — takes raw API response maps and returns a
  /// [ScheduleLoadResult]. No setState, no widget code.
  ///
  /// Like a Laravel Resource/Transformer that shapes API output for the view.
  ScheduleLoadResult applyScheduleData({
    required Map<String, dynamic> scheduleResponse,
    required List<dynamic> teacher,
    required List<dynamic> subject,
    required List<dynamic> classData,
    required List<dynamic> days,
    required List<dynamic> semester,
    required List<dynamic> lessonHours,
    required List<dynamic> availableDays,
  }) {
    final effectiveDays = days.isEmpty && availableDays.isNotEmpty
        ? availableDays
        : days;

    return ScheduleLoadResult(
      scheduleList: scheduleResponse['data'] ?? [],
      teacherList: teacher,
      subjectList: subject,
      classList: classData,
      dayList: effectiveDays,
      semesterList: semester,
      lessonHourList: lessonHours,
      hasMoreData: scheduleResponse['pagination']?['has_next_page'] ?? false,
      isLoading: false,
    );
  }

  /// Fetches all schedule data from the API (or cache-first when [useCache] is
  /// true). Returns null on error — the screen should handle null gracefully.
  ///
  /// This is like a Laravel controller action: gathers data, delegates to
  /// services, and returns a result DTO. The screen decides how to render it.
  Future<ScheduleLoadResult?> loadData({
    required bool showTableView,
    required String selectedSemester,
    required String? selectedFilterSemester,
    required String selectedAcademicYear,
    required String? selectedTeacherId,
    required String? selectedClassId,
    required String? selectedDayId,
    required String? selectedJamPelajaran,
    required String searchText,
    required int perPage,
    required List<dynamic> availableDays,
    required String? lastCachedAcademicYear,
    required String? lastCachedSemester,
    bool useCache = true,
  }) async {
    try {
      final semesterToUse = selectedFilterSemester ?? selectedSemester;

      final results = await Future.wait([
        showTableView
            ? getIt<ApiScheduleService>().getAllSchedules(
                semesterId: semesterToUse,
                academicYearId: selectedAcademicYear,
              ).catchError((e) {
                AppLogger.error('schedule', e);
                throw e;
              })
            : getIt<ApiScheduleService>().getSchedulesPaginated(
                page: 1,
                limit: perPage,
                teacherId: selectedTeacherId,
                classId: selectedClassId,
                dayId: selectedDayId,
                semesterId: semesterToUse,
                academicYearId: selectedAcademicYear,
                search: searchText.trim().isEmpty ? null : searchText.trim(),
                lessonHourId: null,
                hourNumber: selectedJamPelajaran,
                skipCache: !useCache,
              ).catchError((e) {
                AppLogger.error('schedule', e);
                throw e;
              }),
        _apiTeacherService.getTeacher().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        _apiSubjectService.getSubject().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        getIt<ApiClassService>().getClass().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        getIt<ApiScheduleService>().getDays().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        getIt<ApiScheduleService>().getSemester().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        getIt<ApiScheduleService>().getJamPelajaran().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
      ]);

      final scheduleResponse = results[0] as Map<String, dynamic>;
      final teacher = results[1] as List<dynamic>;
      final subject = results[2] as List<dynamic>;
      final classData = results[3] as List<dynamic>;
      final days = results[4] as List<dynamic>;
      final semester = results[5] as List<dynamic>;
      final lessonHours = results[6] as List<dynamic>;

      return applyScheduleData(
        scheduleResponse: scheduleResponse,
        teacher: teacher,
        subject: subject,
        classData: classData,
        days: days,
        semester: semester,
        lessonHours: lessonHours,
        availableDays: availableDays,
      );
    } catch (e) {
      AppLogger.error('schedule', e);
      return null;
    }
  }

  /// Saves the loaded schedule data into the local cache (only for default,
  /// unfiltered first-page views — like Laravel's remember() cache helper).
  void saveScheduleToCache({
    required String? cacheKey,
    required Map<String, dynamic> scheduleResponse,
    required List<dynamic> teacher,
    required List<dynamic> subject,
    required List<dynamic> classData,
    required List<dynamic> days,
    required List<dynamic> semester,
    required List<dynamic> lessonHours,
  }) {
    if (cacheKey == null) return;
    LocalCacheService.save(cacheKey, {
      'schedules': scheduleResponse['data'] ?? [],
      'pagination': scheduleResponse['pagination'],
      'teachers': teacher,
      'subjects': subject,
      'classes': classData,
      'hari': days,
      'semester': semester,
      'jamPelajaran': lessonHours,
    });
  }

  /// Loads the next page of schedules for infinite scroll.
  /// Returns the new items and updated pagination flag.
  Future<ScheduleLoadMoreResult?> loadMoreData({
    required int nextPage,
    required int perPage,
    required String selectedSemester,
    required String? selectedFilterSemester,
    required String selectedAcademicYear,
    required String? selectedTeacherId,
    required String? selectedClassId,
    required String? selectedDayId,
    required String? selectedJamPelajaran,
    required String searchText,
  }) async {
    try {
      final semesterToUse = selectedFilterSemester ?? selectedSemester;

      final response = await getIt<ApiScheduleService>().getSchedulesPaginated(
        page: nextPage,
        limit: perPage,
        teacherId: selectedTeacherId,
        classId: selectedClassId,
        dayId: selectedDayId,
        semesterId: semesterToUse,
        academicYearId: selectedAcademicYear,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
        lessonHourId: null,
        hourNumber: selectedJamPelajaran,
      );

      return ScheduleLoadMoreResult(
        newItems: response['data'] ?? [],
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
      );
    } catch (e) {
      AppLogger.error('schedule', e);
      return null;
    }
  }

  /// Invalidates caches and triggers a clean API reload.
  /// Like `php artisan cache:clear` scoped to the schedule feature.
  Future<void> forceRefresh({
    required String? cacheKey,
    required String selectedAcademicYear,
  }) async {
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_schedule_management_');
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('schedule_filter_options', selectedAcademicYear),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter options
  // ---------------------------------------------------------------------------

  /// Fetches filter options (teacher list, class list, days, semesters,
  /// academic years) for the filter sheet — cache-first with 6-hour TTL.
  Future<FilterOptionsResult?> loadFilterOptions({
    required String selectedAcademicYear,
  }) async {
    try {
      final cacheKey = 'schedule_filter_options_$selectedAcademicYear';
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null) {
          final cachedData = Map<String, dynamic>.from(cached);
          AppLogger.info('schedule', 'Schedule filter options loaded from cache');
          return FilterOptionsResult(
            teachers: List<dynamic>.from(cachedData['teachers'] ?? []),
            classes: List<dynamic>.from(cachedData['classes'] ?? []),
            days: List<dynamic>.from(cachedData['days'] ?? []),
            semesters: List<dynamic>.from(cachedData['semesters'] ?? []),
            academicYears: List<dynamic>.from(cachedData['academic_years'] ?? []),
          );
        }
      } catch (e) {
        AppLogger.error('schedule', e);
      }

      final response = await getIt<ApiScheduleService>()
          .getScheduleFilterOptions(academicYearId: selectedAcademicYear);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final result = FilterOptionsResult(
          teachers: data['teachers'] ?? [],
          classes: data['classes'] ?? [],
          days: data['days'] ?? [],
          semesters: data['semesters'] ?? [],
          academicYears: data['academic_years'] ?? [],
        );
        // Non-blocking cache save
        LocalCacheService.save(cacheKey, {
          'teachers': result.teachers,
          'classes': result.classes,
          'days': result.days,
          'semesters': result.semesters,
          'academic_years': result.academicYears,
        });
        AppLogger.info('schedule', 'Schedule filter options loaded');
        return result;
      }
      return null;
    } catch (e) {
      AppLogger.error('schedule', e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Academic period helpers
  // ---------------------------------------------------------------------------

  /// Determines the correct academic year ID from the list, using the API's
  /// "current" flag first, then date-based fallback. Returns the resolved ID.
  String setDefaultAcademicPeriod({
    required List<dynamic> availableAcademicYears,
  }) {
    if (availableAcademicYears.isEmpty) return '1';

    final currentFromApi = availableAcademicYears.firstWhere(
      (y) => y['current'] == true || y['current'] == 1,
      orElse: () => <String, dynamic>{},
    );

    if ((currentFromApi as Map).isNotEmpty) {
      return currentFromApi['id'].toString();
    }

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final targetYearString = currentMonth >= 7
        ? '$currentYear/${currentYear + 1}'
        : '${currentYear - 1}/$currentYear';

    final dateBasedYear = availableAcademicYears.firstWhere(
      (y) => (y['year'] ?? '').toString() == targetYearString,
      orElse: () => <String, dynamic>{},
    );

    if ((dateBasedYear as Map).isNotEmpty) {
      return dateBasedYear['id'].toString();
    }

    return availableAcademicYears.first['id'].toString();
  }

  /// Determines the correct semester ID to display, using the API's "current"
  /// flag first then a backend date-based lookup. Returns the resolved semester
  /// ID, or null if it matches the current selection (no reload needed).
  Future<String?> updateCurrentSemester({
    required List<dynamic> semesterList,
    required String currentSemesterId,
  }) async {
    if (semesterList.isEmpty) return null;

    String? semesterId;

    final currentFromApi = semesterList.firstWhere(
      (s) => s['current'] == true || s['current'] == 1,
      orElse: () => <String, dynamic>{},
    );

    if ((currentFromApi as Map).isNotEmpty) {
      semesterId = currentFromApi['id'].toString();
    } else {
      try {
        final result = await getIt<ApiScheduleService>().getDateBasedSemester();
        if (result.isNotEmpty && result.containsKey('semester')) {
          final targetSemesterName = result['semester'].toString();
          final dateBasedSemester = semesterList.firstWhere((s) {
            final name = (s['name'] ?? s['nama'] ?? '').toString();
            return name.contains(targetSemesterName);
          }, orElse: () => <String, dynamic>{});

          if ((dateBasedSemester as Map).isNotEmpty) {
            semesterId = dateBasedSemester['id'].toString();
          }
        }
      } catch (e) {
        AppLogger.error('schedule', e);
      }

      semesterId ??= semesterList.first['id'].toString();
    }

    // Return new ID only if it differs — caller reloads data only on change.
    if (semesterId != currentSemesterId) {
      AppLogger.debug('schedule', 'DEBUG: Auto-switching to semester: $semesterId');
      return semesterId;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Grid / timetable data
  // ---------------------------------------------------------------------------

  /// Rebuilds the [TimetableDataSource] and [ScheduleGridData] list from the
  /// current schedule list and reference data. Returns the result as a value
  /// object — the screen calls setState with the new data source.
  GridUpdateResult updateGridData({
    required List<dynamic> scheduleList,
    required List<dynamic> dayList,
    required List<dynamic> classList,
    required List<dynamic> lessonHourList,
    required List<dynamic> availableDays,
    required String? selectedDayId,
    required String? selectedClassId,
    required String? selectedJamPelajaran,
    required Function(Map<String, dynamic>) onScheduleTap,
  }) {
    final gridData = _generateTimetableData(
      scheduleList: scheduleList,
      dayList: dayList,
      classList: classList,
    );

    final languageProvider = ref.read(languageRiverpod);

    var filteredDayList = dayList;
    if (selectedDayId != null) {
      filteredDayList =
          dayList.where((d) => d['id'].toString() == selectedDayId).toList();
    }

    final days = filteredDayList
        .map((d) => translateDay(
              d['name'] ?? d['nama'] ?? '',
              languageProvider.currentLanguage,
            ))
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    var filteredClassList = classList;
    if (selectedClassId != null) {
      filteredClassList =
          classList.where((c) => c['id'].toString() == selectedClassId).toList();
    }

    List<String> timeSlots = _generateTimeSlots(lessonHourList);
    if (selectedJamPelajaran != null) {
      timeSlots = lessonHourList
          .where((jp) {
            final h = (jp['hour_number'] ?? jp['jam_ke'])?.toString();
            return h == selectedJamPelajaran;
          })
          .map((jam) {
            String start =
                (jam['start_time'] ?? jam['jam_mulai'] ?? '').toString();
            String end =
                (jam['end_time'] ?? jam['jam_selesai'] ?? '').toString();
            if (start.length > 5) start = start.substring(0, 5);
            if (end.length > 5) end = end.substring(0, 5);
            return '$start-$end';
          })
          .toSet()
          .toList();
    }

    final dataSource = TimetableDataSource(
      timeSlots: timeSlots,
      days: days,
      classList: filteredClassList,
      gridData: gridData,
      primaryColor: getPrimaryColor(),
      onScheduleTap: onScheduleTap,
    );

    return GridUpdateResult(gridData: gridData, timetableDataSource: dataSource);
  }

  List<String> _generateTimeSlots(List<dynamic> lessonHourList) {
    final slots = lessonHourList
        .map((jam) {
          String start =
              (jam['start_time'] ?? jam['jam_mulai'] ?? '').toString();
          String end =
              (jam['end_time'] ?? jam['jam_selesai'] ?? '').toString();
          if (start.length > 5) start = start.substring(0, 5);
          if (end.length > 5) end = end.substring(0, 5);
          return '$start-$end';
        })
        .toSet()
        .toList();

    slots.sort((a, b) {
      final startA = a.split('-').first;
      final startB = b.split('-').first;
      return startA.compareTo(startB);
    });

    return slots;
  }

  List<ScheduleGridData> _generateTimetableData({
    required List<dynamic> scheduleList,
    required List<dynamic> dayList,
    required List<dynamic> classList,
  }) {
    final List<ScheduleGridData> timetableData = [];

    final Map<String, String> dayIdToName = {};
    for (var day in dayList) {
      final id = day['id']?.toString() ?? '';
      final name = day['name'] ?? day['nama'] ?? '';
      if (id.isNotEmpty) dayIdToName[id] = name;
    }

    final Map<String, String> classIdToName = {};
    for (var cls in classList) {
      final id = cls['id']?.toString() ?? '';
      final name = cls['name'] ?? cls['nama'] ?? '';
      if (id.isNotEmpty) classIdToName[id] = name;
    }

    final languageProvider = ref.read(languageRiverpod);

    for (var schedule in scheduleList) {
      final daysIds = [];
      if (schedule['days_ids'] != null) {
        if (schedule['days_ids'] is List) {
          daysIds.addAll(schedule['days_ids']);
        } else if (schedule['days_ids'] is String) {
          try {
            final parsed = (schedule['days_ids'] as String)
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',');
            daysIds.addAll(parsed);
          } catch (e) {
            // Malformed days_ids string — skip and fall through to day_id fallback
          }
        }
      }
      if (daysIds.isEmpty) {
        if (schedule['day_id'] != null) {
          daysIds.add(schedule['day_id']);
        } else if (schedule['hari_id'] != null) {
          daysIds.add(schedule['hari_id']);
        }
      }

      for (var rawDayId in daysIds) {
        final dayId = rawDayId.toString();
        final classId = schedule['kelas_id']?.toString() ??
            schedule['class_id']?.toString() ??
            '';

        final dayName = dayIdToName[dayId] ?? '';
        final translatedDayName =
            translateDay(dayName, languageProvider.currentLanguage);
        final className = classIdToName[classId] ?? schedule['kelas_nama'] ?? '';

        final timeSlot =
            '${schedule['jam_mulai'] ?? schedule['start_time'] ?? ''}-${schedule['jam_selesai'] ?? schedule['end_time'] ?? ''}';

        final List<String> parts = timeSlot.split('-');
        String start = parts[0];
        String end = parts.length > 1 ? parts[1] : '';
        if (start.length > 5) start = start.substring(0, 5);
        if (end.length > 5) end = end.substring(0, 5);
        final formattedTimeSlot = '$start-$end';

        timetableData.add(
          ScheduleGridData(
            id: schedule['id']?.toString() ?? '',
            timeSlot: formattedTimeSlot,
            day: translatedDayName,
            classroom: className,
            subject: schedule['subject_name'] ??
                schedule['mata_pelajaran_nama'] ??
                '-',
            teacher: schedule['teacher_name'] ?? schedule['guru_nama'] ?? '',
            originalData: schedule,
          ),
        );
      }
    }

    return timetableData;
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Deletes a schedule by ID. Returns true on success.
  /// Requires [BuildContext] only for the confirmation dialog — it is NOT
  /// stored on the class (just used locally then discarded).
  Future<bool> deleteSchedule(String id) async {
    try {
      await getIt<ApiScheduleService>().deleteSchedule(id);
      return true;
    } catch (e) {
      AppLogger.error('schedule', e);
      return false;
    }
  }

  /// Handles post-save conflict detection and resolution. Returns true if the
  /// schedule was ultimately saved (with or without conflict resolution).
  ///
  /// [context] is needed only for the [ConflictResolutionDialog]. Like passing
  /// `$request` to a Laravel form request — used briefly, not stored.
  Future<bool> checkAndResolveConflicts(
    BuildContext context,
    Map<String, dynamic> newScheduleData, {
    String? editingScheduleId,
  }) async {
    try {
      final conflicts = await getIt<ApiScheduleService>()
          .getConflictingSchedules(
        daysIds: (newScheduleData['days_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        classId: newScheduleData['class_id'],
        teacherId: newScheduleData['teacher_id'],
        semesterId: newScheduleData['semester_id'],
        academicYearId: newScheduleData['academic_year_id'],
        lessonHourId: newScheduleData['lesson_hour_days_id'],
        excludeScheduleId: editingScheduleId,
      );

      if (conflicts.isNotEmpty) {
        if (!context.mounted) return false;
        final result = await showDialog<String>(
          context: context,
          builder: (context) => ConflictResolutionDialog(
            conflictingSchedules: conflicts,
            onDeleteConfirmed: (scheduleId) =>
                AppNavigator.pop(context, scheduleId),
            onCancel: () => AppNavigator.pop(context),
          ),
        );

        if (result != null) {
          await getIt<ApiScheduleService>().deleteSchedule(result);

          try {
            if (editingScheduleId != null) {
              await getIt<ApiScheduleService>()
                  .updateSchedule(editingScheduleId, newScheduleData);
            } else {
              await getIt<ApiScheduleService>().addSchedule(newScheduleData);
            }
          } catch (e) {
            AppLogger.error('schedule', e);
          }
          return true;
        }
        return false;
      } else {
        try {
          if (editingScheduleId != null) {
            await getIt<ApiScheduleService>()
                .updateSchedule(editingScheduleId, newScheduleData);
          } else {
            await getIt<ApiScheduleService>().addSchedule(newScheduleData);
          }
        } catch (e) {
          AppLogger.error('schedule', e);
        }
        return true;
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Excel import / export
  // ---------------------------------------------------------------------------

  /// Opens a file picker and imports schedules from an Excel file.
  /// Returns true if the import succeeded.
  ///
  /// [context] is NOT stored — it is passed in only for the error snackbar
  /// message lookup, which is delegated back to the screen via return value.
  Future<bool> importFromExcel() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiScheduleService>().importSchedulesFromExcel(
          File(result.files.single.path!),
        );
        getIt<ApiScheduleService>().invalidateCache();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('schedule', e);
      rethrow;
    }
  }

  /// Enriches schedules with day names and academic year labels, then writes
  /// to an Excel file. [context] is required by [ExcelScheduleService].
  Future<void> exportToExcel({
    required BuildContext context,
    required List<dynamic> scheduleList,
    required List<dynamic> dayList,
    required List<dynamic> availableAcademicYears,
  }) async {
    final enrichedSchedules = scheduleList.map((schedule) {
      final dayId = schedule['day_id']?.toString() ?? '';
      final dayData = dayList.firstWhere(
        (d) => d['id'].toString() == dayId,
        orElse: () => <String, dynamic>{},
      );

      final Map<String, dynamic> newSchedule = Map.from(schedule);
      if ((dayData as Map).isNotEmpty) {
        newSchedule['day_name'] = dayData['name'] ?? dayData['nama'];
      }

      final academicYearId = schedule['academic_year_id']?.toString() ?? '';
      if (academicYearId.isNotEmpty) {
        final academicYearData = availableAcademicYears.firstWhere(
          (ay) => ay['id'].toString() == academicYearId,
          orElse: () => <String, dynamic>{},
        );
        if ((academicYearData as Map).isNotEmpty) {
          newSchedule['academic_year'] =
              academicYearData['year'] ?? academicYearData['name'] ?? '';
        }
      }
      return newSchedule;
    }).toList();

    await ExcelScheduleService.exportSchedulesToExcel(
      schedules: enrichedSchedules,
      context: context,
    );
  }

  /// Downloads the Excel import template. [context] is required by
  /// [ExcelScheduleService].
  Future<void> downloadTemplate(BuildContext context) async {
    await ExcelScheduleService.downloadTemplate(context);
  }

  // ---------------------------------------------------------------------------
  // Pure helper / utility methods
  // ---------------------------------------------------------------------------

  /// Returns the grade level string for a class ID. Like a model accessor.
  String getGradeLevel(String classId, List<dynamic> classList) {
    try {
      final classItem = classList.firstWhere(
        (k) => k['id'] == classId,
        orElse: () => {},
      );
      return classItem['grade_level']?.toString() ?? '-';
    } catch (e) {
      return '-';
    }
  }

  /// Formats start–end time from a schedule map into "HH:mm - HH:mm".
  String formatTime(Map<String, dynamic> schedule) {
    final startTime = schedule['jam_mulai'] ?? schedule['start_time'] ?? '';
    final endTime = schedule['jam_selesai'] ?? schedule['end_time'] ?? '';

    if (startTime.toString().isEmpty || endTime.toString().isEmpty) {
      return '-';
    }
    return '$startTime - $endTime';
  }

  /// Translates a day name between Indonesian and English based on
  /// [languageCode] ('id' or 'en'). Pure function — no side effects.
  String translateDay(String dayName, String languageCode) {
    if (dayName.isEmpty) return '';

    const Map<String, String> enToId = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };

    const Map<String, String> idToEn = {
      'Senin': 'Monday',
      'Selasa': 'Tuesday',
      'Rabu': 'Wednesday',
      'Kamis': 'Thursday',
      'Jumat': 'Friday',
      'Sabtu': 'Saturday',
      'Minggu': 'Sunday',
    };

    String normalizedDay = dayName.trim();
    if (normalizedDay.isNotEmpty) {
      normalizedDay =
          normalizedDay[0].toUpperCase() + normalizedDay.substring(1);
    }

    if (languageCode == 'id') {
      if (idToEn.containsKey(normalizedDay)) return normalizedDay;
      return enToId[normalizedDay] ?? normalizedDay;
    } else {
      if (enToId.containsKey(normalizedDay)) return normalizedDay;
      return idToEn[normalizedDay] ?? normalizedDay;
    }
  }

  /// Resolves day IDs for a schedule entry to localised day-name strings.
  /// Requires [dayList] and [languageCode] because they live in screen state.
  String formatScheduleDays(
    Map<String, dynamic> schedule,
    List<dynamic> dayList,
    String languageCode,
  ) {
    final daysIds = [];
    if (schedule['days_ids'] != null) {
      if (schedule['days_ids'] is List) {
        daysIds.addAll(schedule['days_ids']);
      } else if (schedule['days_ids'] is String) {
        try {
          final raw = schedule['days_ids'] as String;
          final clean = raw
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .replaceAll("'", "");
          if (clean.trim().isNotEmpty) {
            daysIds.addAll(clean.split(',').map((e) => e.trim()));
          }
        } catch (e) {
          AppLogger.error('schedule', e);
        }
      }
    }

    if (daysIds.isEmpty) {
      if (schedule['hari_id'] != null) {
        daysIds.add(schedule['hari_id']);
      } else if (schedule['day_id'] != null) {
        daysIds.add(schedule['day_id']);
      }
    }

    if (daysIds.isNotEmpty) {
      final dayNames = daysIds
          .map((id) {
            final idStr = id.toString();
            final day = dayList.firstWhere(
              (d) => d['id'].toString().toLowerCase() == idStr.toLowerCase(),
              orElse: () => {},
            );
            if ((day as Map).isNotEmpty) {
              return translateDay(
                day['name'] ?? day['nama'] ?? '',
                languageCode,
              );
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (dayNames.isNotEmpty) return dayNames.join(', ');
    }

    if (schedule['hari_nama'] != null &&
        schedule['hari_nama'].toString().isNotEmpty) {
      return translateDay(schedule['hari_nama'], languageCode);
    }

    return 'No Day';
  }

  /// Filters [scheduleList] client-side by search text and the active filter
  /// fields (teacher, class, day, lesson hour). Semester and academic year are
  /// handled server-side so they are not re-checked here.
  ///
  /// Like a Laravel Collection filter() call — pure data transformation.
  List<dynamic> getFilteredSchedules({
    required List<dynamic> scheduleList,
    required List<dynamic> dayList,
    required String searchText,
    required String? selectedTeacherId,
    required String? selectedClassId,
    required String? selectedDayId,
    required String? selectedJamPelajaran,
  }) {
    final searchTerm = searchText.toLowerCase();
    return scheduleList.where((schedule) {
      final subjectName = schedule['subject_name']?.toString().toLowerCase() ??
          schedule['mata_pelajaran_nama']?.toString().toLowerCase() ??
          '';
      final teacherName = schedule['teacher_name']?.toString().toLowerCase() ??
          schedule['guru_nama']?.toString().toLowerCase() ??
          '';
      final className = schedule['class_name']?.toString().toLowerCase() ??
          schedule['kelas_nama']?.toString().toLowerCase() ??
          '';

      // Build a searchable day-names string from IDs.
      final daysIds = [];
      if (schedule['days_ids'] is List) {
        daysIds.addAll(schedule['days_ids']);
      } else if (schedule['day_id'] != null) {
        daysIds.add(schedule['day_id']);
      }
      final dayNamesString = daysIds.map((id) {
        final d = dayList.firstWhere(
          (element) => element['id'].toString() == id.toString(),
          orElse: () => <String, dynamic>{},
        );
        return ((d as Map).isNotEmpty
            ? (d['name'] ?? d['nama'] ?? '')
            : ''
        ).toString().toLowerCase();
      }).join(' ');

      final matchesSearch = searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          teacherName.contains(searchTerm) ||
          className.contains(searchTerm) ||
          dayNamesString.contains(searchTerm);

      // Teacher filter
      bool matchesGuru = true;
      if (selectedTeacherId != null) {
        final teacherId = schedule['teacher_id']?.toString() ??
            schedule['guru_id']?.toString();
        matchesGuru = teacherId == selectedTeacherId;
      }

      // Class filter
      bool matchesKelas = true;
      if (selectedClassId != null) {
        final classId = schedule['class_id']?.toString() ??
            schedule['kelas_id']?.toString();
        matchesKelas = classId == selectedClassId;
      }

      // Day filter
      bool matchesHari = true;
      if (selectedDayId != null) {
        final ids = [];
        if (schedule['days_ids'] is List) {
          ids.addAll(schedule['days_ids']);
        } else if (schedule['day_id'] != null) {
          ids.add(schedule['day_id']);
        }
        matchesHari =
            ids.any((id) => id.toString() == selectedDayId.toString());
      }

      // Lesson-hour filter
      bool matchesJamPelajaran = true;
      if (selectedJamPelajaran != null) {
        final lessonHour = schedule['lesson_hour'] as Map<String, dynamic>?;
        final hourNumber = lessonHour?['hour_number']?.toString() ??
            lessonHour?['jam_ke']?.toString();
        matchesJamPelajaran = hourNumber == selectedJamPelajaran;
      }

      return matchesSearch &&
          matchesGuru &&
          matchesKelas &&
          matchesHari &&
          matchesJamPelajaran;
    }).toList();
  }

  /// Returns true if any non-default filter is active.
  bool checkActiveFilter({
    required String? selectedDayId,
    required String? selectedClassId,
    required String? selectedJamPelajaran,
    required String? selectedFilterSemester,
    required String selectedSemester,
  }) {
    return selectedDayId != null ||
        selectedClassId != null ||
        selectedJamPelajaran != null ||
        (selectedFilterSemester != null &&
            selectedFilterSemester != selectedSemester);
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  /// Returns the primary colour for the admin role.
  Color getPrimaryColor() => ColorUtils.getRoleColor('admin');

  /// Returns the [ApiService] instance (needed by form dialogs in the screen).
  ApiService get apiService => _apiService;

  /// Returns the [ApiTeacherService] instance (needed by form dialogs).
  ApiTeacherService get apiTeacherService => _apiTeacherService;
}
