// Admin teacher controller — data/logic layer for the teacher management
// screen. Mirrors the shape of `admin_student_controller.dart`: a plain
// Dart class that owns API calls + cache reads/writes, while the screen
// keeps setState, dialog plumbing, and navigation.
//
// Riverpod provider mirrors the Siswa pattern so widgets can
// `ref.read(adminTeacherControllerProvider)` to grab the singleton.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/filter_options_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/teachers/exports/teacher_export_service.dart';

import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_form_dialog.dart';

/// Riverpod provider — `ref.read(adminTeacherControllerProvider)` yields a
/// shared controller instance for the screen + its descendant widgets.
final adminTeacherControllerProvider = Provider<AdminTeacherController>(
  AdminTeacherController.new,
);

/// Result object returned by [AdminTeacherController.loadData].
/// Screen applies it via setState — like a JSON payload coming back from a
/// Laravel controller.
class TeacherLoadResult {
  final List<dynamic> teachers;
  final List<dynamic> subjects;
  final List<dynamic> classes;
  final bool hasMoreData;
  final String? errorMessage;

  const TeacherLoadResult({
    required this.teachers,
    required this.subjects,
    required this.classes,
    required this.hasMoreData,
    this.errorMessage,
  });
}

/// Result object returned by [AdminTeacherController.loadMoreData].
class TeacherLoadMoreResult {
  final List<dynamic> additionalTeachers;
  final bool hasMoreData;

  const TeacherLoadMoreResult({
    required this.additionalTeachers,
    required this.hasMoreData,
  });
}

/// Result object returned by [AdminTeacherController.loadFilterOptions].
class TeacherFilterOptionsResult {
  final List<dynamic> availableClass;
  final List<dynamic> availableGenders;
  final List<dynamic> availableEmploymentStatus;

  const TeacherFilterOptionsResult({
    required this.availableClass,
    required this.availableGenders,
    required this.availableEmploymentStatus,
  });
}

class AdminTeacherController {
  final Ref ref;

  AdminTeacherController(this.ref);

  // ---------------------------------------------------------------------------
  // Cache key
  // ---------------------------------------------------------------------------

  /// Returns the cache key for the page-1/no-filter view, or null when
  /// any filter/search is active (those results are not cached).
  String? buildTeacherCacheKey({
    required int currentPage,
    required String? selectedClassId,
    required String? selectedHomeroomFilter,
    required String? selectedGender,
    required String? selectedEmploymentStatus,
    required String? selectedTeachingClassId,
    required bool showAllTeachers,
    required String searchText,
  }) {
    if (currentPage != 1) return null;
    if (selectedClassId != null ||
        selectedHomeroomFilter != null ||
        selectedGender != null ||
        selectedEmploymentStatus != null ||
        selectedTeachingClassId != null ||
        showAllTeachers ||
        searchText.trim().isNotEmpty) {
      return null;
    }
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return CacheKeyBuilder.custom('teacher_list', yearId);
  }

  // ---------------------------------------------------------------------------
  // Filter options
  // ---------------------------------------------------------------------------

