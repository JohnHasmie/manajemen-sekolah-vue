import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/filter_options_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/admin_teacher_management_screen.dart';

mixin TeacherDataLoadingMixin on ConsumerState<TeacherAdminScreen> {
  // Abstract bridge to state
  List<dynamic> get teachers;
  set teachers(List<dynamic> v);

  List<dynamic> get subjects;
  set subjects(List<dynamic> v);

  List<dynamic> get classes;
  set classes(List<dynamic> v);

  bool get isLoading;
  set isLoading(bool v);

  String? get errorMessage;
  set errorMessage(String? v);

  int get currentPage;
  set currentPage(int v);

  int get perPage;
  bool get hasMoreData;
  set hasMoreData(bool v);

  bool get isLoadingMore;
  set isLoadingMore(bool v);

  String? get selectedClassId;
  String? get selectedHomeroomFilter;
  String? get selectedGender;
  String? get selectedEmploymentStatus;
  String? get selectedTeachingClassId;
  bool get showAllTeachers;

  String? get searchText;
  List<dynamic> get availableClass;
  set availableClass(List<dynamic> v);

  List<dynamic> get availableGenders;
  set availableGenders(List<dynamic> v);

  List<dynamic> get availableEmploymentStatus;
  set availableEmploymentStatus(List<dynamic> v);

  Future<void> loadFilterOptions() async {
    try {
      String? academicYearId;
      if (mounted) {
        try {
          final academicYearProvider = ref.read(academicYearRiverpod);
          academicYearId = academicYearProvider.selectedAcademicYear?['id']
              ?.toString();
        } catch (e) {
          // provider might not be available or other error
        }
      }

      // Uses consolidated /filter-options endpoint with caching
      final data = await FilterOptionsService.getFilterOptions(
        role: 'admin',
        academicYearId: academicYearId,
      );

      if (!mounted) return;

      setState(() {
        availableClass = List<dynamic>.from(data['classes'] ?? []);
        availableGenders = List<dynamic>.from(data['gender_options'] ?? []);
        availableEmploymentStatus = List<dynamic>.from(
          data['employment_status_options'] ?? [],
        );
      });

      AppLogger.info(
        'teacher',
        'Filter options loaded: ${availableClass.length} classes, '
            '${availableGenders.length} gender, '
            '${availableEmploymentStatus.length} employment status',
      );
    } catch (e) {
      AppLogger.error('teacher', 'Error loading filter options: $e');
    }
  }

  String? buildTeacherCacheKey() {
    if (currentPage != 1) return null;
    if (selectedClassId != null ||
        selectedHomeroomFilter != null ||
        selectedGender != null ||
        selectedEmploymentStatus != null ||
        selectedTeachingClassId != null ||
        showAllTeachers ||
        (searchText?.trim().isNotEmpty ?? false)) {
      return null;
    }
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return CacheKeyBuilder.custom('teacher_list', yearId);
  }

  Future<void> loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        currentPage = 1;
        hasMoreData = true;

        // ─── Step 1: Load from cache for instant display ───
        if (useCache) {
          final cacheKey = buildTeacherCacheKey();
          if (cacheKey != null) {
            try {
              final cached = await LocalCacheService.load(
                cacheKey,
                ttl: const Duration(hours: 3),
              );
              if (cached != null && mounted) {
                final cachedData = Map<String, dynamic>.from(cached);
                setState(() {
                  teachers = List<dynamic>.from(cachedData['teachers'] ?? []);
                  subjects = List<dynamic>.from(cachedData['subjects'] ?? []);
                  classes = List<dynamic>.from(cachedData['classes'] ?? []);
                  hasMoreData =
                      cachedData['pagination']?['has_next_page'] ?? false;
                  isLoading = false;
                  errorMessage = null;
                });
                AppLogger.info('teacher', 'Teachers loaded from cache');
                return;
              }
            } catch (e) {
              AppLogger.error('teacher', 'Teacher cache load failed: $e');
            }
          }
        }

        // Show skeleton only if no cached data displayed
        if (teachers.isEmpty && mounted) {
          setState(() {
            isLoading = true;
            errorMessage = null;
          });
        }
      }

      // ─── Step 2: Fetch fresh data from API ───
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // Load subjects and classes (for dropdown/reference)
      final subjectData = await getIt<ApiSubjectService>().getSubject();
      final classData = await getIt<ApiClassService>().getClass(
        academicYearId: selectedYearId,
      );

      // If showing all teachers, ignore academic year
      final effectiveAcademicYearId = showAllTeachers ? null : selectedYearId;

      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: currentPage,
        limit: perPage,
        classId: selectedHomeroomFilter == 'wali_kelas'
            ? selectedClassId
            : null,
        gender: selectedGender,
        employmentStatus: selectedEmploymentStatus,
        teachingClassId: selectedTeachingClassId,
        academicYearId: effectiveAcademicYearId,
        search: (searchText?.trim().isEmpty ?? true)
            ? null
            : searchText?.trim(),
        useCache: useCache,
      );

      if (!mounted) return;

      setState(() {
        teachers = response['data'] ?? [];
        subjects = subjectData;
        classes = classData;
        hasMoreData = response['pagination']?['has_next_page'] ?? false;
        isLoading = false;
      });

      // ─── Step 3: Save to cache (only for default view) ───
      final cacheKey = buildTeacherCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'teachers': response['data'] ?? [],
          'subjects': subjectData,
          'classes': classData,
          'pagination': response['pagination'],
        });
      }
    } catch (e) {
      AppLogger.error('teacher', 'Load teachers error: $e');
      if (!mounted) return;

      if (teachers.isEmpty) {
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> forceRefresh() async {
    final cacheKey = buildTeacherCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_teacher_admin_');
    await FilterOptionsService.invalidateCache();
    await loadData(resetPage: true, useCache: false);
  }

  Future<void> refreshData() async {
    await loadData(resetPage: true, useCache: false);
  }

  Future<void> loadMoreData() async {
    if (isLoadingMore || !hasMoreData) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      currentPage++;

      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final effectiveAcademicYearId = showAllTeachers ? null : selectedYearId;

      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: currentPage,
        limit: perPage,
        classId: selectedHomeroomFilter == 'wali_kelas'
            ? selectedClassId
            : null,
        gender: selectedGender,
        employmentStatus: selectedEmploymentStatus,
        teachingClassId: selectedTeachingClassId,
        academicYearId: effectiveAcademicYearId,
        search: (searchText?.trim().isEmpty ?? true)
            ? null
            : searchText?.trim(),
      );

      if (!mounted) return;

      setState(() {
        teachers.addAll(response['data'] ?? []);
        hasMoreData = response['pagination']?['has_next_page'] ?? false;
        isLoadingMore = false;
      });

      AppLogger.info(
        'teacher',
        'Loaded more data: Page $currentPage, Total items: ${teachers.length}',
      );
    } catch (e) {
      AppLogger.error('teacher', 'Error loading more data: $e');
      if (!mounted) return;

      setState(() {
        isLoadingMore = false;
        currentPage--;
      });
    }
  }
}
