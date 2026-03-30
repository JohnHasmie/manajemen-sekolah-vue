// Admin student controller — data/logic layer extracted from
// AdminStudentManagementScreen.
//
// Mirrors the pattern in `teacher_grade_controller.dart`: a plain Dart class
// that owns all API calls, cache reads/writes, and pure helpers.
// The screen keeps setState, UI builders, and dialog/navigation methods.
//
// In Laravel terms: this is the Controller; the screen is the Blade View.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/exports/student_export_service.dart';

/// Riverpod provider — like a Laravel service-container binding.
/// The screen does: `ref.read(adminStudentControllerProvider)` to get
/// the singleton controller for this widget tree.
final adminStudentControllerProvider =
    Provider<AdminStudentController>(AdminStudentController.new);

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
/// Receives [Ref] (Riverpod base type common to both provider refs and [WidgetRef])
/// so it can read providers from inside a Provider<> or from a widget.
/// Methods that need to show snackbars or dialogs receive [BuildContext] as a
/// parameter (passed in from the screen at call-time), following Flutter's
/// best practice of not storing context across async gaps.
class AdminStudentController {
  final Ref ref;

  AdminStudentController(this.ref);

  // ---------------------------------------------------------------------------
  // Cache-key builder
  // ---------------------------------------------------------------------------

