// Controller for AdminSubjectManagementScreen.
// Like a Vue Composition API `setup()` extracted into its own composable file,
// or a Laravel controller class extracted from a fat route closure.
//
// Holds all data-fetching, data-manipulation, and pure helper logic so that
// admin_subject_management_screen.dart only concerns itself with widget
// rendering and `setState` calls.
//
// Usage in screen:
//   final ctrl = ref.read(adminSubjectControllerProvider);

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/subjects/exports/subject_export_service.dart';

/// Riverpod provider for [AdminSubjectController].
/// Use `ref.read(adminSubjectControllerProvider)` from the screen.
///
/// This is a plain [Provider] (not AsyncNotifier) because the controller
/// does not own state — it just provides methods. State stays in the screen's
/// `setState` calls, matching the pattern used throughout this codebase for
/// ConsumerStatefulWidgets.
final adminSubjectControllerProvider =
    Provider<AdminSubjectController>(AdminSubjectController.new);

// ---------------------------------------------------------------------------
// Result types — plain objects returned by controller methods so the screen
// can apply them via setState without the controller ever calling setState.
// Think of these like DTOs from a Laravel Service returning structured data.
// ---------------------------------------------------------------------------

/// Result of [AdminSubjectController.loadSubjects] and
/// [AdminSubjectController.loadMoreSubjects].
/// The screen destructures each field and applies it via setState.
///
/// [errorMessage] is non-null when the load failed. The screen decides
/// whether to show an error screen or a snackbar — no BuildContext needed here.
class SubjectLoadResult {
  final List<dynamic> subjects;
  final bool hasMoreData;
  final bool isLoading;
  final String? errorMessage;

  /// Extracted filter options from the loaded data.
  final List<String> availableClassNames;
  final List<String> availableGradeLevels;

  const SubjectLoadResult({
    required this.subjects,
    required this.hasMoreData,
    required this.isLoading,
    required this.availableClassNames,
    required this.availableGradeLevels,
    this.errorMessage,
  });

  /// Convenience constructor for error-only results — nothing to render.
  SubjectLoadResult.failure(String message)
      : subjects = const [],
        hasMoreData = false,
        isLoading = false,
        availableClassNames = const [],
        availableGradeLevels = const [],
        errorMessage = message;
}

/// Result of [AdminSubjectController.loadMoreSubjects].
/// Only carries the incremental additions — the screen appends them to its
/// existing list via setState.
class SubjectLoadMoreResult {
  final List<dynamic> additionalSubjects;
  final bool hasMoreData;
  final List<String> availableClassNames;
  final List<String> availableGradeLevels;
  final String? errorMessage;

  const SubjectLoadMoreResult({
    required this.additionalSubjects,
    required this.hasMoreData,
    required this.availableClassNames,
    required this.availableGradeLevels,
    this.errorMessage,
  });
}

/// Result of [AdminSubjectController.loadFilterOptions].
class SubjectFilterOptionsResult {
  final bool success;

  const SubjectFilterOptionsResult({required this.success});
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Plain Dart class that holds all data/logic for [SubjectManagementScreen].
///
/// Analogy for a Laravel developer: this is the Controller class that was
/// previously inlined inside the View (admin_subject_management_screen.dart).
/// It receives `ref` (like Laravel's DI container) so it can read Riverpod
/// providers without ever owning widget state.
///
/// Methods that must show snackbars or dialogs receive [BuildContext] as a
/// parameter (passed in from the screen at call-time), following Flutter's
/// "don't store BuildContext across async gaps" best practice.
class AdminSubjectController {
  /// Riverpod ref — used to read providers (academicYearRiverpod,
  /// languageRiverpod) the same way Laravel reads service container bindings.
  final Ref ref;

  AdminSubjectController(this.ref);

  // ─── Cache key ────────────────────────────────────────────────────────────

