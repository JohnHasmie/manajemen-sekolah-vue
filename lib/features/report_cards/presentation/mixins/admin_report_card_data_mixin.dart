import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';

/// Mixin for data loading and caching logic.
mixin AdminReportCardDataMixin on ConsumerState<AdminReportCardScreen> {
  // Data state holder - no longer used but kept for compatibility

  String? buildClassesCacheKey() {
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'raport_classes_$yearId';
  }

  String? buildStudentsCacheKey() {
    if (selectedClass == null) return null;
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'raport_students_${selectedClass!['id']}_$yearId';
  }

  Future<void> forceRefresh() async {
    final classesKey = buildClassesCacheKey();
    if (classesKey != null) await LocalCacheService.invalidate(classesKey);
    await LocalCacheService.clearStartingWith('tour_raport_screen_');
    if (selectedClass != null) {
      final studentsKey = buildStudentsCacheKey();
      if (studentsKey != null) {
        await LocalCacheService.invalidate(studentsKey);
      }
      loadStudents(useCache: false);
    } else {
      loadInitialData(useCache: false);
    }
  }

  Future<void> loadInitialData({bool useCache = true}) async {
    if (useCache) {
      final cacheKey = buildClassesCacheKey();
      if (cacheKey != null) {
        final cached = await LocalCacheService.load(cacheKey);
        if (cached != null && cached['data'] != null && mounted) {
          final cachedList = cached['data'] as List<dynamic>;
          if (cachedList.isNotEmpty) {
            setState(() {
              classes = cachedList;
              isLoading = false;
            });
            AppLogger.info('report_card', 'Classes loaded from cache');
            return;
          }
        }
      }
    }

    if (classes.isEmpty && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final classesResponse = await getIt<ApiClassService>().getClassPaginated(
        limit: 100,
        academicYearId: academicYearId,
      );

      if (mounted) {
        setState(() {
          classes = classesResponse['data'] ?? [];
          isLoading = false;
        });

        final cacheKey = buildClassesCacheKey();
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {
            'data': classesResponse['data'] ?? [],
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (classes.isEmpty) {
          setState(() {
            errorMessage = e.toString();
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      }
    }
  }

  Future<void> loadStudents({bool useCache = true}) async {
    if (selectedClass == null) return;

    errorMessage = '';

    if (useCache) {
      final cacheKey = buildStudentsCacheKey();
      if (cacheKey != null) {
        final cached = await LocalCacheService.load(cacheKey);
        if (cached != null && cached['data'] != null && mounted) {
          final cachedList = cached['data'] as List<dynamic>;
          if (cachedList.isNotEmpty) {
            setState(() {
              students = cachedList;
              isLoadingStudents = false;
            });
            AppLogger.info('report_card', 'Students loaded from cache');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && students.isNotEmpty) {
                checkAndShowTour();
              }
            });
            return;
          }
        }
      }
    }

    if (students.isEmpty && mounted) {
      setState(() {
        isLoadingStudents = true;
      });
    }

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      if (academicYearId == null) {
        throw Exception('Tahun ajaran tidak valid.');
      }

      final studentsData = await getIt<ApiReportCardService>().getRaports(
        classId: selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
      );

      if (mounted) {
        setState(() {
          students = studentsData;
          isLoadingStudents = false;
        });

        final cacheKey = buildStudentsCacheKey();
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {'data': studentsData});
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && students.isNotEmpty) {
            checkAndShowTour();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        if (students.isEmpty) {
          setState(() {
            errorMessage = e.toString();
            isLoadingStudents = false;
          });
        } else {
          setState(() => isLoadingStudents = false);
        }
      }
    }
  }

  // Abstract properties to be defined in state class
  List<dynamic> get classes;
  set classes(List<dynamic> value);

  Map<String, dynamic>? get selectedClass;
  set selectedClass(Map<String, dynamic>? value);

  List<dynamic> get students;
  set students(List<dynamic> value);

  bool get isLoading;
  set isLoading(bool value);

  bool get isLoadingStudents;
  set isLoadingStudents(bool value);

  String get errorMessage;
  set errorMessage(String value);

  Future<void> checkAndShowTour();
}

class _AdminReportCardDataState {}
