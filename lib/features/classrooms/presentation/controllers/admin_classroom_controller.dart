// Controller for AdminClassManagementScreen.
//
// Like a Laravel Controller class that handles the business logic for
// a resource — this owns all data-fetching, cache reads/writes, and
// pure helper methods, so the Screen (View) only has to call these
// methods and call setState() with the returned results.
//
// Pattern: plain Dart class + Riverpod Provider (not a Notifier) so the
// Screen can grab it via `ref.read(adminClassroomControllerProvider)` and
// call individual methods ad-hoc — the same way you'd inject a service in Vue.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/classrooms/exports/classroom_export_service.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';

/// Riverpod Provider — like a Laravel service container binding.
/// The Screen reads this once with `ref.read(adminClassroomControllerProvider)`.
final adminClassroomControllerProvider =
    Provider<AdminClassroomController>(AdminClassroomController.new);

/// Result object returned by [AdminClassroomController.loadData] and
/// [AdminClassroomController.loadMoreData].
///
/// Like a Laravel Resource or DTO — bundles the API response fields that
/// the Screen needs to update its local state in one go.
class ClassLoadResult {
  final List<dynamic> classes;
  final bool hasMoreData;
  final bool isLoading;
  final String? errorMessage;

  const ClassLoadResult({
    required this.classes,
    required this.hasMoreData,
    this.isLoading = false,
    this.errorMessage,
  });
}

/// Result returned by [AdminClassroomController.loadSchoolSettings].
class SchoolSettingsResult {
  final String? jenjang;
  final List<String> gradeLevels;

  const SchoolSettingsResult({required this.jenjang, required this.gradeLevels});
}

/// Owns all data-fetching and pure helpers for the classroom management screen.
///
/// Think of this like a Laravel Controller injected with repositories — it
/// knows how to talk to the API and cache, but it never touches the widget
/// tree (no `setState`, no `context.mounted`, no Navigator calls).
class AdminClassroomController {
  /// [Ref] is Riverpod's base reference type — works whether the controller is
  /// constructed inside a `Provider` (gives `ProviderRef`) or called from a
  /// widget via `ref.read(...)` (gives `WidgetRef`). Both extend `Ref`.
  final Ref ref;

  const AdminClassroomController(this.ref);

  // ---------------------------------------------------------------------------
  // Cache Key Builder
  // ---------------------------------------------------------------------------