  /// Builds the local-cache key for the default first-page subject list.
  /// Returns null when any filter or search term is active — those results
  /// are not cached (like skipping HTTP cache for filtered API requests).
  ///
  /// Mirrors CacheKeyBuilder.custom('subject_list', yearId) used in the
  /// student controller.
  String? buildSubjectCacheKey({
    required int currentPage,
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
  }) {
    if (currentPage != 1) return null;
    if (selectedStatusFilter != null ||
        selectedGradeLevelFilter != null ||
        selectedClassesStatusFilter != null ||
        selectedClassNameFilter != null ||
        searchText.trim().isNotEmpty) {
      return null;
    }

    final yearId =
        ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ??
        'default';
    return CacheKeyBuilder.custom('subject_list', yearId);
  }

  // ─── Filter helpers ───────────────────────────────────────────────────────

  /// Returns true if any filter or search is currently active.
  /// The screen calls this and stores the result in _hasActiveFilter via setState.
  /// Like a Vue computed: `hasActiveFilter: () => status != null || search != ''`.
  bool checkActiveFilter({
    required String? selectedStatusFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassNameFilter,
  }) {
    return selectedStatusFilter != null ||
        selectedClassesStatusFilter != null ||
        selectedGradeLevelFilter != null ||
        selectedClassNameFilter != null;
  }

  /// Builds the list of active filter chip descriptors for the header bar.
  /// Returns a list of `{label: String, onRemove: VoidCallback}` maps that the
  /// screen renders as dismissible chips.
  ///
  /// [onFilterRemoved] is called after each chip's close tap — the screen uses
  /// it to setState + reload, keeping UI concerns out of the controller.
  List<Map<String, dynamic>> buildFilterChips({
    required String? selectedStatusFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassNameFilter,
    required LanguageProvider languageProvider,
    required VoidCallback onStatusRemoved,
    required VoidCallback onClassesStatusRemoved,
    required VoidCallback onGradeLevelRemoved,
    required VoidCallback onClassNameRemoved,
  }) {
    final List<Map<String, dynamic>> filterChips = [];

    if (selectedStatusFilter != null) {
      final statusText = selectedStatusFilter == 'active'
          ? languageProvider.getTranslatedText({'en': 'Active', 'id': 'Aktif'})
          : selectedStatusFilter == 'inactive'
          ? languageProvider.getTranslatedText({
              'en': 'Inactive',
              'id': 'Tidak Aktif',
            })
          : languageProvider.getTranslatedText({'en': 'All', 'id': 'Semua'});
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': onStatusRemoved,
      });
    }

    if (selectedClassesStatusFilter != null) {
      final statusText = selectedClassesStatusFilter == 'ada'
          ? languageProvider.getTranslatedText({
              'en': 'Has Classes',
              'id': 'Ada Kelas',
            })
          : languageProvider.getTranslatedText({
              'en': 'No Classes',
              'id': 'Tidak Ada Kelas',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Classes', 'id': 'Kelas'})}: $statusText',
        'onRemove': onClassesStatusRemoved,
      });
    }