  /// Returns the cache key for the current first-page default view, or null if
  /// any filter/search is active (those results are not cached).
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
    if (currentPage != 1) return null;
    if (selectedClassIds.isNotEmpty ||
        selectedGradeLevel != null ||
        selectedGenderFilter != null ||
        selectedGuardian != null ||
        selectedStatusFilter != null ||
        searchText.trim().isNotEmpty) {
      return null;
    }
    final yearId =
        ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ??
        'default';
    return CacheKeyBuilder.custom('student_list', yearId);
  }

  // ---------------------------------------------------------------------------
  // Filter helpers (pure — no setState, no context)
  // ---------------------------------------------------------------------------

  /// Returns true if any filter or search text is currently active.
  /// Screen calls this and stores the result in [_hasActiveFilter] via setState.
  bool checkActiveFilter({
    required String? selectedStatusFilter,
    required List<String> selectedClassIds,
    required String? selectedGenderFilter,
    required String? selectedGradeLevel,
    required String? selectedGuardian,
    required String searchText,
  }) {
    return selectedStatusFilter != null ||
        selectedClassIds.isNotEmpty ||
        selectedGenderFilter != null ||
        selectedGradeLevel != null ||
        selectedGuardian != null ||
        searchText.trim().isNotEmpty;
  }

  /// Builds the filter chip list for the header bar.
  /// Returns a list of {label, onRemove} maps — the screen renders them.
  /// Callbacks inside onRemove call setState on the screen then trigger loadData.
  List<Map<String, dynamic>> buildFilterChips({
    required String? selectedStatusFilter,
    required List<String> selectedClassIds,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required List<dynamic> classList,
    required LanguageProvider languageProvider,
    required VoidCallback onFilterChanged,
  }) {
    final List<Map<String, dynamic>> filterChips = [];

    if (selectedStatusFilter != null) {
      final statusText = selectedStatusFilter == 'active'
          ? languageProvider.getTranslatedText({'en': 'Active', 'id': 'Aktif'})
          : languageProvider.getTranslatedText({
              'en': 'Inactive',
              'id': 'Tidak Aktif',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': onFilterChanged,
      });
    }

    if (selectedClassIds.isNotEmpty) {
      for (var classId in selectedClassIds) {
        final className = classList.firstWhere(
          (k) => k['id'].toString() == classId,
          orElse: () => {'name': classId},
        );
        filterChips.add({
          'label':
              '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: ${className['name'] ?? className['nama'] ?? 'Unknown'}',
          'onRemove': onFilterChanged,
        });
      }
    }

    if (selectedGenderFilter != null) {
      final genderText = selectedGenderFilter == 'M'
          ? languageProvider.getTranslatedText({
              'en': 'Male',
              'id': 'Laki-laki',
            })
          : languageProvider.getTranslatedText({
              'en': 'Female',
              'id': 'Perempuan',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Gender', 'id': 'Jenis Kelamin'})}: $genderText',
        'onRemove': onFilterChanged,
      });
    }

    if (selectedGuardian != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Guardian', 'id': 'Wali'})}: $selectedGuardian',
        'onRemove': onFilterChanged,
      });
    }

    return filterChips;
  }

  /// Returns translated gender display text for a gender code ('M'/'L'/'F'/'P').
  String getGenderText(String? gender, LanguageProvider languageProvider) {
    switch (gender) {
      case 'M':
      case 'L':
        return languageProvider.getTranslatedText({
          'en': 'Male',
          'id': 'Laki-laki',
        });
      case 'F':
      case 'P':
        return languageProvider.getTranslatedText({
          'en': 'Female',
          'id': 'Perempuan',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
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
    try {
      if (resetPage) {
        // ─── Step 1: Try cache — return early on hit ───
        if (useCache) {
          final cacheKey = buildStudentCacheKey(
            currentPage: 1,
            selectedClassIds: selectedClassIds,
            selectedGradeLevel: selectedGradeLevel,
            selectedGenderFilter: selectedGenderFilter,
            selectedGuardian: selectedGuardian,
            selectedStatusFilter: selectedStatusFilter,
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
                AppLogger.info('student', 'Students loaded from cache');
                return StudentLoadResult(
                  students: List<dynamic>.from(cachedData['students'] ?? []),
                  classList: List<dynamic>.from(cachedData['classList'] ?? []),
                  hasMoreData:
                      cachedData['pagination']?['has_next_page'] ?? false,
                  isLoading: false,
                );
              }
            } catch (e) {
              AppLogger.error('student', 'Student cache load failed: $e');
            }
          }
        }
      }

      // ─── Step 2: Fetch fresh data from API ───
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: resetPage ? 1 : currentPage,
        limit: perPage,
        classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
        gradeLevel: selectedGradeLevel,
        gender: selectedGenderFilter,
        academicYearId: selectedYearId,
        guardianName: selectedGuardian,
        status: selectedStatusFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
        useCache: useCache,
      );

      final classData = await getIt<ApiClassService>().getClass();

      // ─── Step 3: Save to cache (non-blocking, only default view) ───
      final cacheKey = buildStudentCacheKey(
        currentPage: 1,
        selectedClassIds: selectedClassIds,
        selectedGradeLevel: selectedGradeLevel,
        selectedGenderFilter: selectedGenderFilter,
        selectedGuardian: selectedGuardian,
        selectedStatusFilter: selectedStatusFilter,
        searchText: searchText,
      );
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'students': response['data'] ?? [],
          'classList': classData,
          'pagination': response['pagination'],
        });
      }

      return StudentLoadResult(
        students: response['data'] ?? [],
        classList: classData,
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('student', 'Load students/class error: $e');
      return StudentLoadResult(
        students: const [],
        classList: const [],
        hasMoreData: false,
        isLoading: false,
        errorMessage: ErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  /// Loads the next page of students for infinite scroll.
  /// Returns a [StudentLoadMoreResult] — screen appends to its list via setState.
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
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: nextPage,
        limit: perPage,
        classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
        gradeLevel: selectedGradeLevel,
        gender: selectedGenderFilter,
        academicYearId: selectedYearId,
        guardianName: selectedGuardian,
        status: selectedStatusFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      AppLogger.info(
        'student',
        'Loaded more data: Page $nextPage, items: ${(response['data'] ?? []).length}',
      );

      return StudentLoadMoreResult(
        additionalStudents: response['data'] ?? [],
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
      );
    } catch (e) {
      AppLogger.error('student', 'Load more students error: $e');
      return null; // Screen interprets null as failure (roll back page counter)
    }
  }

  /// Loads filter options (grade levels + classes) — tries cache first.
  /// Returns [FilterOptionsResult] — screen applies via setState.
  Future<FilterOptionsResult?> loadFilterOptions() async {
    try {
      final cacheKey = CacheKeyBuilder.custom('student', 'filter_options');
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && cached is Map<String, dynamic>) {
        return _parseFilterOptions(cached);
      }

      final response =
          await getIt<ApiStudentService>().getStudentFilterOptions();

      if (response['success'] == true && response['data'] != null) {
        LocalCacheService.save(cacheKey, response['data']);
        return _parseFilterOptions(
          Map<String, dynamic>.from(response['data']),
        );
      }
      return null;
    } catch (e) {
      AppLogger.error('student', 'Error loading filter options: $e');
      return null;
    }
  }

  FilterOptionsResult _parseFilterOptions(Map<String, dynamic> data) {
    AppLogger.info(
      'student',
      'Filter options loaded: ${(data['grade_levels'] as List?)?.length ?? 0} grades, ${(data['kelas'] as List?)?.length ?? 0} kelas',
    );
    return FilterOptionsResult(
      gradeLevels: List<String>.from(data['grade_levels'] ?? []),
      availableClass: data['kelas'] ?? [],
    );
  }

  /// Force-refresh: clears relevant caches then triggers a full reload.
  /// The screen passes current filter state so buildStudentCacheKey can find the right key.
  Future<void> forceRefreshCaches({
    required int currentPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
  }) async {
    final cacheKey = buildStudentCacheKey(
      currentPage: currentPage,
      selectedClassIds: selectedClassIds,
      selectedGradeLevel: selectedGradeLevel,
      selectedGenderFilter: selectedGenderFilter,
      selectedGuardian: selectedGuardian,
      selectedStatusFilter: selectedStatusFilter,
      searchText: searchText,
    );
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_student_management_');
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('student', 'filter_options'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Delete Student',
          'id': 'Hapus Siswa',
        }),
        content: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Are you sure you want to delete this student?',
          'id': 'Yakin ingin menghapus siswa ini?',
        }),
        confirmText: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Delete',
          'id': 'Hapus',
        }),
        confirmColor: ColorUtils.error600,
      ),
    );

    if (confirmed != true) return false;

    try {
      await getIt<ApiStudentService>().deleteStudent(student['id']);
      return true;
    } catch (e) {
      AppLogger.error('student', 'Delete student error: $e');
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          ref.read(languageRiverpod).getTranslatedText({
            'en':
                'Failed to delete student: ${ErrorUtils.getFriendlyMessage(e)}',
            'id':
                '${AppLocalizations.failedToDelete.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
          }),
        );
      }
      return false;
    }
  }

  /// Exports students matching current filters to an Excel file.
  Future<void> exportToExcel({
    required BuildContext context,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String searchText,
  }) async {
    try {
      SnackBarUtils.showInfo(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Preparing export...',
          'id': 'Menyiapkan export...',
        }),
      );

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: 1,
        limit: 10000,
        classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
        gradeLevel: selectedGradeLevel,
        gender: selectedGenderFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      if (!context.mounted) return;

      await ExcelService.exportStudentsToExcel(
        students: response['data'] ?? [],
        context: context,
      );
    } catch (e) {
      AppLogger.error('student', 'Export to Excel error: $e');
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Failed to export: ${ErrorUtils.getFriendlyMessage(e)}',
          'id':
              '${AppLocalizations.failedToExport.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    }
  }

  /// Lets the user pick an Excel file and imports it.
  /// Returns true if import succeeded (screen can reload), false on cancel/error.
  Future<bool> importFromExcel(BuildContext context) async {
    final languageProvider = ref.read(languageRiverpod);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiStudentService>().importStudentsFromExcel(
          File(result.files.single.path!),
        );
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('student', 'Import from Excel error: $e');
      if (!context.mounted) return false;
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to import file: ${ErrorUtils.getFriendlyMessage(e)}',
          'id':
              '${AppLocalizations.failedToImport.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
      return false;
    }
  }

  /// Downloads the import template Excel file.
  Future<void> downloadTemplate(BuildContext context) async {
    await ExcelService.downloadTemplate(context);
  }

  // ---------------------------------------------------------------------------
  // Navigation helper
  // ---------------------------------------------------------------------------

  /// Returns whether the current academic year is read-only.
  /// Screen uses this to decide whether to show edit/delete controls.
  bool get isReadOnly => ref.read(academicYearRiverpod).isReadOnly;
}
