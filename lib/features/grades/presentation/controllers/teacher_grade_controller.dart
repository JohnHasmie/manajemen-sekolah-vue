import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/teacher_grade_state.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/helpers.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

final teacherGradeProvider =
    AsyncNotifierProvider.family<
      TeacherGradeController,
      TeacherGradeState,
      TeacherGradeParams
    >(TeacherGradeController.new, isAutoDispose: true);

class TeacherGradeController extends AsyncNotifier<TeacherGradeState> {
  /// The params passed at construction time (replaces the old `arg`
  /// property from AutoDisposeFamilyAsyncNotifier, which no longer
  /// exists in Riverpod 3.x).
  final TeacherGradeParams arg;

  TeacherGradeController(this.arg);

  List<dynamic> _todaySchedulesCache = [];

  @override
  FutureOr<TeacherGradeState> build() async {
    _todaySchedulesCache = await ScheduleLoaderHelper.preloadTodaySchedules(
      ref,
      Teacher.fromJson(arg.teacher).id,
    );
    return _loadClasses(useCache: true);
  }

  // --- Actions ---

  Future<void> setStep(int step) async {
    state = state.whenData((s) => s.copyWith(currentStep: step));
  }

  Future<void> selectClass(Map<String, dynamic> classData) async {
    state = state.whenData(
      (s) => s.copyWith(
        selectedClass: classData,
        currentStep: 1,
        subjectList: [],
        isLoading: true,
      ),
    );
    await loadSubjects(useCache: true);
  }

  Future<void> selectSubject(Map<String, dynamic> subjectData) async {
    state = state.whenData((s) => s.copyWith(selectedSubject: subjectData));
  }

  Future<void> updateSearch(String query) async {
    state = state.whenData(
      (s) => s.copyWith(searchQuery: query, currentPage: 1),
    );
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
    final role = Teacher.fromJson(arg.teacher).role.toLowerCase();
    return ClassLoaderHelper.loadClasses(
      currentState: currentState,
      ref: ref,
      teacherId: Teacher.fromJson(arg.teacher).id,
      teacherRole: role,
      resetPage: resetPage,
      useCache: useCache,
    );
  }

  Future<void> loadMoreClasses() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMoreData) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        isLoadingMore: true,
        currentPage: current.currentPage + 1,
      ),
    );
    state = AsyncData(await _loadClasses(resetPage: false, useCache: false));
  }

  Future<void> loadSubjects({bool useCache = true}) async {
    final currentState = state.value;
    if (currentState == null) return;

    final role = Teacher.fromJson(arg.teacher).role.toLowerCase();
    final newState = await SubjectLoaderHelper.loadSubjects(
      currentState: currentState,
      ref: ref,
      teacherId: Teacher.fromJson(arg.teacher).id,
      teacherRole: role,
      useCache: useCache,
    );
    state = AsyncData(newState);
  }

  /// Refreshes today's schedules into state (safe to call after build).
  Future<void> loadTodaySchedules() async {
    _todaySchedulesCache = await ScheduleLoaderHelper.preloadTodaySchedules(
      ref,
      Teacher.fromJson(arg.teacher).id,
    );
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(
        currentState.copyWith(todaySchedules: _todaySchedulesCache),
      );
    }
  }
}