    if (selectedGradeLevelFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Tingkat Kelas'})}: $selectedGradeLevelFilter',
        'onRemove': onGradeLevelRemoved,
      });
    }

    if (selectedClassNameFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Nama Kelas'})}: $selectedClassNameFilter',
        'onRemove': onClassNameRemoved,
      });
    }

    return filterChips;
  }

  // ─── Data extraction helpers ──────────────────────────────────────────────

  /// Extracts unique class names and grade levels from a subject list.
  /// Like a Laravel Collection pluck + unique + sort pipeline.
  /// Returns `(classNames, gradeLevels)` — the screen applies both via setState.
  ({List<String> classNames, List<String> gradeLevels}) extractFilterOptions(
    List<dynamic> subjects,
  ) {
    final Set<String> classNamesSet = {};
    final Set<String> gradeLevelsSet = {};

    for (var subject in subjects) {
      // Support both naming conventions (English and Indonesian field names)
      final classNames =
          (subject['class_names'] ?? subject['kelas_names'])?.toString() ?? '';
      if (classNames.isNotEmpty) {
        classNamesSet.addAll(
          classNames.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
        );
      }

      final gradeLevels =
          (subject['class_grade_levels'] ?? subject['kelas_grade_levels'])
              ?.toString() ??
          '';
      if (gradeLevels.isNotEmpty) {
        gradeLevelsSet.addAll(
          gradeLevels
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }
    }

    return (
      classNames: classNamesSet.toList()..sort(),
      gradeLevels: gradeLevelsSet.toList()
        ..sort((a, b) {
          final aInt = int.tryParse(a) ?? 0;
          final bInt = int.tryParse(b) ?? 0;
          return aInt.compareTo(bInt);
        }),
    );
  }

  // ─── API data loading ─────────────────────────────────────────────────────

  /// Loads the first page of subjects. Cache-first strategy: tries local cache
  /// then falls back to API.
  ///
  /// Like `Cache::remember('subjects', 3*3600, fn() => Subject::paginate())`.
  /// Returns a [SubjectLoadResult]; the screen applies it via setState.
  Future<SubjectLoadResult> loadSubjects({
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
    required int perPage,
    bool useCache = true,
  }) async {
    SubjectLoadResult? cacheResult;

    try {
      // ── Step 1: Try cache for instant display ───────────────────────────
      if (useCache) {
        final cacheKey = buildSubjectCacheKey(
          currentPage: 1,
          selectedStatusFilter: selectedStatusFilter,
          selectedGradeLevelFilter: selectedGradeLevelFilter,
          selectedClassesStatusFilter: selectedClassesStatusFilter,
          selectedClassNameFilter: selectedClassNameFilter,
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
              final subjects = List<dynamic>.from(cachedData['subjects'] ?? []);
              if (subjects.isNotEmpty) {
                AppLogger.info('subject', 'Subjects loaded from cache');
                final options = extractFilterOptions(subjects);
                cacheResult = SubjectLoadResult(
                  subjects: subjects,
                  hasMoreData:
                      cachedData['pagination']?['has_next_page'] ?? false,
                  isLoading: false,
                  availableClassNames: options.classNames,
                  availableGradeLevels: options.gradeLevels,
                );
                // Return cache immediately — caller can show it while API loads
                // in the background. The screen calls loadSubjects again with
                // useCache: false for the background refresh.
                return cacheResult;
              }
            }
          } catch (e) {
            AppLogger.error('subject', 'Subject cache load failed: $e');
          }
        }
      }

      // ── Step 2: Fetch fresh data from API ───────────────────────────────
      final response = await getIt<ApiSubjectService>().getSubjectsPaginated(
        page: 1,
        limit: perPage,
        status: selectedStatusFilter,
        gradeLevel: selectedGradeLevelFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      final data = List<dynamic>.from(response['data'] ?? []);
      AppLogger.info('subject', 'Subjects received: ${data.length} items');

      final options = extractFilterOptions(data);

      // ── Step 3: Persist to cache (only default view) ─────────────────────
      final cacheKey = buildSubjectCacheKey(
        currentPage: 1,
        selectedStatusFilter: selectedStatusFilter,
        selectedGradeLevelFilter: selectedGradeLevelFilter,
        selectedClassesStatusFilter: selectedClassesStatusFilter,
        selectedClassNameFilter: selectedClassNameFilter,
        searchText: searchText,
      );
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'subjects': data,
          'pagination': response['pagination'],
        });
      }

      return SubjectLoadResult(
        subjects: data,
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        isLoading: false,
        availableClassNames: options.classNames,
        availableGradeLevels: options.gradeLevels,
      );
    } catch (error) {
      AppLogger.error('subject', 'Load subjects error: $error');
      // If we already have a cache result, signal that error happened but
      // don't replace the data — the screen will keep showing cached data.
      if (cacheResult != null) {
        return SubjectLoadResult(
          subjects: cacheResult.subjects,
          hasMoreData: cacheResult.hasMoreData,
          isLoading: false,
          availableClassNames: cacheResult.availableClassNames,
          availableGradeLevels: cacheResult.availableGradeLevels,
          errorMessage: ErrorUtils.getFriendlyMessage(error),
        );
      }
      return SubjectLoadResult.failure(ErrorUtils.getFriendlyMessage(error));
    }
  }

  /// Loads the next page of subjects and merges class-name/grade-level options
  /// with the existing sets provided by the screen.
  ///
  /// Returns a [SubjectLoadMoreResult]; the screen appends additionalSubjects
  /// to its existing list via setState.
  Future<SubjectLoadMoreResult> loadMoreSubjects({
    required int nextPage,
    required int perPage,
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String searchText,
    required List<String> existingClassNames,
    required List<String> existingGradeLevels,
  }) async {
    try {
      final response = await getIt<ApiSubjectService>().getSubjectsPaginated(
        page: nextPage,
        limit: perPage,
        status: selectedStatusFilter,
        gradeLevel: selectedGradeLevelFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      final data = List<dynamic>.from(response['data'] ?? []);

      // Merge new filter option values into the existing sets
      final classNamesSet = Set<String>.from(existingClassNames);
      final gradeLevelsSet = Set<String>.from(existingGradeLevels);

      for (var subject in data) {
        final classNames = subject['class_names']?.toString() ?? '';
        if (classNames.isNotEmpty) {
          classNamesSet.addAll(
            classNames
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty),
          );
        }

        final classGradeLevels =
            subject['kelas_grade_levels']?.toString() ?? '';
        if (classGradeLevels.isNotEmpty) {
          gradeLevelsSet.addAll(
            classGradeLevels
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty),
          );
        }
      }

      AppLogger.info(
        'subject',
        'Loaded more subjects: Page $nextPage, Count: ${data.length}',
      );

      return SubjectLoadMoreResult(
        additionalSubjects: data,
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        availableClassNames: classNamesSet.toList()..sort(),
        availableGradeLevels: gradeLevelsSet.toList()
          ..sort((a, b) {
            final aInt = int.tryParse(a) ?? 0;
            final bInt = int.tryParse(b) ?? 0;
            return aInt.compareTo(bInt);
          }),
      );
    } catch (e) {
      AppLogger.error('subject', 'Error loading more subjects: $e');
      return SubjectLoadMoreResult(
        additionalSubjects: const [],
        hasMoreData: true, // Keep true so the screen can retry
        availableClassNames: existingClassNames,
        availableGradeLevels: existingGradeLevels,
        errorMessage: ErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  /// Force-refreshes subjects by invalidating the cache first, then fetching
  /// fresh data from the API.
  ///
  /// The screen should call loadSubjects(useCache: false) after invalidation —
  /// this method only handles cache clearing and delegates the load back.
  Future<void> invalidateSubjectCache({
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
  }) async {
    final cacheKey = buildSubjectCacheKey(
      currentPage: 1,
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedClassNameFilter: selectedClassNameFilter,
      searchText: searchText,
    );
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
  }

  /// Loads filter options from the API.
  /// Currently only logs — the response is not yet used to hydrate filter lists
  /// (those are extracted from the subject data instead). Returns success flag.
  Future<SubjectFilterOptionsResult> loadFilterOptions() async {
    try {
      final response =
          await getIt<ApiSubjectService>().getSubjectFilterOptions();
      if (response['success'] == true && response['data'] != null) {
        AppLogger.info('subject', 'Filter options loaded');
      }
      return const SubjectFilterOptionsResult(success: true);
    } catch (e) {
      AppLogger.error('subject', 'Error loading filter options: $e');
      return const SubjectFilterOptionsResult(success: false);
    }
  }

  // ─── Data mutation ────────────────────────────────────────────────────────

  /// Deletes a subject after user confirmation.
  /// Returns `null` on success, or an error message string on failure.
  /// The caller shows success/error snackbars itself — keeping context usage
  /// at the call-site, not stored in the controller.
  /// Deletes a subject by [subjectId].
  /// Returns `null` on success, or an error message string on failure.
  /// The caller is responsible for showing the confirmation dialog and
  /// snackbar feedback — keeping BuildContext usage at the screen layer.
  Future<String?> deleteSubject(dynamic subjectId) async {
    try {
      await getIt<ApiSubjectService>().deleteSubject(subjectId);
      return null;
    } catch (error) {
      AppLogger.error('subject', 'Delete subject error: $error');
      return ErrorUtils.getFriendlyMessage(error);
    }
  }

  /// Exports subjects to Excel.
  /// Delegates to [ExcelSubjectService] which handles the file save/open.
  Future<void> exportToExcel({
    required List<dynamic> subjects,
    required BuildContext context,
  }) async {
    await ExcelSubjectService.exportSubjectsToExcel(
      subjects: subjects,
      context: context,
    );
  }

  /// Imports subjects from an Excel file picked by the user.
  /// Returns `null` on success, or an error message string on failure.
  /// The caller shows snackbars itself.
  Future<String?> importFromExcel() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiSubjectService>().importSubjectFromExcel(
          File(result.files.single.path!),
        );
        return null; // null = success
      }

      return null; // User cancelled picker — not an error
    } catch (e) {
      AppLogger.error('subject', 'Import subjects error: $e');
      return ErrorUtils.getFriendlyMessage(e);
    }
  }

  /// Downloads the Excel import template.
  Future<void> downloadTemplate(BuildContext context) async {
    await ExcelSubjectService.downloadTemplate(context);
  }

  // ─── Pure helpers / utilities ─────────────────────────────────────────────

  /// Returns the primary theme color for the admin role.
  /// Like `ColorUtils.getRoleColor('admin')` — extracted so the screen doesn't
  /// need to import ColorUtils directly.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Returns a localised status label for a subject's status string.
  /// Like a Vue filter: `{{ subject.status | statusText }}`.
  String getSubjectStatusText(
    String? status,
    LanguageProvider languageProvider,
  ) {
    switch (status) {
      case 'active':
        return languageProvider.getTranslatedText({
          'en': 'Active',
          'id': 'Aktif',
        });
      case 'inactive':
        return languageProvider.getTranslatedText({
          'en': 'Inactive',
          'id': 'Tidak Aktif',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }

  /// Loads master subjects (predefined subject templates).
  /// Returns the list on success, or an empty list on failure (non-critical).
  Future<List<dynamic>> loadMasterSubjects() async {
    try {
      final data = await getIt<ApiSubjectService>().getAllMasterSubjects();
      if (kDebugMode) {
        AppLogger.info(
          'subject',
          'Master Subjects Loaded: ${data.length} items',
        );
        if (data.isNotEmpty) {
          AppLogger.debug('subject', 'First item: ${data[0]}');
        }
      }
      return data;
    } catch (e) {
      AppLogger.error('subject', 'Error loading master subjects: $e');
      return const [];
    }
  }

  /// Applies client-side filtering on top of the server-filtered subject list.
  /// Handles filters that are not sent to the API (class status, class name).
  /// Like a Laravel Collection `filter()` call applied after an Eloquent query.
  List<dynamic> getFilteredSubjects({
    required List<dynamic> subjectList,
    required String searchText,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
  }) {
    return subjectList.where((subject) {
      final searchTerm = searchText.toLowerCase();
      final subjectName = subject['name']?.toString().toLowerCase() ?? '';
      final subjectCode =
          (subject['code'] ?? subject['kode'])?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          subjectCode.contains(searchTerm);

      final hasClasses = (subject['jumlah_kelas'] ?? 0) > 0;
      final matchesClassStatusFilter =
          selectedClassesStatusFilter == null ||
          (selectedClassesStatusFilter == 'ada' && hasClasses) ||
          (selectedClassesStatusFilter == 'tidak_ada' && !hasClasses);

      final classNames = subject['kelas_names']?.toString() ?? '';
      final matchesClassNameFilter =
          selectedClassNameFilter == null ||
          (classNames.isNotEmpty &&
              classNames
                  .split(',')
                  .map((e) => e.trim())
                  .contains(selectedClassNameFilter));

      return matchesSearch && matchesClassStatusFilter && matchesClassNameFilter;
    }).toList();
  }

  // ─── Snackbar helpers ─────────────────────────────────────────────────────

  /// Shows an error snackbar. Requires [BuildContext] because snackbars are
  /// widget-layer concerns.
  void showErrorSnackBar(BuildContext context, String message) {
    SnackBarUtils.showError(context, message);
  }

  /// Shows a success snackbar, optionally translating the message.
  void showSuccessSnackBar(BuildContext context, String message) {
    SnackBarUtils.showSuccess(context, message);
  }
}