  /// Loads gender / employment-status / class options for the filter sheet.
  /// Uses the consolidated `/filter-options` endpoint with caching.
  Future<TeacherFilterOptionsResult?> loadFilterOptions() async {
    try {
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final data = await FilterOptionsService.getFilterOptions(
        role: 'admin',
        academicYearId: academicYearId,
      );

      return TeacherFilterOptionsResult(
        availableClass: List<dynamic>.from(data['classes'] ?? []),
        availableGenders: List<dynamic>.from(data['gender_options'] ?? []),
        availableEmploymentStatus: List<dynamic>.from(
          data['employment_status_options'] ?? [],
        ),
      );
    } catch (e) {
      AppLogger.error('teacher', 'Error loading filter options: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  /// Loads page-1 of teachers plus the subject/class reference lists.
  Future<TeacherLoadResult> loadData({
    required bool useCache,
    required int currentPage,
    required int perPage,
    required String? selectedClassId,
    required String? selectedHomeroomFilter,
    required String? selectedGender,
    required String? selectedEmploymentStatus,
    required String? selectedTeachingClassId,
    required bool showAllTeachers,
    required String searchText,
  }) async {
    try {
      // Try cache first — only when view is "default" (page 1, no filters).
      if (useCache) {
        final cacheKey = buildTeacherCacheKey(
          currentPage: currentPage,
          selectedClassId: selectedClassId,
          selectedHomeroomFilter: selectedHomeroomFilter,
          selectedGender: selectedGender,
          selectedEmploymentStatus: selectedEmploymentStatus,
          selectedTeachingClassId: selectedTeachingClassId,
          showAllTeachers: showAllTeachers,
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
              AppLogger.info('teacher', 'Teachers loaded from cache');
              return TeacherLoadResult(
                teachers: List<dynamic>.from(cachedData['teachers'] ?? []),
                subjects: List<dynamic>.from(cachedData['subjects'] ?? []),
                classes: List<dynamic>.from(cachedData['classes'] ?? []),
                hasMoreData:
                    cachedData['pagination']?['has_next_page'] ?? false,
              );
            }
          } catch (e) {
            AppLogger.error('teacher', 'Teacher cache load failed: $e');
          }
        }
      }

      final selectedYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final effectiveAcademicYearId = showAllTeachers ? null : selectedYearId;

      // Subjects + classes are small reference lists — fetched alongside
      // the paginated list so the add/edit sheet has them ready.
      final subjectData = await getIt<ApiSubjectService>().getSubject();
      final classData = await getIt<ApiClassService>().getClass(
        academicYearId: selectedYearId,
      );

      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: currentPage,
        limit: perPage,
        classId: selectedHomeroomFilter == 'wali_kelas'
            ? selectedClassId
            : null,
        gender: selectedGender,
        employmentStatus: selectedEmploymentStatus,
        teachingClassId: selectedTeachingClassId,
        academicYearId: effectiveAcademicYearId,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
        useCache: useCache,
      );

      final result = TeacherLoadResult(
        teachers: response['data'] ?? [],
        subjects: subjectData,
        classes: classData,
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
      );

      // Write-through cache for the default view.
      final cacheKey = buildTeacherCacheKey(
        currentPage: currentPage,
        selectedClassId: selectedClassId,
        selectedHomeroomFilter: selectedHomeroomFilter,
        selectedGender: selectedGender,
        selectedEmploymentStatus: selectedEmploymentStatus,
        selectedTeachingClassId: selectedTeachingClassId,
        showAllTeachers: showAllTeachers,
        searchText: searchText,
      );
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'teachers': response['data'] ?? [],
          'subjects': subjectData,
          'classes': classData,
          'pagination': response['pagination'],
        });
      }

      return result;
    } catch (e) {
      AppLogger.error('teacher', 'Load teachers error: $e');
      return TeacherLoadResult(
        teachers: const [],
        subjects: const [],
        classes: const [],
        hasMoreData: false,
        errorMessage: ErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  /// Loads the next page of teachers for infinite scroll.
  Future<TeacherLoadMoreResult?> loadMoreData({
    required int nextPage,
    required int perPage,
    required String? selectedClassId,
    required String? selectedHomeroomFilter,
    required String? selectedGender,
    required String? selectedEmploymentStatus,
    required String? selectedTeachingClassId,
    required bool showAllTeachers,
    required String searchText,
  }) async {
    try {
      final selectedYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final effectiveAcademicYearId = showAllTeachers ? null : selectedYearId;

      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: nextPage,
        limit: perPage,
        classId: selectedHomeroomFilter == 'wali_kelas'
            ? selectedClassId
            : null,
        gender: selectedGender,
        employmentStatus: selectedEmploymentStatus,
        teachingClassId: selectedTeachingClassId,
        academicYearId: effectiveAcademicYearId,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      return TeacherLoadMoreResult(
        additionalTeachers: List<dynamic>.from(response['data'] ?? []),
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
      );
    } catch (e) {
      AppLogger.error('teacher', 'Error loading more data: $e');
      return null;
    }
  }

  /// Force-refresh: clears the teacher cache and filter-option cache, then
  /// the caller should re-run [loadData] with `useCache: false`.
  Future<void> forceRefreshCaches({
    required int currentPage,
    required String? selectedClassId,
    required String? selectedHomeroomFilter,
    required String? selectedGender,
    required String? selectedEmploymentStatus,
    required String? selectedTeachingClassId,
    required bool showAllTeachers,
    required String searchText,
  }) async {
    final cacheKey = buildTeacherCacheKey(
      currentPage: currentPage,
      selectedClassId: selectedClassId,
      selectedHomeroomFilter: selectedHomeroomFilter,
      selectedGender: selectedGender,
      selectedEmploymentStatus: selectedEmploymentStatus,
      selectedTeachingClassId: selectedTeachingClassId,
      showAllTeachers: showAllTeachers,
      searchText: searchText,
    );
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await FilterOptionsService.invalidateCache();
  }

  // ---------------------------------------------------------------------------
  // CRUD / dialogs
  // ---------------------------------------------------------------------------

  /// Opens the add/edit bottom sheet. On save the sheet calls [onSaved] so
  /// the screen can refresh its list.
  void openTeacherFormDialog({
    required BuildContext context,
    required List<dynamic> subjects,
    required List<dynamic> classes,
    Map<String, dynamic>? teacher,
    required VoidCallback onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => TeacherFormDialog(
        teacher: teacher,
        subjects: subjects,
        classes: classes,
        onSaved: onSaved,
      ),
    );
  }

  /// Shows delete confirmation + performs deletion. Returns true if the
  /// teacher was deleted successfully.
  Future<bool> deleteTeacher(
    Map<String, dynamic> teacher,
    BuildContext context,
  ) async {
    final languageProvider = ref.read(languageRiverpod);
    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: languageProvider.getTranslatedText(const {
        'en': 'Delete Teacher',
        'id': 'Hapus Guru',
      }),
      message: languageProvider.getTranslatedText(const {
        'en': 'Are you sure you want to delete this teacher?',
        'id': 'Apakah Anda yakin ingin menghapus guru ini?',
      }),
      confirmText: languageProvider.getTranslatedText(const {
        'en': 'Delete',
        'id': 'Hapus',
      }),
      isDestructive: true,
    );

    if (confirmed != true) return false;

    try {
      final teacherId = Teacher.fromJson(teacher).id;
      if (teacherId.isEmpty) return false;
      await getIt<ApiTeacherService>().deleteTeacher(teacherId);
      return true;
    } catch (error) {
      AppLogger.error('teacher', 'Delete teacher error: $error');
      if (context.mounted) {
        final prefix = languageProvider.getTranslatedText(const {
          'en': 'Failed to delete teacher: ',
          'id': 'Gagal menghapus guru: ',
        });
        SnackBarUtils.showError(
          context,
          '$prefix${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Excel flows
  // ---------------------------------------------------------------------------

  /// Exports teachers matching the current filters to an Excel workbook.
  Future<void> exportToExcel({
    required BuildContext context,
    required String? selectedClassId,
    required bool showAllTeachers,
    required String searchText,
  }) async {
    final lang = ref.read(languageRiverpod);
    try {
      if (!context.mounted) return;
      SnackBarUtils.showInfo(
        context,
        lang.getTranslatedText(const {
          'en': 'Preparing export...',
          'id': 'Menyiapkan export...',
        }),
      );

      final selectedYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final effectiveAcademicYearId = showAllTeachers ? null : selectedYearId;

      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: 1,
        limit: 10000,
        classId: selectedClassId,
        gender: null,
        academicYearId: effectiveAcademicYearId,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      if (!context.mounted) return;

      await ExcelTeacherService.exportTeachersToExcel(
        teachers: response['data'] ?? [],
        context: context,
      );
    } catch (e) {
      AppLogger.error('teacher', 'Export teachers error: $e');
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        lang.getTranslatedText({
          'en': 'Failed to export: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': 'Gagal export: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    }
  }

  /// Picks an Excel file and posts it to the import endpoint. Returns true
  /// on success so the screen can reload.
  Future<bool> importFromExcel(BuildContext context) async {
    final lang = ref.read(languageRiverpod);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return false;

      final pickedFile = File(result.files.single.path!);
      final fileSize = await pickedFile.length();
      AppLogger.debug(
        'teacher',
        'Import teachers - picked file: ${pickedFile.path}, '
            'size: $fileSize bytes',
      );

      try {
        final response = await getIt<ApiTeacherService>()
            .importTeachersFromExcel(pickedFile);
        AppLogger.debug('teacher', 'Import response: $response');

        if (!context.mounted) return false;

        if (response['errors'] != null &&
            response['errors'] is List &&
            (response['errors'] as List).isNotEmpty) {
          final errors = (response['errors'] as List).take(10).join('\n');
          SnackBarUtils.showWarning(
            context,
            'Import finished with errors:\n$errors',
          );
          return true;
        }

        if (response['error'] != null) {
          SnackBarUtils.showError(
            context,
            'Import failed: ${response['error']}',
          );
          return false;
        }

        SnackBarUtils.showSuccess(
          context,
          lang.getTranslatedText(const {
            'en': 'Import completed',
            'id': 'Import selesai',
          }),
        );
        return true;
      } catch (apiError) {
        AppLogger.error('teacher', 'Error calling import API: $apiError');
        if (!context.mounted) return false;
        final friendly = ErrorUtils.getFriendlyMessage(apiError);
        SnackBarUtils.showError(
          context,
          lang.getTranslatedText({
            'en': 'Failed to import file: $friendly',
            'id': 'Gagal import file: $friendly',
          }),
        );
        return false;
      }
    } catch (e) {
      AppLogger.error('teacher', 'Import from Excel picker error: $e');
      if (!context.mounted) return false;
      SnackBarUtils.showError(
        context,
        lang.getTranslatedText({
          'en': 'Failed to import file: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': 'Gagal import file: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
      return false;
    }
  }

  /// Downloads the teacher import template workbook.
  Future<void> downloadTemplate(BuildContext context) {
    return ExcelTeacherService.downloadTemplate(context);
  }

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  /// Returns whether the currently-selected academic year is read-only —
  /// the screen uses this to hide the FAB and disable edit/delete.
  bool get isReadOnly => ref.read(academicYearRiverpod).isReadOnly;
}
