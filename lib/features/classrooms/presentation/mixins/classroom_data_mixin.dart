import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/classrooms/presentation/controllers/admin_classroom_controller.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';

/// Mixin for data loading operations (API calls, pagination, search).
///
/// Provides methods for loading classes, teachers, pagination, and
/// refresh operations. Assumes the State class provides:
/// - setState()
/// - context
/// - ref
/// - mounted property
mixin ClassroomDataMixin on ConsumerState<AdminClassManagementScreen> {
  // Abstract state fields that must be provided by the State class
  List<dynamic> get classes;
  set classes(List<dynamic> value);

  List<dynamic> get teachers;
  set teachers(List<dynamic> value);

  bool get isLoading;
  set isLoading(bool value);

  String? get errorMessage;
  set errorMessage(String? value);

  int get currentPage;
  set currentPage(int value);

  int get perPage;

  bool get hasMoreData;
  set hasMoreData(bool value);

  bool get isLoadingMore;
  set isLoadingMore(bool value);

  bool get isMounted => mounted;

  ScrollController get scrollController;

  TextEditingController get searchController;

  String? get selectedGradeFilter;
  String? get selectedHomeroomFilter;

  /// Loads school settings and populates available grade levels.
  Future<void> loadSchoolSettings() async {
    final result = await ref
        .read(adminClassroomControllerProvider)
        .loadSchoolSettings();
    if (!isMounted) return;
    setState(() {
      // Grade levels are handled by controller
      AppLogger.debug('classroom', 'School settings loaded');
    });
  }

  /// Fetches and updates the teacher list.
  Future<void> fetchTeachers() async {
    final teacherList = await ref
        .read(adminClassroomControllerProvider)
        .fetchTeachers();
    if (!isMounted) return;
    setState(() => teachers = teacherList);
  }

  /// Loads or reloads the paginated class list.
  Future<void> loadData({bool resetPage = true, bool useCache = true}) async {
    if (resetPage && classes.isEmpty && isMounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
        currentPage = 1;
        hasMoreData = true;
      });
    } else if (resetPage) {
      currentPage = 1;
      hasMoreData = true;
    }

    final result = await ref
        .read(adminClassroomControllerProvider)
        .loadData(
          currentPage: currentPage,
          perPage: perPage,
          existingClasses: classes,
          selectedGradeFilter: selectedGradeFilter,
          selectedHomeroomFilter: selectedHomeroomFilter,
          searchText: searchController.text,
          resetPage: resetPage,
          useCache: useCache,
        );

    if (!isMounted) return;

    setState(() {
      classes = result.classes;
      hasMoreData = result.hasMoreData;
      isLoading = false;
      if (result.errorMessage != null) {
        errorMessage = result.errorMessage;
      }
    });

    if (result.errorMessage != null && classes.isNotEmpty) {
      final errorPrefix = ref.read(languageRiverpod).getTranslatedText({
        'en': 'Failed to load classes',
        'id': 'Gagal memuat data kelas',
      });
      SnackBarUtils.showError(context, '$errorPrefix: ${result.errorMessage}');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted) onDataLoaded();
    });
  }

  /// Clears cache and forces a full reload from the API.
  Future<void> forceRefresh() async {
    final result = await ref
        .read(adminClassroomControllerProvider)
        .forceRefresh(
          perPage: perPage,
          selectedGradeFilter: selectedGradeFilter,
          selectedHomeroomFilter: selectedHomeroomFilter,
          searchText: searchController.text,
        );
    if (!isMounted) return;
    setState(() {
      classes = result.classes;
      hasMoreData = result.hasMoreData;
      isLoading = false;
      currentPage = 1;
      errorMessage = result.errorMessage;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted) onDataLoaded();
    });
  }

  /// Pull-to-refresh handler.
  Future<void> onRefresh() async {
    await loadData(resetPage: true, useCache: false);
  }

  /// Appends the next page of classes to the list.
  Future<void> loadMoreData() async {
    if (isLoadingMore || !hasMoreData) return;
    setState(() => isLoadingMore = true);

    final result = await ref
        .read(adminClassroomControllerProvider)
        .loadMoreData(
          nextPage: currentPage + 1,
          perPage: perPage,
          existingClasses: classes,
          selectedGradeFilter: selectedGradeFilter,
          selectedHomeroomFilter: selectedHomeroomFilter,
          searchText: searchController.text,
        );

    if (!isMounted) return;
    setState(() {
      classes = result.classes;
      hasMoreData = result.hasMoreData;
      isLoadingMore = false;
      if (result.errorMessage == null) currentPage++;
    });

    if (result.errorMessage != null) {
      AppLogger.error('classroom', 'Load more error: ${result.errorMessage}');
    }
  }

  /// Exports the current class list to Excel.
  Future<void> exportToExcel() async {
    await ref
        .read(adminClassroomControllerProvider)
        .exportToExcel(classes: classes, context: context);
  }

  /// Imports classes from Excel file.
  Future<void> importFromExcel() async {
    final success = await ref
        .read(adminClassroomControllerProvider)
        .importFromExcel(context);
    if (success) await loadData();
  }

  /// Downloads the Excel import template.
  Future<void> downloadTemplate() async {
    await ref.read(adminClassroomControllerProvider).downloadTemplate(context);
  }

  /// Called after data is loaded (hook for tour, etc.).
  void onDataLoaded();
}
