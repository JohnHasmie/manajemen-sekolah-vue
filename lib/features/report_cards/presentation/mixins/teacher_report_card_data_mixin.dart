import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

/// Mixin for data loading operations (classes, students).
mixin TeacherReportCardDataMixin on ConsumerState<ReportCardScreen> {
  Future<void> loadInitialClassesData({bool useCache = true}) async {
    final classesCacheKey = buildClassesCacheKey();

    // Try TeacherProvider cache
    if (useCache && await tryLoadFromProvider()) return;

    // Try disk cache
    if (useCache && await tryLoadFromCache(classesCacheKey)) return;

    // Fetch from API
    await fetchClassesFromApi(classesCacheKey);
  }

  Future<bool> tryLoadFromProvider() async {
    try {
      final teacherProvider = ref.read(teacherRiverpod);
      if (teacherProvider.isLoaded &&
          teacherProvider.homeroomClasses.isNotEmpty) {
        final classes = List<dynamic>.from(teacherProvider.homeroomClasses);
        if (mounted) {
          onClassesLoaded(classes);
          onLoadingComplete();
          loadStudentsForClass();
        }
        AppLogger.debug(
          'report_card',
          'Classes from TeacherProvider (${classes.length})',
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> tryLoadFromCache(String cacheKey) async {
    final cached = await LocalCacheService.load(cacheKey);
    if (cached != null && cached is List && cached.isNotEmpty) {
      if (mounted) {
        onClassesLoaded(List<dynamic>.from(cached));
        onLoadingComplete();
        loadStudentsForClass();
      }
      AppLogger.debug('report_card', 'Classes from cache (${cached.length})');
      return true;
    }
    return false;
  }

  Future<void> fetchClassesFromApi(String cacheKey) async {
    if (mounted) onStartLoading();

    try {
      final response = await getIt<ApiClassService>().getClassPaginated(
        homeroomTeacherId: getTeacherId(),
        academicYearId: getAcademicYearId(),
        limit: 100,
      );

      final classes = _deduplicateClasses(response['data'] as List? ?? []);

      if (mounted) {
        onClassesLoaded(classes);
        if (classes.isNotEmpty) loadStudentsForClass();
        onLoadingComplete();
      }

      await LocalCacheService.save(cacheKey, classes);
    } catch (e) {
      if (mounted) onClassesLoadError(e.toString());
    }
  }

  List<dynamic> _deduplicateClasses(List classData) {
    final uniqueMap = <String, dynamic>{};
    for (final item in classData) {
      if (item != null && item['id'] != null) {
        uniqueMap[item['id'].toString()] = item;
      }
    }
    return uniqueMap.values.toList();
  }

  Future<void> loadStudentsForClass({bool useCache = true}) async {
    if (getSelectedClass() == null) return;

    final studentsCacheKey = buildStudentsCacheKey();

    if (useCache) {
      final cached = await LocalCacheService.load(studentsCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          onStudentsLoaded(List<dynamic>.from(cached));
          onLoadingComplete();
        }
        AppLogger.debug(
          'report_card',
          'TeacherReportCard: Students from cache (${cached.length})',
        );
        return;
      }
    }

    if (mounted) {
      onStartLoadingStudents();
    }

    try {
      final academicYearId = getAcademicYearId();

      final semester = await resolveAcademicTerm();

      final response = await getIt<ApiReportCardService>().getRaports(
        classId: getSelectedClass()!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semester,
      );

      if (mounted) {
        onStudentsLoaded(response);
        onLoadingComplete();
      }

      await LocalCacheService.save(studentsCacheKey, response);
    } catch (e) {
      if (mounted) {
        onStudentsLoadError(e.toString());
      }
    }
  }

  Future<String> resolveAcademicTerm() async {
    final cachedDayData = await LocalCacheService.load(
      'school_day_data',
      ttl: const Duration(hours: 24),
    );
    if (cachedDayData != null && cachedDayData is Map) {
      if (cachedDayData.containsKey('semester') &&
          cachedDayData['semester'].toString().toLowerCase() == 'genap') {
        return '2';
      }
      return '1';
    }
    final dateBasedSemester = await getIt<ApiScheduleService>()
        .getDateBasedSemester();
    if (dateBasedSemester.isNotEmpty) {
      await LocalCacheService.save('school_day_data', dateBasedSemester);
    }
    if (dateBasedSemester.containsKey('semester') &&
        dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
      return '2';
    }
    return '1';
  }

  // Helper for building cache keys
  String buildClassesCacheKey() {
    final academicYearId = getAcademicYearId();
    return 'raport_classes_${getTeacherId()}_$academicYearId';
  }

  String buildStudentsCacheKey() {
    final academicYearId = getAcademicYearId();
    final classId = getSelectedClass()?['id']?.toString() ?? '';
    return 'raport_students_${classId}_$academicYearId';
  }

  // Abstract methods for state communication
  String getTeacherId();
  String getAcademicYearId();
  Map<String, dynamic>? getSelectedClass();
  void onClassesLoaded(List<dynamic> classes);
  void onStudentsLoaded(List<dynamic> students);
  void onStartLoading();
  void onStartLoadingStudents();
  void onLoadingComplete();
  void onClassesLoadError(String error);
  void onStudentsLoadError(String error);
}