  /// Builds the local-cache key for the default (unfiltered, page-1) class list.
  ///
  /// Returns `null` when any filter/search/pagination is active — matching the
  /// original screen behaviour of only caching the "clean first page" view.
  String? buildClassCacheKey({
    required int currentPage,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) {
    // Only cache default first-page view (no filters/search) for fast reload
    if (currentPage != 1) return null;
    if (selectedGradeFilter != null ||
        selectedHomeroomFilter != null ||
        searchText.trim().isNotEmpty) {
      return null;
    }

    final academicYearProvider = ref.read(academicYearRiverpod);
    final yearId =
        academicYearProvider.selectedAcademicYear?['id']?.toString() ??
        'default';
    return 'class_list_$yearId';
  }

  // ---------------------------------------------------------------------------
  // Pure Helper / Utility Methods
  // ---------------------------------------------------------------------------

  /// Returns `true` when any filter is currently active.
  ///
  /// Pure function — no side-effects, just reads the two filter values the
  /// Screen passes in (like a Vue computed property).
  bool checkActiveFilter({
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
  }) {
    return selectedGradeFilter != null || selectedHomeroomFilter != null;
  }

  /// Builds the chip data list for active filters shown in the header bar.
  ///
  /// Returns a list of `{label, onRemove}` maps — the Screen renders them as
  /// [Chip] widgets and supplies the `setState` callbacks via [onRemoveGrade]
  /// and [onRemoveHomeroom].
  List<Map<String, dynamic>> buildFilterChips({
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required LanguageProvider languageProvider,
    required VoidCallback onRemoveGrade,
    required VoidCallback onRemoveHomeroom,
  }) {
    final List<Map<String, dynamic>> filterChips = [];

    if (selectedGradeFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})}: $selectedGradeFilter',
        'onRemove': onRemoveGrade,
      });
    }

    if (selectedHomeroomFilter != null) {
      String label;
      if (selectedHomeroomFilter == 'true') {
        label = languageProvider.getTranslatedText({
          'en': 'Has Homeroom Teacher',
          'id': 'Sudah Ada Wali Kelas',
        });
      } else {
        label = languageProvider.getTranslatedText({
          'en': 'No Homeroom Teacher',
          'id': 'Belum Ada Wali Kelas',
        });
      }

      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $label',
        'onRemove': onRemoveHomeroom,
      });
    }

    return filterChips;
  }

  /// Converts a numeric grade level to a human-readable string
  /// (e.g. `7` → `"Kelas 7 SMP"`).
  String getGradeLevelText(
    dynamic gradeLevel,
    LanguageProvider languageProvider,
  ) {
    if (gradeLevel == null) return '-';

    final level = int.tryParse(gradeLevel.toString());
    if (level == null) return '-';

    if (level <= 6) {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SD';
    } else if (level <= 9) {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SMP';
    } else {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SMA';
    }
  }

  /// Returns the role-based primary colour for the admin role.
  ///
  /// Extracted as a method so the Screen and its widgets share one source of
  /// truth — like a CSS variable in a Vue component.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  // ---------------------------------------------------------------------------
  // Grade Level Generator
  // ---------------------------------------------------------------------------

  /// Generates the list of grade level strings based on [jenjang].
  ///
  /// Like a pure PHP helper that maps 'SD' → [1..6], 'SMP' → [7..9], etc.
  List<String> generateGradeLevels(String? jenjang) {
    int start = 1;
    int end = 12;

    if (jenjang != null) {
      final j = jenjang.toUpperCase();
      if (j == 'SD') {
        start = 1;
        end = 6;
      } else if (j == 'SMP') {
        start = 7;
        end = 9;
      } else if (j == 'SMA' || j == 'SMK') {
        start = 10;
        end = 12;
      }
    }

    return List.generate(end - start + 1, (i) => (start + i).toString());
  }

  // ---------------------------------------------------------------------------
  // API / Data Methods
  // ---------------------------------------------------------------------------

  /// Loads school settings (jenjang) with cache-first strategy.
  ///
  /// Returns a [SchoolSettingsResult] — the Screen calls `setState` with the
  /// fields inside.  Like a Laravel action that returns a DTO instead of
  /// redirecting.
  Future<SchoolSettingsResult> loadSchoolSettings() async {
    const cacheKey = 'school_settings';

    // ─── Cache-first ───
    try {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null) {
        final jenjang = cached['jenjang'] as String?;
        AppLogger.info('classroom', 'School settings loaded from cache');
        return SchoolSettingsResult(
          jenjang: jenjang,
          gradeLevels: generateGradeLevels(jenjang),
        );
      }
    } catch (e) {
      AppLogger.error('classroom', 'School settings cache load failed: $e');
    }

    // ─── API fallback ───
    try {
      final settings = await getIt<ApiSettingsService>().getSchoolSettings();
      final jenjang = settings['jenjang'] as String?;
      // Non-blocking cache save
      LocalCacheService.save(cacheKey, settings);
      return SchoolSettingsResult(
        jenjang: jenjang,
        gradeLevels: generateGradeLevels(jenjang),
      );
    } catch (e) {
      AppLogger.error('classroom', 'Error loading school settings: $e');
      // Fallback to defaults on error
      return SchoolSettingsResult(jenjang: null, gradeLevels: generateGradeLevels(null));
    }
  }

  /// Loads the full teacher list with cache-first strategy.
  ///
  /// Returns the raw list — Screen calls `setState(() => _teachers = result)`.
  Future<List<dynamic>> fetchTeachers() async {
    const cacheKey = 'teachers_all_list';

    // ─── Cache-first ───
    try {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null) {
        final teachers = List<dynamic>.from(cached);
        AppLogger.info(
          'classroom',
          'Teachers list loaded from cache (${teachers.length})',
        );
        return teachers;
      }
    } catch (e) {
      AppLogger.error('classroom', 'Teachers list cache load failed: $e');
    }

    // ─── API ───
    final response = await getIt<ApiTeacherService>().getTeachersPaginated(
      limit: 1000,
    );
    final teachers = List<dynamic>.from(response['data'] ?? []);
    // Non-blocking cache save
    LocalCacheService.save(cacheKey, teachers);
    AppLogger.info(
      'classroom',
      'Loaded ${teachers.length} teachers for wali kelas selection',
    );
    return teachers;
  }

  /// Loads (or reloads) the paginated class list from cache then API.
  ///
  /// - [resetPage] = true → discard existing list, start from page 1 (like a
  ///   fresh Vue `fetch()` call).
  /// - [useCache] = false → force an API hit (used by pull-to-refresh and
  ///   force-refresh menu action).
  ///
  /// Returns a [ClassLoadResult] containing the new list + pagination flags.
  /// The Screen then calls `setState` with those values — keeping UI logic in
  /// the Screen and data logic here.
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
    try {
      if (resetPage) {
        // ─── Step 1: Try loading from cache for instant display ───
        if (useCache) {
          final cacheKey = buildClassCacheKey(
            currentPage: 1,
            selectedGradeFilter: selectedGradeFilter,
            selectedHomeroomFilter: selectedHomeroomFilter,
            searchText: searchText,
          );
          if (cacheKey != null) {
            try {
              final cached = await LocalCacheService.load(
                cacheKey,
                ttl: const Duration(hours: 3),
              );
              if (cached != null) {
                final cachedData = Map<String, dynamic>.from(cached);
                AppLogger.info('classroom', 'Classes loaded from cache');
                return ClassLoadResult(
                  classes: List<dynamic>.from(cachedData['classes'] ?? []),
                  hasMoreData:
                      cachedData['pagination']?['has_next_page'] ?? false,
                  isLoading: false,
                );
              }
            } catch (e) {
              AppLogger.error('classroom', 'Class cache load failed: $e');
            }
          }
        }
      }

      // ─── Step 2: Fetch fresh data from API ───
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();

      final int page = resetPage ? 1 : currentPage;

      final response = await getIt<ApiClassService>().getClassPaginated(
        page: page,
        limit: perPage,
        gradeLevel: selectedGradeFilter,
        hasHomeroomTeacher: selectedHomeroomFilter,
        academicYearId: selectedYearId,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
        useCache: useCache,
      );

      // ─── Step 3: Save to cache (only for default view) ───
      final cacheKey = buildClassCacheKey(
        currentPage: 1,
        selectedGradeFilter: selectedGradeFilter,
        selectedHomeroomFilter: selectedHomeroomFilter,
        searchText: searchText,
      );
      if (cacheKey != null && resetPage) {
        LocalCacheService.save(cacheKey, {
          'classes': response['data'] ?? [],
          'pagination': response['pagination'],
        });
      }

      return ClassLoadResult(
        classes: List<dynamic>.from(response['data'] ?? []),
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('classroom', 'Load classes error: $e');
      return ClassLoadResult(
        classes: resetPage ? [] : existingClasses,
        hasMoreData: false,
        isLoading: false,
        errorMessage: existingClasses.isEmpty
            ? ErrorUtils.getFriendlyMessage(e)
            : null,
      );
    }
  }

  /// Loads the next page of classes and returns it appended to [existingClasses].
  ///
  /// Like a Laravel cursor paginator — returns the combined list so the Screen
  /// can do a single `setState`.
  Future<ClassLoadResult> loadMoreData({
    required int nextPage,
    required int perPage,
    required List<dynamic> existingClasses,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) async {
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();

      final response = await getIt<ApiClassService>().getClassPaginated(
        page: nextPage,
        limit: perPage,
        gradeLevel: selectedGradeFilter,
        hasHomeroomTeacher: selectedHomeroomFilter,
        academicYearId: selectedYearId,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      final newItems = List<dynamic>.from(response['data'] ?? []);
      AppLogger.info(
        'classroom',
        'Loaded more data: Page $nextPage, New items: ${newItems.length}',
      );

      return ClassLoadResult(
        classes: [...existingClasses, ...newItems],
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('classroom', 'Error loading more data: $e');
      // Return the original list unchanged — caller reverts page increment
      return ClassLoadResult(
        classes: existingClasses,
        hasMoreData: true, // keep trying
        isLoading: false,
        errorMessage: ErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  /// Clears the class list cache and reloads everything from the API.
  ///
  /// Also clears school settings, teachers, and tour caches — like a full
  /// `php artisan cache:clear` for this screen.
  Future<ClassLoadResult> forceRefresh({
    required int perPage,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) async {
    final cacheKey = buildClassCacheKey(
      currentPage: 1,
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
    );
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_class_management_');
    await LocalCacheService.invalidate('school_settings');
    await LocalCacheService.invalidate('teachers_all_list');

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

  /// Pull-to-refresh: bypass cache and reload page 1.
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

  // ---------------------------------------------------------------------------
  // Data Manipulation
  // ---------------------------------------------------------------------------

  /// Deletes a class after showing a confirmation dialog.
  ///
  /// Returns `true` if the deletion succeeded, `false` if the user cancelled
  /// or if an error occurred (snackbar is shown in both error cases).
  ///
  /// The Screen calls `_loadData()` when this returns `true` — keeping
  /// navigation/reload logic in the Screen.
  Future<bool> deleteClass(
    Map<String, dynamic> classData,
    BuildContext context,
  ) async {
    final languageProvider = ref.read(languageRiverpod);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: languageProvider.getTranslatedText({
          'en': 'Delete Class',
          'id': 'Hapus Kelas',
        }),
        content: languageProvider.getTranslatedText({
          'en': 'Are you sure you want to delete this class?',
          'id': 'Yakin ingin menghapus kelas ini?',
        }),
        confirmText: languageProvider.getTranslatedText({
          'en': 'Delete',
          'id': 'Hapus',
        }),
        confirmColor: Colors.red,
      ),
    );

    if (confirmed != true) return false;

    try {
      await getIt<ApiClassService>().deleteClass(classData['id'].toString());
      if (context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': 'Class successfully deleted',
            'id': 'Kelas berhasil dihapus',
          }),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          '${languageProvider.getTranslatedText({'en': 'Gagal menghapus kelas', 'id': 'Gagal menghapus kelas'})}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
      return false;
    }
  }

  /// Exports the current [classes] list to an Excel file.
  Future<void> exportToExcel({
    required List<dynamic> classes,
    required BuildContext context,
  }) async {
    await ExcelClassService.exportClassesToExcel(
      classes: classes,
      context: context,
    );
  }

  /// Opens a file picker, imports an Excel file, and returns `true` on success.
  ///
  /// The Screen reloads data when this returns `true`.
  Future<bool> importFromExcel(BuildContext context) async {
    final languageProvider = ref.read(languageRiverpod);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiClassService>().importClassesFromExcel(
          File(result.files.single.path!),
        );
        return true;
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          '${languageProvider.getTranslatedText({'en': 'Gagal mengimpor file', 'id': 'Gagal mengimpor file'})}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
      return false;
    }
  }

  /// Downloads the Excel import template.
  Future<void> downloadTemplate(BuildContext context) async {
    await ExcelClassService.downloadTemplate(context);
  }

  // ---------------------------------------------------------------------------
  // Clear Filters (data-side of the clear action)
  // ---------------------------------------------------------------------------

  /// Returns the reset filter values — Screen calls `setState` with these and
  /// then triggers a data reload.
  ///
  /// Separated from the Screen's `setState` so the controller owns the "what
  /// are the default filter values?" knowledge.
  ({String? gradeFilter, String? homeroomFilter, bool hasActiveFilter})
  clearAllFilters() {
    return (gradeFilter: null, homeroomFilter: null, hasActiveFilter: false);
  }
}
