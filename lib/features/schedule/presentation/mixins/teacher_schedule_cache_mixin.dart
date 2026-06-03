import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/teacher_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

/// Mixin for schedule caching and data loading logic.
///
/// Shared state fields (teacherIdInternal, selectedTermInternal,
/// selectedAcademicYearInternal, isHomeroomViewInternal,
/// selectedHomeroomClassInternal, isLoadingInternal) live in
/// [TeacherScheduleDataLoadingMixin] — do NOT redeclare them here.
/// This mixin only owns cache-specific state.
mixin TeacherScheduleCacheMixin on ConsumerState<TeachingScheduleScreen> {
  // ── Cache-specific state (owned by this mixin) ──
  List<dynamic> scheduleListInternal = [];
  List<Map<String, String>> availableClassesInternal = [];
  Map<String, dynamic>? dailySummaryInternal;
  String? errorMessageInternal;

  // ── Shared state — declared in TeacherScheduleDataLoadingMixin ──
  // These abstract getters let the Dart analyzer confirm the fields
  // are provided by another mixin earlier in the linearization chain.
  String get teacherIdInternal;
  String get selectedTermInternal;
  String get selectedAcademicYearInternal;
  bool get isHomeroomViewInternal;
  set isHomeroomViewInternal(bool v);
  Map<String, dynamic>? get selectedHomeroomClassInternal;
  set selectedHomeroomClassInternal(Map<String, dynamic>? v);
  bool get isLoadingInternal;
  set isLoadingInternal(bool v);

  static const String _prefKeyLastCacheKey = 'schedule_last_cache_key';

  String? buildScheduleCacheKey(
    TextEditingController searchController,
    List<String> selectedDayIds,
    String? selectedClassId,
    String? selectedFilterSemester,
    Map<String, String> dayIdMap,
  ) {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    return ctrl.buildScheduleCacheKey(
      teacherId: teacherIdInternal,
      selectedDayIds: selectedDayIds,
      selectedClassId: selectedClassId,
      searchText: searchController.text,
      selectedFilterSemester: selectedFilterSemester,
      selectedSemester: selectedTermInternal,
      selectedAcademicYear: selectedAcademicYearInternal,
      isHomeroomView: isHomeroomViewInternal,
      selectedHomeroomClass: selectedHomeroomClassInternal,
    );
  }

  Future<void> forceRefresh(
    TextEditingController searchController,
    List<String> selectedDayIds,
    String? selectedClassId,
    String? selectedFilterSemester,
    Map<String, String> dayIdMap,
    Future<void> Function({
      required TextEditingController searchController,
      required List<String> selectedDayIds,
      required String? selectedClassId,
      required String? selectedFilterSemester,
    })
    loadScheduleCallback,
  ) async {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    await ctrl.invalidateScheduleCache(
      buildScheduleCacheKey(
        searchController,
        selectedDayIds,
        selectedClassId,
        selectedFilterSemester,
        dayIdMap,
      ),
    );
    // Only clear summary caches for the teacher's own schedule tab.
    if (!isHomeroomViewInternal) {
      await LocalCacheService.clearStartingWith('schedule_daily_summary');
      await LocalCacheService.clearStartingWith('schedule_week_summary');
    }
    await loadScheduleCallback(
      searchController: searchController,
      selectedDayIds: selectedDayIds,
      selectedClassId: selectedClassId,
      selectedFilterSemester: selectedFilterSemester,
    );
    // NOTE: loadDailySummary() is NOT called here because loadSchedule()
    // already calls it on success (line 211). Calling it here too caused
    // a duplicate week-summary API fetch on pull-to-refresh.
  }

  /// Clears the week-summary cache and reloads from API.
  /// Use this as the onRefresh callback for child widgets so that
  /// closing a dialog (attendance, material, activity) immediately
  /// picks up any data changes instead of returning stale cached data.
  Future<void> refreshDailySummary() async {
    await LocalCacheService.clearStartingWith('schedule_week_summary');
    await loadDailySummary();
  }

  /// Load weekly summary in a single API call instead of N daily calls.
  Future<void> loadDailySummary() async {
    if (teacherIdInternal.isEmpty) return;
    try {
      final service = getIt<ApiScheduleService>();

      // Single API call replaces N separate getDailySummary calls
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final weekResult = await service.getWeekSummary(
        teacherId: teacherIdInternal,
        academicYearId: ayId,
      );

      final days = weekResult['days'];
      final progress = weekResult['progress'];

      final mergedSummaries = <String, dynamic>{};
      if (days is Map) {
        for (final dateEntry in days.entries) {
          final date = dateEntry.key;
          final summaries = dateEntry.value;
          if (summaries is Map) {
            for (final entry in summaries.entries) {
              mergedSummaries['${date}__${entry.key}'] = entry.value;
            }
          }
        }
      }

      // For schedule cards that only have progress data (no attendance/activity
      // for any specific date), make progress accessible at top level too.
      if (progress is Map) {
        mergedSummaries['_progress'] = Map<String, dynamic>.from(progress);
      }

      if (mounted) {
        setState(() => dailySummaryInternal = {'summaries': mergedSummaries});
      }
    } catch (e) {
      AppLogger.error('schedule', 'Error loading week summary: $e');
    }
  }

  Future<void> loadSchedule({
    bool useCache = true,
    required TextEditingController searchController,
    required List<String> selectedDayIds,
    required String? selectedClassId,
    required String? selectedFilterSemester,
    required Map<String, String> dayIdMap,
  }) async {
    if (teacherIdInternal.isEmpty) {
      setState(() => isLoadingInternal = false);
      return;
    }

    final ctrl = ref.read(teacherScheduleControllerProvider);
    final cacheKey = buildScheduleCacheKey(
      searchController,
      selectedDayIds,
      selectedClassId,
      selectedFilterSemester,
      dayIdMap,
    );

    if (useCache && cacheKey != null) {
      final cached = await ctrl.loadCachedSchedule(cacheKey);
      if (cached.found && mounted) {
        setState(() {
          scheduleListInternal = cached.schedules;
          availableClassesInternal = cached.availableClasses;
          isLoadingInternal = false;
        });
        AppLogger.info('schedule', 'Schedule loaded from cache');
      }
    }

    final hasData = scheduleListInternal.isNotEmpty;
    if (!hasData && mounted) {
      setState(() => isLoadingInternal = true);
    }

    final semesterToUse = selectedFilterSemester ?? selectedTermInternal;
    final result = await ctrl.fetchScheduleFromApi(
      teacherId: teacherIdInternal,
      semesterToUse: semesterToUse,
      academicYearToUse: selectedAcademicYearInternal,
      isHomeroomView: isHomeroomViewInternal,
      selectedHomeroomClass: selectedHomeroomClassInternal,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final schedules = result.schedules!;
      final classes = result.availableClasses!;

      setState(() {
        scheduleListInternal = schedules;
        availableClassesInternal = classes;
        isLoadingInternal = false;
        errorMessageInternal = null;
      });

      if (cacheKey != null) {
        ctrl.saveScheduleToCache(
          cacheKey: cacheKey,
          schedules: schedules,
          availableClasses: classes,
          prefKeyLastCacheKey: _prefKeyLastCacheKey,
        );
      }

      // Only fetch week-summary for the teacher's own schedule (Mengajar
      // tab). Wali Kelas mode shows another teacher's classes — the
      // attendance/material/activity summary is not relevant there.
      AppLogger.debug(
        'schedule',
        'loadSchedule success — isHomeroomView=$isHomeroomViewInternal, '
            'skipping week-summary=$isHomeroomViewInternal',
      );
      if (!isHomeroomViewInternal) {
        loadDailySummary();
      }
    } else {
      setState(() {
        isLoadingInternal = false;
        if (!hasData) {
          errorMessageInternal =
              'Gagal memuat jadwal. Tarik ke bawah untuk coba lagi.';
        }
      });
    }
  }

  // ── Public getters/setters for cache-owned state ──
  // Shared-state getters (teacherId, selectedTerm, selectedAcademicYear,
  // isHomeroomView, selectedHomeroomClass, isLoading) are provided by
  // TeacherScheduleDataLoadingMixin — do NOT redeclare them here.

  List<dynamic> get scheduleList => scheduleListInternal;
  set scheduleList(List<dynamic> v) => scheduleListInternal = v;

  List<Map<String, String>> get availableClasses => availableClassesInternal;
  Map<String, dynamic>? get dailySummary => dailySummaryInternal;
  String? get errorMessage => errorMessageInternal;
}
