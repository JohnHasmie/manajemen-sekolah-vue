// Controller for AdminClassManagementScreen.
//
// Like a Laravel Controller class that handles business logic for
// a resource — owns all data-fetching, cache reads/writes, and
// pure helpers. The Screen only calls these methods and updates
// local state with returned results.
//
// Pattern: plain Dart class + Riverpod Provider (not a Notifier) so
// the Screen can grab it via `ref.read(adminClassroomControllerProvider)`
// and call individual methods ad-hoc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/classrooms/presentation/'
    'controllers/helpers/classroom_cache_helper.dart';
import 'package:manajemensekolah/features/classrooms/presentation/'
    'controllers/helpers/classroom_data_service.dart';
import 'package:manajemensekolah/features/classrooms/presentation/'
    'controllers/helpers/classroom_deletion_helper.dart';
import 'package:manajemensekolah/features/classrooms/presentation/'
    'controllers/helpers/classroom_export_helper.dart';
import 'package:manajemensekolah/features/classrooms/presentation/'
    'controllers/helpers/classroom_filter_helper.dart';

/// Riverpod Provider — like a Laravel service container binding.
final adminClassroomControllerProvider = Provider<AdminClassroomController>(
  AdminClassroomController.new,
);

/// Main facade controller for classroom management.
///
/// Orchestrates helpers and delegates to specialized services. Public API
/// remains unchanged from original — all methods preserved with same
/// signatures and behavior.
class AdminClassroomController {
  final Ref ref;
  late final ClassroomFilterHelper _filterHelper;
  late final ClassroomCacheHelper _cacheHelper;
  late final ClassroomDataService _dataService;
  late final ClassroomExportHelper _exportHelper;
  late final ClassroomDeletionHelper _deletionHelper;

  AdminClassroomController(this.ref) {
    _filterHelper = ClassroomFilterHelper(ref);
    _cacheHelper = ClassroomCacheHelper(ref);
    _dataService = ClassroomDataService(
      generateGradeLevels: _filterHelper.generateGradeLevels,
    );
    _exportHelper = ClassroomExportHelper();
    _deletionHelper = ClassroomDeletionHelper(ref);
  }

  // ─────────────────────────────────────────────────────────────
  // Cache Key Building
  // ─────────────────────────────────────────────────────────────

  String? buildClassCacheKey({
    required int currentPage,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) {
    return _cacheHelper.buildClassCacheKey(
      currentPage: currentPage,
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Filter & UI Helpers
  // ─────────────────────────────────────────────────────────────

  bool checkActiveFilter({
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) {
    return _filterHelper.checkActiveFilter(
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
    );
  }

  List<Map<String, dynamic>> buildFilterChips({
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required LanguageProvider languageProvider,
    required VoidCallback onRemoveGrade,
    required VoidCallback onRemoveHomeroom,
  }) {
    return _filterHelper.buildFilterChips(
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      languageProvider: languageProvider,
      onRemoveGrade: onRemoveGrade,
      onRemoveHomeroom: onRemoveHomeroom,
    );
  }

  /// Builds typed [ActiveFilter] chips for [AdminCrudScaffold]'s header.
  ///
  /// Phase-1 chip builder — one chip per active filter, each with its own
  /// × removal callback. Preferred over [buildFilterChips] (map-based,
  /// kept only for backwards compat).
  List<ActiveFilter> buildActiveFilterChips({
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required LanguageProvider languageProvider,
    required VoidCallback onClearGrade,
    required VoidCallback onClearHomeroom,
  }) {
    return _filterHelper.buildActiveFilterChips(
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      languageProvider: languageProvider,
      onClearGrade: onClearGrade,
      onClearHomeroom: onClearHomeroom,
    );
  }

  String getGradeLevelText(
    dynamic gradeLevel,
    LanguageProvider languageProvider,
  ) {
    return _filterHelper.getGradeLevelText(gradeLevel, languageProvider);
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  List<String> generateGradeLevels(String? jenjang) {
    return _filterHelper.generateGradeLevels(jenjang);
  }

  // ─────────────────────────────────────────────────────────────
  // API / Data Methods
  // ─────────────────────────────────────────────────────────────

  Future<SchoolSettingsResult> loadSchoolSettings() async {
    return _dataService.loadSchoolSettings();
  }

  Future<List<dynamic>> fetchTeachers() async {
    return _dataService.fetchTeachers();
  }

  Future<ClassLoadResult> loadData({
    required int currentPage,
    required int perPage,
    required List<dynamic> existingClasses,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
    bool resetPage = true,
    bool useCache = true,
  }) async {
    final academicYearProvider = ref.read(academicYearRiverpod);
    final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
        ?.toString();

    final cacheKey = buildClassCacheKey(
      currentPage: 1,
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
    );

    return _dataService.loadData(
      currentPage: currentPage,
      perPage: perPage,
      existingClasses: existingClasses,
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
      selectedYearId: selectedYearId,
      cacheKey: cacheKey,
      resetPage: resetPage,
      useCache: useCache,
    );
  }

  Future<ClassLoadResult> loadMoreData({
    required int nextPage,
    required int perPage,
    required List<dynamic> existingClasses,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) async {
    final academicYearProvider = ref.read(academicYearRiverpod);
    final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
        ?.toString();

    return _dataService.loadMoreData(
      nextPage: nextPage,
      perPage: perPage,
      existingClasses: existingClasses,
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
      selectedYearId: selectedYearId,
    );
  }

  Future<ClassLoadResult> forceRefresh({
    required int perPage,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) async {
    await _cacheHelper.clearAllClassroomCaches(
      currentPage: 1,
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
    );

    return loadData(
      currentPage: 1,
      perPage: perPage,
      existingClasses: [],
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
      resetPage: true,
      useCache: false,
    );
  }

  Future<ClassLoadResult> onRefresh({
    required int perPage,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) {
    return loadData(
      currentPage: 1,
      perPage: perPage,
      existingClasses: [],
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
      resetPage: true,
      useCache: false,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Data Manipulation
  // ─────────────────────────────────────────────────────────────

  Future<bool> deleteClass(
    Map<String, dynamic> classData,
    BuildContext context,
  ) async {
    return _deletionHelper.deleteClass(
      classData,
      context,
      (classId) => _dataService.deleteClass(classId),
    );
  }

  Future<void> exportToExcel({
    required List<dynamic> classes,
    required BuildContext context,
  }) async {
    await _exportHelper.exportToExcel(classes: classes, context: context);
  }

  Future<bool> importFromExcel(BuildContext context) async {
    final languageProvider = ref.read(languageRiverpod);
    final errorMsg = languageProvider.getTranslatedText({
      'en': 'Gagal mengimpor file',
      'id': 'Gagal mengimpor file',
    });
    return _exportHelper.importFromExcel(context, errorMsg);
  }

  Future<void> downloadTemplate(BuildContext context) async {
    await _exportHelper.downloadTemplate(context);
  }

  // ─────────────────────────────────────────────────────────────
  // Filter Reset
  // ─────────────────────────────────────────────────────────────

  ({String? gradeFilter, String? homeroomFilter, bool hasActiveFilter})
  clearAllFilters() {
    return _filterHelper.clearAllFilters();
  }
}
