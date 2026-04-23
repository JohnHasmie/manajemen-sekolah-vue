import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';

/// Result returned by [loadData] method.
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

/// Result returned by [loadMoreData] method.
class ScheduleLoadMoreResult {
  final List<dynamic> newItems;
  final bool hasMoreData;

  const ScheduleLoadMoreResult({
    required this.newItems,
    required this.hasMoreData,
  });
}

/// Mixin providing data loading functionality for the admin
/// schedule controller.
mixin DataLoadingMixin {
  /// Provides access to the Riverpod [Ref].
  Ref get ref;

  /// Provides access to the API teacher service.
  ApiTeacherService get apiTeacherService;

  /// Loads cached schedule data from disk.
  /// Returns null if nothing is cached yet.
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
        lessonHours: List<dynamic>.from(cachedData['lessonHour'] ?? []),
        availableDays: [],
      );
      AppLogger.info(
        'schedule',
        'Schedules loaded from persisted cache (early)',
      );
      return result;
    } catch (e) {
      AppLogger.error('schedule', e);
      return null;
    }
  }

  /// Pure data-mapping method — takes raw API response maps
  /// and returns a [ScheduleLoadResult].
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

  /// Fetches all schedule data from the API.
  /// Returns null on error.
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

      final results = await _fetchAllScheduleData(
        showTableView: showTableView,
        semesterToUse: semesterToUse,
        selectedAcademicYear: selectedAcademicYear,
        perPage: perPage,
        selectedTeacherId: selectedTeacherId,
        selectedClassId: selectedClassId,
        selectedDayId: selectedDayId,
        selectedJamPelajaran: selectedJamPelajaran,
        searchText: searchText,
        useCache: useCache,
      );

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

  /// Helper method to fetch all schedule data
  /// in parallel.
  Future<List<dynamic>> _fetchAllScheduleData({
    required bool showTableView,
    required String semesterToUse,
    required String selectedAcademicYear,
    required int perPage,
    required String? selectedTeacherId,
    required String? selectedClassId,
    required String? selectedDayId,
    required String? selectedJamPelajaran,
    required String searchText,
    required bool useCache,
  }) async {
    return Future.wait([
      showTableView
          ? getIt<ApiScheduleService>()
                .getAllSchedules(
                  semesterId: semesterToUse,
                  academicYearId: selectedAcademicYear,
                )
                .catchError((e) {
                  AppLogger.error('schedule', e);
                  throw e;
                })
          : getIt<ApiScheduleService>()
                .getSchedulesPaginated(
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
                )
                .catchError((e) {
                  AppLogger.error('schedule', e);
                  throw e;
                }),
      apiTeacherService.getTeacher().catchError((e) {
        AppLogger.error('schedule', e);
        throw e;
      }),
      getIt<ApiSubjectService>().getSubject().catchError((e) {
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
  }

  /// Loads the next page of schedules for infinite scroll.
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
}
