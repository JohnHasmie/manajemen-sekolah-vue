import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/teacher_grade_state.dart';

final teacherGradeProvider = AsyncNotifierProvider.family<
    TeacherGradeController,
    TeacherGradeState,
    TeacherGradeParams>(
  TeacherGradeController.new,
  isAutoDispose: true,
);

class TeacherGradeController extends AsyncNotifier<TeacherGradeState> {
  /// The params passed at construction time (replaces the old `arg` property
  /// from AutoDisposeFamilyAsyncNotifier, which no longer exists in Riverpod 3.x).
  final TeacherGradeParams arg;

  TeacherGradeController(this.arg);

  List<dynamic> _todaySchedulesCache = [];

  @override
  FutureOr<TeacherGradeState> build() async {
    await _preloadTodaySchedules();
    return _loadClasses(useCache: true);
  }

  /// Pre-loads today's schedules into a local cache before state is initialized.
  Future<void> _preloadTodaySchedules() async {
    try {
      List<dynamic> days = [];
      final cachedDays = await LocalCacheService.load('school_day_data', ttl: const Duration(hours: 24));
      if (cachedDays != null) {
        days = List<dynamic>.from(cachedDays);
      } else {
        days = await getIt<ApiScheduleService>().getDays();
        if (days.isNotEmpty) LocalCacheService.save('school_day_data', days);
      }

      final Map<String, String> dayIdMap = {};
      for (var day in days) {
        dayIdMap[day['nama'] ?? day['name'] ?? ''] = day['id'].toString();
      }

      final currentDayIndo = _normalizeDayName();
      String? currentDayId;
      dayIdMap.forEach((key, value) {
        if (_normalizeDayName(key) == currentDayIndo) currentDayId = value;
      });

      final academicYear = ref.read(academicYearRiverpod).selectedAcademicYear;
      final academicYearId = academicYear?['id']?.toString();
      final semester = academicYear?['semester']?.toString() ?? '1';
      final teacherId = arg.teacher['id']?.toString() ?? '';

      List<dynamic> allSchedules = [];
      final scheduleCacheKey = CacheKeyBuilder.custom('schedule_teacher', '${teacherId}_$semester', academicYearId);
      final cachedSched = await LocalCacheService.load(scheduleCacheKey, ttl: const Duration(hours: 3));

      if (cachedSched != null) {
        allSchedules = List<dynamic>.from(Map<String, dynamic>.from(cachedSched)['jadwal'] ?? []);
      } else {
        final schedules = await getIt<ApiScheduleService>().getSchedulesPaginated(
          limit: 100,
          teacherId: arg.teacher['id'],
          academicYearId: academicYearId,
        );
        allSchedules = schedules['data'] ?? [];
      }

      _todaySchedulesCache = allSchedules.where((s) {
        final ids = _extractDayIds(s);
        if (currentDayId != null && ids.contains(currentDayId)) return true;
        return ids.any((id) {
          final entry = dayIdMap.entries.firstWhere((e) => e.value == id, orElse: () => const MapEntry('', ''));
          return entry.key.isNotEmpty && _normalizeDayName(entry.key) == currentDayIndo;
        });
      }).toList();
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  // --- Actions ---

  Future<void> setStep(int step) async {
    state = state.whenData((s) => s.copyWith(currentStep: step));
  }

  Future<void> selectClass(Map<String, dynamic> classData) async {
    state = state.whenData((s) => s.copyWith(
      selectedClass: classData,
      currentStep: 1,
      subjectList: [],
      isLoading: true,
    ));
    await loadSubjects(useCache: true);
  }

  Future<void> selectSubject(Map<String, dynamic> subjectData) async {
    state = state.whenData((s) => s.copyWith(selectedSubject: subjectData));
  }

  Future<void> updateSearch(String query) async {
    state = state.whenData((s) => s.copyWith(searchQuery: query, currentPage: 1));
    if (state.value?.currentStep == 0) {
      await _loadClasses(resetPage: true, useCache: false);
    }
    // Step 1: Subjects are filtered locally in UI for now
  }

  // --- Data Loading ---

  Future<TeacherGradeState> _loadClasses({
    bool resetPage = true,
    bool useCache = true,
  }) async {
    final currentState = (state.value ?? const TeacherGradeState()).copyWith(
      todaySchedules: _todaySchedulesCache,
    );
    final role = arg.teacher['role']?.toString().toLowerCase() ?? '';
    final isTeacher = role.contains('guru') || role.contains('teacher');

    final int page = resetPage ? 1 : currentState.currentPage;
    final List<dynamic> classList = resetPage ? [] : List.from(currentState.classList);

    if (resetPage) {
      // 1. Try TeacherProvider
      if (isTeacher && useCache) {
        final teacherProvider = ref.read(teacherRiverpod);
        if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
          final List<dynamic> providerClasses = List.from(teacherProvider.allClasses);
          _sortClassesByTodaySchedule(providerClasses, currentState.todaySchedules);
          return currentState.copyWith(
            classList: providerClasses,
            hasMoreData: false,
            isLoading: false,
          );
        }
      }

      // 2. Try Cache
      if (useCache) {
        final cacheKey = _buildClassCacheKey(page, currentState.searchQuery);
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 3));
          if (cached != null) {
            final cachedData = Map<String, dynamic>.from(cached);
            final cachedClasses = List<dynamic>.from(cachedData['classes'] ?? []);
            if (cachedClasses.isNotEmpty) {
              return currentState.copyWith(
                classList: cachedClasses,
                hasMoreData: cachedData['hasMoreData'] ?? false,
                isLoading: false,
              );
            }
          }
        }
      }
    }

    // 3. API
    try {
      final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      List<dynamic> loadedClasses = [];
      bool hasMore = false;

      if (isTeacher) {
        loadedClasses = await getIt<ApiTeacherService>().getTeacherClasses(
          arg.teacher['id'],
          academicYearId: academicYearId,
        );
        hasMore = false;
      } else {
        final response = await getIt<ApiClassService>().getClassPaginated(
          page: page,
          limit: 20,
          academicYearId: academicYearId,
          search: currentState.searchQuery,
        );
        loadedClasses = response['data'] ?? [];
        hasMore = response['pagination']?['has_next_page'] ?? false;
      }

      _sortClassesByTodaySchedule(loadedClasses, currentState.todaySchedules);
      
      final newList = resetPage ? loadedClasses : [...classList, ...loadedClasses];

      // Save to cache
      if (resetPage) {
        final cacheKey = _buildClassCacheKey(1, currentState.searchQuery);
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {
            'classes': loadedClasses,
            'hasMoreData': hasMore,
          });
        }
      }

      return currentState.copyWith(
        classList: newList,
        hasMoreData: hasMore,
        isLoading: false,
        isLoadingMore: false,
        currentPage: page,
      );
    } catch (e) {
      AppLogger.error('grades', e);
      return currentState.copyWith(isLoading: false, isLoadingMore: false);
    }
  }

  Future<void> loadMoreClasses() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMoreData) return;
    state = AsyncData(current.copyWith(isLoadingMore: true, currentPage: current.currentPage + 1));
    state = AsyncData(await _loadClasses(resetPage: false, useCache: false));
  }

  Future<void> loadSubjects({bool useCache = true}) async {
    final currentState = state.value;
    if (currentState == null || currentState.selectedClass == null) return;

    // 1. Cache
    if (useCache) {
      final cacheKey = _buildSubjectCacheKey(currentState.selectedClass!);
      if (cacheKey != null) {
        final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 3));
        if (cached != null) {
          final cachedData = Map<String, dynamic>.from(cached);
          final cachedSubjects = List<dynamic>.from(cachedData['subjects'] ?? []);
          if (cachedSubjects.isNotEmpty) {
            state = AsyncData(currentState.copyWith(
              subjectList: cachedSubjects,
              isLoading: false,
            ));
            return;
          }
        }
      }
    }

    // 2. API
    try {
      final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final classId = currentState.selectedClass!['id'].toString();
      
      // Get what THIS teacher teaches first
      final mySchedules = await getIt<ApiScheduleService>().getSchedulesPaginated(
        limit: 100,
        teacherId: arg.teacher['id'],
        classId: classId,
        academicYearId: academicYearId,
      );
      final myData = mySchedules['data'] ?? [];
      final mySubjectIds = <String>{};
      for (var item in myData) {
        final s = item['subject'] ?? item['mata_pelajaran'];
        if (s != null) mySubjectIds.add(s['id'].toString());
      }

      final role = arg.teacher['role']?.toString().toLowerCase() ?? '';
      final isTeacher = role.contains('guru') || role.contains('teacher');
      final isAdmin = !isTeacher;
      final isHomeroom = currentState.selectedClass!['is_homeroom'] == true;

      List<dynamic> subjects = [];

      if (isHomeroom || isAdmin) {
        final response = await dioClient.get('/class/$classId/subjects');
        final allSubjects = response.data is List ? response.data as List : [];
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (var s in allSubjects) {
          final sid = s['id'].toString();
          final smap = Map<String, dynamic>.from(s);
          smap['can_edit'] = isAdmin || mySubjectIds.contains(sid);
          uniqueSubjects[sid] = smap;
        }
        subjects = uniqueSubjects.values.toList();
      } else {
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (var item in myData) {
          final s = item['subject'] ?? item['mata_pelajaran'];
          if (s != null) {
            final sid = s['id'].toString();
            final smap = Map<String, dynamic>.from(s);
            smap['can_edit'] = true;
            uniqueSubjects[sid] = smap;
          }
        }
        subjects = uniqueSubjects.values.toList();
      }

      _sortSubjectsByTodaySchedule(subjects, currentState.selectedClass!['id'].toString(), currentState.todaySchedules);

      // Save to cache
      final cacheKey = _buildSubjectCacheKey(currentState.selectedClass!);
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {'subjects': subjects});
      }

      state = AsyncData(currentState.copyWith(
        subjectList: subjects,
        isLoading: false,
      ));
    } catch (e) {
      AppLogger.error('grades', e);
      state = AsyncData(currentState.copyWith(isLoading: false));
    }
  }

  /// Refreshes today's schedules into state (safe to call after build).
  Future<void> loadTodaySchedules() async {
    await _preloadTodaySchedules();
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(todaySchedules: _todaySchedulesCache));
    }
  }

  // --- Helpers ---

  String? _buildClassCacheKey(int page, String query) {
    if (page != 1 || query.trim().isNotEmpty) return null;
    final yearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ?? 'default';
    return 'grade_classes_${arg.teacher['id']}_$yearId';
  }

  String? _buildSubjectCacheKey(Map<String, dynamic> classData) {
    final yearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ?? 'default';
    return 'grade_subjects_${arg.teacher['id']}_${classData['id']}_$yearId';
  }

  void _sortClassesByTodaySchedule(List<dynamic> classes, List<dynamic> todaySchedules) {
    if (todaySchedules.isEmpty) return;
    final todayClassIds = todaySchedules
        .map((s) => (s['class_id'] ?? s['kelas_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    classes.sort((a, b) {
      final isTodayA = todayClassIds.contains(a['id'].toString());
      final isTodayB = todayClassIds.contains(b['id'].toString());
      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;
      return 0;
    });
  }

  void _sortSubjectsByTodaySchedule(List<dynamic> subjects, String classId, List<dynamic> todaySchedules) {
    if (todaySchedules.isEmpty) return;
    final todaySubjectIds = todaySchedules
        .where((s) => (s['class_id'] ?? s['kelas_id'] ?? '').toString() == classId)
        .map((s) => (s['subject_id'] ?? s['mata_pelajaran_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    subjects.sort((a, b) {
      final isTodayA = todaySubjectIds.contains(a['id'].toString());
      final isTodayB = todaySubjectIds.contains(b['id'].toString());
      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;
      return 0;
    });
  }

  String _normalizeDayName([String? name]) {
    name ??= _getSystemDayName();
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

  String _getSystemDayName() {
    final now = DateTime.now();
    final names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[now.weekday - 1];
  }

  List<String> _extractDayIds(dynamic schedule) {
    if (schedule == null) return [];
    final rawIds = schedule['days_ids'] ?? schedule['day_id'];
    if (rawIds == null) return [];
    if (rawIds is List) return rawIds.map((e) => e.toString()).toList();
    if (rawIds is String) {
      if (rawIds.contains('[')) {
        try {
          final parsed = json.decode(rawIds);
          if (parsed is List) return parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return rawIds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [rawIds.toString()];
  }
}
