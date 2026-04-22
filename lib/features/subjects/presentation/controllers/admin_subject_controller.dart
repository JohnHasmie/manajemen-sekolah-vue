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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/subjects/presentation/controllers/subject_data_helper.dart';
import 'package:manajemensekolah/features/subjects/presentation/controllers/subject_export_helper.dart';
import 'package:manajemensekolah/features/subjects/presentation/controllers/subject_filter_helper.dart';
import 'package:manajemensekolah/features/subjects/presentation/controllers/subject_text_helper.dart';

export 'subject_data_helper.dart'
    show SubjectLoadResult, SubjectLoadMoreResult, SubjectFilterOptionsResult;

/// Riverpod provider for [AdminSubjectController].
/// Use `ref.read(adminSubjectControllerProvider)` from the screen.
///
/// This is a plain [Provider] (not AsyncNotifier) because the controller
/// does not own state — it just provides methods. State stays in the screen's
/// `setState` calls, matching the pattern used throughout this codebase for
/// ConsumerStatefulWidgets.
final adminSubjectControllerProvider = Provider<AdminSubjectController>(
  AdminSubjectController.new,
);

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
///
/// Uses facade pattern to delegate to helper classes:
/// - [SubjectDataHelper]: cache, loading, pagination, extraction
/// - [SubjectFilterHelper]: filtering, chips, client-side filtering
/// - [SubjectExportHelper]: Excel import/export
/// - [SubjectTextHelper]: text translation
class AdminSubjectController {
  /// Riverpod ref — used to read providers (academicYearRiverpod,
  /// languageRiverpod) the same way Laravel reads service container bindings.
  final Ref ref;

  AdminSubjectController(this.ref);

  // ─── Cache key ────────────────────────────────────────────────────────────

  /// Builds the local-cache key for the default first-page subject list.
  /// Returns null when any filter or search term is active.
  String? buildSubjectCacheKey({
    required int currentPage,
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
  }) {
    return SubjectDataHelper.buildSubjectCacheKey(
      ref,
      currentPage: currentPage,
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedClassNameFilter: selectedClassNameFilter,
      searchText: searchText,
    );
  }

  // ─── Filter helpers ───────────────────────────────────────────────────────

  /// Returns true if any filter or search is currently active.
  bool checkActiveFilter({
    required String? selectedStatusFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassNameFilter,
  }) {
    return SubjectFilterHelper.checkActiveFilter(
      selectedStatusFilter: selectedStatusFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassNameFilter: selectedClassNameFilter,
    );
  }

  /// Builds the list of active filter chip descriptors for the header bar.
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
    return SubjectFilterHelper.buildFilterChips(
      selectedStatusFilter: selectedStatusFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassNameFilter: selectedClassNameFilter,
      languageProvider: languageProvider,
      onStatusRemoved: onStatusRemoved,
      onClassesStatusRemoved: onClassesStatusRemoved,
      onGradeLevelRemoved: onGradeLevelRemoved,
      onClassNameRemoved: onClassNameRemoved,
    );
  }

  // ─── Data extraction helpers ──────────────────────────────────────────────

  /// Extracts unique class names and grade levels from a subject list.
  ({List<String> classNames, List<String> gradeLevels}) extractFilterOptions(
    List<dynamic> subjects,
  ) {
    return SubjectDataHelper.extractFilterOptions(subjects);
  }

  // ─── API data loading ─────────────────────────────────────────────────────

  /// Loads the first page of subjects. Cache-first strategy.
  Future<SubjectLoadResult> loadSubjects({
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
    required int perPage,
    bool useCache = true,
  }) {
    return SubjectDataHelper.loadSubjects(
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedClassNameFilter: selectedClassNameFilter,
      searchText: searchText,
      perPage: perPage,
      ref: ref,
      useCache: useCache,
    );
  }

  /// Loads the next page of subjects and merges class-name/grade-level options
  /// with the existing sets provided by the screen.
  Future<SubjectLoadMoreResult> loadMoreSubjects({
    required int nextPage,
    required int perPage,
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String searchText,
    required List<String> existingClassNames,
    required List<String> existingGradeLevels,
  }) {
    return SubjectDataHelper.loadMoreSubjects(
      nextPage: nextPage,
      perPage: perPage,
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      searchText: searchText,
      existingClassNames: existingClassNames,
      existingGradeLevels: existingGradeLevels,
    );
  }

  /// Force-refreshes subjects by invalidating the cache.
  Future<void> invalidateSubjectCache({
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
  }) {
    return SubjectDataHelper.invalidateSubjectCache(
      ref,
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedClassNameFilter: selectedClassNameFilter,
      searchText: searchText,
    );
  }

  /// Loads filter options from the API.
  Future<SubjectFilterOptionsResult> loadFilterOptions() {
    return SubjectDataHelper.loadFilterOptions();
  }

  /// Loads master subjects (predefined subject templates).
  Future<List<dynamic>> loadMasterSubjects() {
    return SubjectDataHelper.loadMasterSubjects();
  }

  // ─── Data mutation ────────────────────────────────────────────────────────

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
  Future<void> exportToExcel({
    required List<dynamic> subjects,
    required BuildContext context,
  }) {
    return SubjectExportHelper.exportToExcel(
      subjects: subjects,
      context: context,
    );
  }

  /// Imports subjects from an Excel file picked by the user.
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> importFromExcel() {
    return SubjectExportHelper.importFromExcel();
  }

  /// Downloads the Excel import template.
  Future<void> downloadTemplate(BuildContext context) {
    return SubjectExportHelper.downloadTemplate(context);
  }

  // ─── Pure helpers / utilities ─────────────────────────────────────────────

  /// Returns the primary theme color for the admin role.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Returns a localised status label for a subject's status string.
  String getSubjectStatusText(
    String? status,
    LanguageProvider languageProvider,
  ) {
    return SubjectTextHelper.getSubjectStatusText(status, languageProvider);
  }

  /// Applies client-side filtering on top of the server-filtered list.
  List<dynamic> getFilteredSubjects({
    required List<dynamic> subjectList,
    required String searchText,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
  }) {
    return SubjectFilterHelper.getFilteredSubjects(
      subjectList: subjectList,
      searchText: searchText,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedClassNameFilter: selectedClassNameFilter,
    );
  }

  // ─── Snackbar helpers ─────────────────────────────────────────────────────

  /// Shows an error snackbar. Requires [BuildContext] because snackbars are
  /// widget-layer concerns.
  void showErrorSnackBar(BuildContext context, String message) {
    SnackBarUtils.showError(context, message);
  }

  /// Shows a success snackbar.
  void showSuccessSnackBar(BuildContext context, String message) {
    SnackBarUtils.showSuccess(context, message);
  }
}
