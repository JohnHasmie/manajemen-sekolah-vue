// Admin student controller — data/logic layer extracted from
// AdminStudentManagementScreen.
//
// Mirrors the pattern in `teacher_grade_controller.dart`: a plain Dart class
// that owns all API calls, cache reads/writes, and pure helpers.
// The screen keeps setState, UI builders, and dialog/navigation methods.
//
// In Laravel terms: this is the Controller; the screen is the Blade View.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/helpers/student_cache_helper.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/helpers/student_data_helper.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/helpers/student_deletion_helper.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/helpers/student_excel_helper.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/helpers/student_filter_helper.dart';

/// Riverpod provider — like a Laravel service-container binding.
/// The screen does: `ref.read(adminStudentControllerProvider)` to get
/// the singleton controller for this widget tree.
final adminStudentControllerProvider = Provider<AdminStudentController>(
  AdminStudentController.new,
);

/// Result object returned by [AdminStudentController.loadData].
/// Carries every piece of state that the screen needs to apply via setState().
/// Think of it as the JSON payload your Laravel controller returns to the view.
class StudentLoadResult {
  final List<dynamic> students;
  final List<dynamic> classList;
  final bool hasMoreData;
  final bool isLoading;
  final String? errorMessage;

  const StudentLoadResult({
    required this.students,
    required this.classList,
    required this.hasMoreData,
    required this.isLoading,
    this.errorMessage,
  });
}

/// Result object returned by [AdminStudentController.loadMoreData].
class StudentLoadMoreResult {
  final List<dynamic> additionalStudents;
  final bool hasMoreData;

  const StudentLoadMoreResult({
    required this.additionalStudents,
    required this.hasMoreData,
  });
}

/// Result object returned by [AdminStudentController.loadFilterOptions].
class FilterOptionsResult {
  final List<String> gradeLevels;
  final List<dynamic> availableClass;

  const FilterOptionsResult({
    required this.gradeLevels,
    required this.availableClass,
  });
}

/// Plain Dart class — no State, no BuildContext stored as a field.
/// Receives [Ref] (Riverpod base type common to both provider refs and
/// [WidgetRef]) so it can read providers from inside a Provider<> or from a
/// widget. Methods that need to show snackbars or dialogs receive
/// [BuildContext] as a parameter (passed in from the screen at call-time),
/// following Flutter's best practice of not storing context across async gaps.
class AdminStudentController {
  final Ref ref;

  AdminStudentController(this.ref);

  // ---------------------------------------------------------------------------
  // Cache-key builder
  // ---------------------------------------------------------------------------

  /// Returns the cache key for the current first-page default view, or null
  /// if any filter/search is active (those results are not cached).
  /// Only caches page-1, no-filter views — like HTTP cache-control: max-age.
  String? buildStudentCacheKey({
    required int currentPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
  }) {
    return StudentCacheHelper.buildStudentCacheKey(
      ref: ref,
      currentPage: currentPage,
      selectedClassIds: selectedClassIds,
      selectedGradeLevel: selectedGradeLevel,
      selectedGenderFilter: selectedGenderFilter,
      selectedGuardian: selectedGuardian,
      selectedStatusFilter: selectedStatusFilter,
      searchText: searchText,
    );
  }

  // ---------------------------------------------------------------------------
  // Filter helpers (pure — no setState, no context)
  // ---------------------------------------------------------------------------

  /// Returns true if any filter or search text is currently active.
  /// Screen calls this and stores the result in [_hasActiveFilter] via
  /// setState.
  bool checkActiveFilter({
    required String? selectedStatusFilter,
    required List<String> selectedClassIds,
    required String? selectedGenderFilter,
    required String? selectedGradeLevel,
    required String? selectedGuardian,
    required String searchText,
  }) {
    return StudentFilterHelper.checkActiveFilter(
      selectedStatusFilter: selectedStatusFilter,
      selectedClassIds: selectedClassIds,
      selectedGenderFilter: selectedGenderFilter,
      selectedGradeLevel: selectedGradeLevel,
      selectedGuardian: selectedGuardian,
      searchText: searchText,
    );
  }

  /// Builds the typed active-filter chip list for the header bar.
  ///
  /// Each chip carries a per-filter removal callback — tapping the × on
  /// a class chip removes that specific class only, not all filters.
  List<ActiveFilter> buildFilterChips({
    required String? selectedStatusFilter,
    required List<String> selectedClassIds,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required List<dynamic> classList,
    required LanguageProvider languageProvider,
    required VoidCallback onClearStatus,
    required void Function(String classId) onClearClass,
    required VoidCallback onClearGender,
    required VoidCallback onClearGuardian,
  }) {
    return StudentFilterHelper.buildFilterChips(
      selectedStatusFilter: selectedStatusFilter,
      selectedClassIds: selectedClassIds,
      selectedGenderFilter: selectedGenderFilter,
      selectedGuardian: selectedGuardian,
      classList: classList,
      languageProvider: languageProvider,
      onClearStatus: onClearStatus,
      onClearClass: onClearClass,
      onClearGender: onClearGender,
      onClearGuardian: onClearGuardian,
    );
  }

