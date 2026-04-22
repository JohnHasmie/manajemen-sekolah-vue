import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';

/// Mixin for data loading and refresh operations.
///
/// Handles loading student data, pagination, cache refresh, and
/// integration with academic year changes.
mixin DataLoadingMixin on ConsumerState<StudentManagementScreen> {
  // Abstract properties to be implemented by state class
  abstract int currentPage;
  abstract int perPage;
  abstract bool isLoadingMore;
  abstract bool hasMoreData;
  abstract List<dynamic> students;
  abstract List<dynamic> classList;
  abstract List<String> selectedClassIds;
  abstract String? selectedGradeLevel;
  abstract String? selectedGenderFilter;
  abstract String? selectedGuardian;
  abstract String? selectedStatusFilter;
  abstract String searchText;

  TextEditingController get searchController;

  /// Public interface for mixins to call loadData
  Future<void> loadData({bool resetPage = true});

  /// Loads student data from API with filters and pagination.
  ///
  /// If [resetPage] is true, resets pagination to page 1.
  /// Uses cache by default unless [useCache] is false.
  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    final ctrl = ref.read(adminStudentControllerProvider);

    if (resetPage) {
      currentPage = 1;
      hasMoreData = true;
      if (students.isEmpty && mounted) {
        setState(() {});
      }
    }

    final result = await ctrl.loadData(
      resetPage: resetPage,
      useCache: useCache,
      currentPage: currentPage,
      perPage: perPage,
      selectedClassIds: selectedClassIds,
      selectedGradeLevel: selectedGradeLevel,
      selectedGenderFilter: selectedGenderFilter,
      selectedGuardian: selectedGuardian,
      selectedStatusFilter: selectedStatusFilter,
      searchText: searchController.text,
    );

    if (!mounted) return;

    setState(() {
      students = result.students;
      classList = result.classList;
      hasMoreData = result.hasMoreData;
    });
  }

  /// Loads the next page of students for infinite scroll.
  Future<void> loadMoreData() async {
    if (isLoadingMore || !hasMoreData) return;
    setState(() => isLoadingMore = true);

    final result = await ref
        .read(adminStudentControllerProvider)
        .loadMoreData(
          nextPage: currentPage + 1,
          perPage: perPage,
          selectedClassIds: selectedClassIds,
          selectedGradeLevel: selectedGradeLevel,
          selectedGenderFilter: selectedGenderFilter,
          selectedGuardian: selectedGuardian,
          selectedStatusFilter: selectedStatusFilter,
          searchText: searchController.text,
        );

    if (!mounted) return;

    if (result == null) {
      setState(() => isLoadingMore = false);
    } else {
      currentPage++;
      setState(() {
        students = [...students, ...result.additionalStudents];
        hasMoreData = result.hasMoreData;
        isLoadingMore = false;
      });
    }
  }

  /// Called when academic year changes - refreshes data.
  void onAcademicYearChanged() {
    if (mounted) {
      _loadData(resetPage: true);
    }
  }

  /// Forces refresh of all caches and reloads data.
  Future<void> forceRefresh() async {
    await ref
        .read(adminStudentControllerProvider)
        .forceRefreshCaches(
          currentPage: currentPage,
          selectedClassIds: selectedClassIds,
          selectedGradeLevel: selectedGradeLevel,
          selectedGenderFilter: selectedGenderFilter,
          selectedGuardian: selectedGuardian,
          selectedStatusFilter: selectedStatusFilter,
          searchText: searchController.text,
        );
    await _loadData(resetPage: true, useCache: false);
  }

  /// Refresh via RefreshIndicator - reloads without cache.
  Future<void> onRefresh() async {
    await _loadData(resetPage: true, useCache: false);
  }
}
