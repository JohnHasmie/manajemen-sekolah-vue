import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_state_bridge_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/data_loading_mixin.dart';

/// Mixin for data loading, caching, and pagination logic.
///
/// Owns all data-loading methods. Requires AdminScheduleStateBridgeMixin for
/// state access. Used alongside AdminScheduleFilterMixin and AdminScheduleTourMixin.
mixin AdminScheduleDataMixin
    on
        ConsumerState<TeachingScheduleManagementScreen>,
        AdminScheduleStateBridgeMixin {
  bool get showTableView;

  /// Load cached schedule data for instant display.
  Future<void> loadCachedScheduleData() async {
    final result = await controller.loadCachedScheduleData();
    if (result == null || !mounted) return;
    setState(() {
      updateScheduleList(result.scheduleList);
      updateSubjectList(result.subjectList);
      updateClassList(result.classList);
      updateDayList(result.dayList);
      updateTermList(result.semesterList);
      updateLessonHourList(result.lessonHourList);
      updateHasMoreData(result.hasMoreData);
      updateIsLoading(result.isLoading);
      updateLastCachedAcademicYear(selectedAcademicYear);
      updateLastCachedTerm(selectedTerm);
    });
  }

  /// Set default academic period based on current date.
  void setDefaultAcademicPeriod() {
    final year = controller.setDefaultAcademicPeriod(
      availableAcademicYears: availableAcademicYears,
    );
    updateSelectedAcademicYear(year);
  }

  /// Update semester selection after semester list is loaded.
  Future<void> updateCurrentTerm() async {
    final newSemesterId = await controller.updateCurrentSemester(
      semesterList: termList,
      currentSemesterId: selectedTerm,
    );
    if (newSemesterId != null && mounted) {
      setState(() => updateSelectedTerm(newSemesterId));
      await loadData(
        resetPage: true,
        useCache: true,
        searchText: '',
        showTableView: showTableView,
      );
    }
  }

  /// Fetch filter options from API.
  Future<void> loadFilterOptions() async {
    final result = await controller.loadFilterOptions(
      selectedAcademicYear: selectedAcademicYear,
    );
    if (result == null || !mounted) return;
    setState(() {
      updateAvailableTeachers(result.teachers);
      updateAvailableClasses(result.classes);
      updateAvailableDays(result.days);
      updateAvailableSemesters(result.semesters);
      updateAvailableAcademicYears(result.academicYears);
    });
  }

  /// Build cache key for current state.
  String? buildScheduleCacheKey({
    required int currentPage,
    required bool showTableView,
    required String searchText,
  }) {
    final key = controller.buildScheduleCacheKey(
      currentPage: currentPage,
      showTableView: showTableView,
      selectedAcademicYear: selectedAcademicYear,
      selectedSemester: selectedTerm,
      selectedTeacherId: selectedTeacherId,
      selectedClassId: selectedClassId,
      selectedDayId: selectedDayId,
      selectedJamPelajaran: selectedLessonHour,
      selectedFilterSemester: selectedFilterTerm,
      searchText: searchText,
      lastCachedAcademicYear: lastCachedAcademicYear,
      lastCachedSemester: lastCachedTerm,
    );
    if (key != null) {
      updateLastCachedAcademicYear(selectedAcademicYear);
      updateLastCachedTerm(selectedTerm);
    }
    return key;
  }

  /// Unpack schedule load result into state.
  void applyLoadResult(ScheduleLoadResult result) {
    updateScheduleList(result.scheduleList);
    updateSubjectList(result.subjectList);
    updateClassList(result.classList);
    updateDayList(
      result.dayList.isEmpty && availableDays.isNotEmpty
          ? availableDays
          : result.dayList,
    );
    updateTermList(result.semesterList);
    updateLessonHourList(result.lessonHourList);
    updateHasMoreData(result.hasMoreData);
    updateIsLoading(result.isLoading);
  }

  /// Load all schedule + reference data with cache-first strategy.
  Future<void> loadData({
    bool resetPage = true,
    bool useCache = true,
    required String searchText,
    required bool showTableView,
  }) async {
    if (resetPage) {
      updateCurrentPage(1);
      updateHasMoreData(true);
    }

    try {
      final result = await controller.loadData(
        showTableView: showTableView,
        selectedSemester: selectedTerm,
        selectedFilterSemester: selectedFilterTerm,
        selectedAcademicYear: selectedAcademicYear,
        selectedTeacherId: selectedTeacherId,
        selectedClassId: selectedClassId,
        selectedDayId: selectedDayId,
        selectedJamPelajaran: selectedLessonHour,
        searchText: searchText,
        perPage: perPage,
        availableDays: availableDays,
        lastCachedAcademicYear: lastCachedAcademicYear,
        lastCachedSemester: lastCachedTerm,
        useCache: useCache,
      );

      if (!mounted) return;

      if (result == null) {
        if (scheduleList.isEmpty) {
          _showErrorSnackBar(
            ref.read(languageRiverpod).getTranslatedText({
              'en': 'Failed to load schedules',
              'id': 'Gagal memuat jadwal',
            }),
          );
        }
        setState(() => updateIsLoading(false));
        return;
      }

      setState(() => applyLoadResult(result));

      controller.saveScheduleToCache(
        cacheKey: buildScheduleCacheKey(
          currentPage: currentPage,
          showTableView: showTableView,
          searchText: searchText,
        ),
        scheduleResponse: {'data': result.scheduleList},
        teacher: result.teacherList,
        subject: result.subjectList,
        classData: result.classList,
        days: result.dayList,
        semester: result.semesterList,
        lessonHours: result.lessonHourList,
      );

      if (termList.isNotEmpty) {
        await updateCurrentTerm();
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      if (scheduleList.isEmpty) {
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
      setState(() => updateIsLoading(false));
    }
  }

  /// Load next page for infinite scroll.
  Future<void> loadMoreData({required String searchText}) async {
    if (isLoadingMore || !hasMoreData) return;
    setState(() => updateIsLoadingMore(true));

    updateCurrentPage(currentPage + 1);
    final result = await controller.loadMoreData(
      nextPage: currentPage,
      perPage: perPage,
      selectedSemester: selectedTerm,
      selectedFilterSemester: selectedFilterTerm,
      selectedAcademicYear: selectedAcademicYear,
      selectedTeacherId: selectedTeacherId,
      selectedClassId: selectedClassId,
      selectedDayId: selectedDayId,
      selectedJamPelajaran: selectedLessonHour,
      searchText: searchText,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        updateIsLoadingMore(false);
        updateCurrentPage(currentPage - 1);
      });
      return;
    }

    setState(() {
      final newList = List<dynamic>.from(scheduleList);
      newList.addAll(result.newItems);
      updateScheduleList(newList);
      updateHasMoreData(result.hasMoreData);
      updateIsLoadingMore(false);
    });

    AppLogger.info(
      'schedule',
      'Loaded more schedules: Page $currentPage, Total: ${scheduleList.length}',
    );
  }

  /// Force refresh: clear cache and reload from API.
  Future<void> forceRefresh() async {
    await controller.forceRefresh(
      cacheKey: buildScheduleCacheKey(
        currentPage: currentPage,
        showTableView: false,
        searchText: '',
      ),
      selectedAcademicYear: selectedAcademicYear,
    );
    // Note: calling loadData will be done by the screen
  }

  void _showErrorSnackBar(String message) {
    // No-op stub; implemented by screen
  }
}