  /// Returns translated gender display text for a gender code.
  String getGenderText(String? gender, LanguageProvider languageProvider) {
    return StudentFilterHelper.getGenderText(gender, languageProvider);
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  /// Loads the first page of students and the class list.
  /// Returns a [StudentLoadResult] — the screen applies it with setState.
  ///
  /// [cacheKeyArgs] encapsulates all current filter/search state so the
  /// controller can decide whether to read/write cache without holding
  /// a reference to the screen's state fields.
  Future<StudentLoadResult> loadData({
    required bool resetPage,
    required bool useCache,
    required int currentPage,
    required int perPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
  }) async {
    return StudentDataHelper.loadData(
      ref: ref,
      resetPage: resetPage,
      useCache: useCache,
      currentPage: currentPage,
      perPage: perPage,
      selectedClassIds: selectedClassIds,
      selectedGradeLevel: selectedGradeLevel,
      selectedGenderFilter: selectedGenderFilter,
      selectedGuardian: selectedGuardian,
      selectedStatusFilter: selectedStatusFilter,
      searchText: searchText,
      buildCacheKey: () => buildStudentCacheKey(
        currentPage: currentPage,
        selectedClassIds: selectedClassIds,
        selectedGradeLevel: selectedGradeLevel,
        selectedGenderFilter: selectedGenderFilter,
        selectedGuardian: selectedGuardian,
        selectedStatusFilter: selectedStatusFilter,
        searchText: searchText,
      ),
    );
  }

  /// Loads the next page of students for infinite scroll.
  /// Returns a [StudentLoadMoreResult] — screen appends to its list via
  /// setState.
  Future<StudentLoadMoreResult?> loadMoreData({
    required int nextPage,
    required int perPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
  }) async {
    return StudentDataHelper.loadMoreData(
      ref: ref,
      nextPage: nextPage,
      perPage: perPage,
      selectedClassIds: selectedClassIds,
      selectedGradeLevel: selectedGradeLevel,
      selectedGenderFilter: selectedGenderFilter,
      selectedGuardian: selectedGuardian,
      selectedStatusFilter: selectedStatusFilter,
      searchText: searchText,
    );
  }

  /// Loads filter options (grade levels + classes) — tries cache first.
  /// Returns [FilterOptionsResult] — screen applies via setState.
  Future<FilterOptionsResult?> loadFilterOptions() async {
    return StudentDataHelper.loadFilterOptions();
  }

  /// Force-refresh: clears relevant caches then triggers a full reload.
  /// The screen passes current filter state so buildStudentCacheKey can find
  /// the right key.
  Future<void> forceRefreshCaches({
    required int currentPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
  }) async {
    return StudentCacheHelper.forceRefreshCaches(
      ref: ref,
      currentPage: currentPage,
      selectedClassIds: selectedClassIds,
      selectedGradeLevel: selectedGradeLevel,
      selectedGenderFilter: selectedGenderFilter,
      selectedGuardian: selectedGuardian,
      selectedStatusFilter: selectedStatusFilter,
      searchText: searchText,
    );
  }

  // ---------------------------------------------------------------------------
  // Data manipulation
  // ---------------------------------------------------------------------------

  /// Deletes a student after showing a confirmation dialog.
  /// Returns true if deleted successfully, false if cancelled or failed.
  /// Screen calls loadData() and shows snackbar after getting true.
  Future<bool> deleteStudent(
    Map<String, dynamic> student,
    BuildContext context,
  ) async {
    return StudentDeletionHelper.deleteStudent(student, context, ref);
  }

  /// Exports students matching current filters to an Excel file.
  Future<void> exportToExcel({
    required BuildContext context,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String searchText,
  }) async {
    return StudentExcelHelper.exportToExcel(
      ref: ref,
      context: context,
      selectedClassIds: selectedClassIds,
      selectedGradeLevel: selectedGradeLevel,
      selectedGenderFilter: selectedGenderFilter,
      searchText: searchText,
    );
  }

  /// Lets the user pick an Excel file and imports it.
  /// Returns true if import succeeded (screen can reload), false on
  /// cancel/error.
  Future<bool> importFromExcel(BuildContext context) async {
    return StudentExcelHelper.importFromExcel(context, ref);
  }

  /// Downloads the import template Excel file.
  Future<void> downloadTemplate(BuildContext context) async {
    return StudentExcelHelper.downloadTemplate(context);
  }

  // ---------------------------------------------------------------------------
  // Navigation helper
  // ---------------------------------------------------------------------------

  /// Returns whether the current academic year is read-only.
  /// Screen uses this to decide whether to show edit/delete controls.
  bool get isReadOnly => ref.read(academicYearRiverpod).isReadOnly;
}
