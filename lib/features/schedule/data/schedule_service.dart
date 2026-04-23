/// schedule_service.dart - Main service for teaching schedules (jadwal
/// mengajar) with caching and delegation to specialized sub-services.
/// Like Laravel's TeachingScheduleController / Vue's schedule store module.
///
/// Handles CRUD for teaching schedules, lesson hours, semesters, academic
/// years, conflict detection, Excel import/export, and filtering by
/// teacher/class/day. Uses [LocalCacheService] with 30-minute TTL for
/// paginated schedule data.
library;

import 'dart:io';

import 'package:manajemensekolah/features/schedule/data/schedule_base_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_conflict_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_filter_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_import_export_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_mutation_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_teacher_service.dart';

/// Main service for teaching schedules with delegated operations.
/// Acts as a facade that delegates to specialized sub-services while
/// maintaining backward compatibility with the public API.
class ApiScheduleService {
  // Lazy initialization for sub-services
  late final ScheduleBaseService _baseService = ScheduleBaseService();
  late final ScheduleFilterService _filterService = ScheduleFilterService();
  late final ScheduleTeacherService _teacherService = ScheduleTeacherService();
  late final ScheduleConflictService _conflictService =
      ScheduleConflictService();
  late final ScheduleImportExportService _importExportService =
      ScheduleImportExportService();
  late final ScheduleMutationService _mutationService =
      ScheduleMutationService();

  // ============= Base Service Delegation =============

  Future<List<dynamic>> getDays() => _baseService.getDays();
  Future<List<dynamic>> getSemester() => _baseService.getSemester();
  Future<List<dynamic>> getAcademicYear() => _baseService.getAcademicYear();
  Future<List<dynamic>> getJamPelajaran() => _baseService.getJamPelajaran();

  Future<dynamic> addJamPelajaran(Map<String, dynamic> data) =>
      _baseService.addJamPelajaran(data);

  Future<List<dynamic>> getJamPelajaranByFilter({
    String? dayId,
    String? semesterId,
    String? classId,
    String? academicYear,
  }) => _baseService.getJamPelajaranByFilter(
    dayId: dayId,
    semesterId: semesterId,
    classId: classId,
    academicYear: academicYear,
  );

  Future<Map<String, dynamic>> getDateBasedSemester() =>
      _baseService.getDateBasedSemester();

  // ============= Filter Service Delegation =============

  Future<Map<String, dynamic>> getScheduleFilterOptions({
    String? academicYearId,
  }) => _filterService.getScheduleFilterOptions(academicYearId: academicYearId);

  Future<Map<String, dynamic>> getSchedulesPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYearId,
    String? search,
    String? lessonHourId,
    String? hourNumber,
    bool skipCache = false,
  }) => _filterService.getSchedulesPaginated(
    page: page,
    limit: limit,
    teacherId: teacherId,
    classId: classId,
    dayId: dayId,
    semesterId: semesterId,
    academicYearId: academicYearId,
    search: search,
    lessonHourId: lessonHourId,
    hourNumber: hourNumber,
    skipCache: skipCache,
  );

  Future<List<dynamic>> getSchedule({
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) => _filterService.getSchedule(
    teacherId: teacherId,
    classId: classId,
    dayId: dayId,
    semesterId: semesterId,
    academicYear: academicYear,
  );

  Future<List<dynamic>> getFilteredSchedule({
    required String teacherId,
    String? day,
    String? semester,
    String? academicYear,
  }) => _filterService.getFilteredSchedule(
    teacherId: teacherId,
    day: day,
    semester: semester,
    academicYear: academicYear,
  );

  // ============= Teacher Service Delegation =============

  Future<List<dynamic>> getScheduleByTeacher({
    required String teacherId,
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) => _teacherService.getScheduleByTeacher(
    teacherId: teacherId,
    dayId: dayId,
    semesterId: semesterId,
    academicYear: academicYear,
  );

  Future<List<dynamic>> getCurrentUserSchedule({
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) => _teacherService.getCurrentUserSchedule(
    dayId: dayId,
    semesterId: semesterId,
    academicYear: academicYear,
  );

  Future<Map<String, dynamic>> getDailySummary({
    required String teacherId,
    String? date,
    String? academicYearId,
  }) => _teacherService.getDailySummary(
    teacherId: teacherId,
    date: date,
    academicYearId: academicYearId,
  );

  Future<Map<String, dynamic>> getWeekSummary({
    required String teacherId,
    String? weekStart,
    String? academicYearId,
  }) => _teacherService.getWeekSummary(
    teacherId: teacherId,
    weekStart: weekStart,
    academicYearId: academicYearId,
  );

  Future<void> recordMaterialView({
    required String teacherId,
    required String classId,
    required String subjectId,
    required String date,
    String? lessonHourId,
  }) => _teacherService.recordMaterialView(
    teacherId: teacherId,
    classId: classId,
    subjectId: subjectId,
    date: date,
    lessonHourId: lessonHourId,
  );

  // ============= Conflict Service Delegation =============

  Future<List<dynamic>> getConflictingSchedules({
    required List<String> daysIds,
    required String classId,
    required String teacherId,
    required String semesterId,
    required String academicYearId,
    required String lessonHourId,
    String? excludeScheduleId,
  }) => _conflictService.getConflictingSchedules(
    daysIds: daysIds,
    classId: classId,
    teacherId: teacherId,
    semesterId: semesterId,
    academicYearId: academicYearId,
    lessonHourId: lessonHourId,
    excludeScheduleId: excludeScheduleId,
  );

  // ============= Import/Export Service Delegation =============

  Future<String> downloadScheduleTemplate() =>
      _importExportService.downloadScheduleTemplate();

  Future<Map<String, dynamic>> importSchedulesFromExcel(File file) =>
      _importExportService.importSchedulesFromExcel(
        file,
        invalidateCache: invalidateCache,
      );

  Future<Map<String, dynamic>> debugExcelSchedule(File file) =>
      _importExportService.debugExcelSchedule(file);

  Future<String> exportSchedules({
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYearId,
  }) => _importExportService.exportSchedules(
    teacherId: teacherId,
    classId: classId,
    dayId: dayId,
    semesterId: semesterId,
    academicYearId: academicYearId,
  );

  // ============= Mutation Service Delegation =============

  Future<void> invalidateCache() => _mutationService.invalidateCache();

  Future<dynamic> addSchedule(Map<String, dynamic> data) =>
      _mutationService.addSchedule(data);

  Future<void> updateSchedule(String id, Map<String, dynamic> data) =>
      _mutationService.updateSchedule(id, data);

  Future<void> deleteSchedule(String id) => _mutationService.deleteSchedule(id);

  Future<Map<String, dynamic>> getAllSchedules({
    String? semesterId,
    String? academicYearId,
  }) => _mutationService.getAllSchedules(
    semesterId: semesterId,
    academicYearId: academicYearId,
  );
}
