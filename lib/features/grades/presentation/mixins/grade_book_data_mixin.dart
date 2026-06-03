import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_controller.dart';
import 'package:manajemensekolah/features/grades/domain/models/grade_book_models.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';

/// Mixin that handles all data loading operations for the grade book.
/// Extracted from inline methods to reduce class complexity.
mixin GradeBookDataMixin on ConsumerState<GradeBookPage> {
  // Abstract getters/setters bridging state
  List<Student> get studentList;
  set studentList(List<Student> v);

  List<Student> get filteredStudentList;
  set filteredStudentList(List<Student> v);

  List<Map<String, dynamic>> get gradeList;
  set gradeList(List<Map<String, dynamic>> v);

  Map<String, List<Map<String, dynamic>>> get assessmentHeaders;
  set assessmentHeaders(Map<String, List<Map<String, dynamic>>> v);

  bool get isLoading;
  set isLoading(bool v);

  List<String> get allGradeTypeList;

  TextEditingController get searchController;

  Map<String, bool> get gradeTypeFilter;
  List<String> get filteredGradeTypeList;
  set filteredGradeTypeList(List<String> v);

  /// Applies a [LoadDataResult] into local state fields.
  void applyLoadResult(LoadDataResult result) {
    studentList = result.studentList;
    filteredStudentList = result.filteredStudentList;
    gradeList = result.gradeList;
    assessmentHeaders = result.assessmentHeaders;
    isLoading = result.isLoading;
  }

  /// Loads student list and grade data from API with caching.
  /// Uses cache-first strategy; falls back to API on cache miss.
  Future<void> loadData({
    required Map<String, dynamic> teacher,
    required Map<String, dynamic> subject,
    required Map<String, dynamic> classData,
    bool showLoading = true,
    bool useCache = true,
  }) async {
    if (!mounted) return;

    if (showLoading && studentList.isEmpty) {
      setState(() => isLoading = true);
    }

    final ctrl = ref.read(gradeBookControllerProvider);
    final result = await ctrl.loadData(
      teacher: teacher,
      subject: subject,
      classData: classData,
      allGradeTypeList: allGradeTypeList,
      showLoading: showLoading,
      useCache: useCache,
    );

    if (!mounted) return;

    if (result.error != null) {
      if (studentList.isEmpty) setState(() => isLoading = false);
      showErrorSnackBar(result.error!);
      return;
    }

    setState(() => applyLoadResult(result));
    filterStudents();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onDataLoaded();
    });
  }

  /// Filters student list by search query.
  void filterStudents() {
    setState(() {
      filteredStudentList = ref
          .read(gradeBookControllerProvider)
          .filterStudents(studentList, searchController.text);
    });
  }

  /// Updates filtered grade types based on the current filter settings.
  void updateFilteredGradeTypes() {
    setState(() {
      filteredGradeTypeList = ref
          .read(gradeBookControllerProvider)
          .computeFilteredGradeTypes(allGradeTypeList, gradeTypeFilter);
    });
  }

  /// Loads the view preference (card view vs table view) from cache.
  Future<void> loadViewPreference() async {
    try {
      final cached = await LocalCacheService.load('buku_nilai_view_preference');
      if (cached is Map && mounted) {
        setCardViewMode(cached['is_card_view'] ?? true);
      }
    } catch (_) {}
  }

  /// Sets the card view mode and saves to cache.
  void setCardViewMode(bool isCardView);

  /// Called after data is loaded. Subclass can override to show tour, etc.
  void onDataLoaded() {}

  /// Show error snackbar.
  void showErrorSnackBar(String message);

  /// Show success snackbar.
  void showSuccessSnackBar(String message);
}
