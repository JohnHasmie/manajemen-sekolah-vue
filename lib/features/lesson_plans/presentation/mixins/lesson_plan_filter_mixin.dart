import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_filter_sheet.dart';

/// Mixin for filter sheet management in lesson plan screens.
/// Handles filter UI, state, and application logic.
///
/// As of the format axis migration this owns three filter axes:
///   - status (single-select, legacy)
///   - formats (multi-select, K13 / 1 Hal / Modul Ajar / File)
///   - method (single-select, AI / Manual / null = all)
///
/// All three flow through to the paginated service via `formats[]` +
/// `method` query params; the existing status param is unchanged.
mixin LessonPlanFilterMixin on ConsumerState<LessonPlanScreen> {
  /// Status axis (legacy) — abstract get/set on the host state.
  String? get selectedStatusFilter;
  set selectedStatusFilter(String? value);

  /// Format axis. Empty set ↔ "all formats". Default to a mutable
  /// empty set on the host state (`<LessonPlanFormat>{}`).
  Set<LessonPlanFormat> get selectedFormats;
  set selectedFormats(Set<LessonPlanFormat> value);

  /// Method axis. `null` ↔ "all", `'ai'` ↔ AI-generated only,
  /// `'manual'` ↔ teacher-authored only.
  String? get selectedMethod;
  set selectedMethod(String? value);

  bool get hasActiveFilter;
  set hasActiveFilter(bool value);

  void checkActiveFilter();
  Future<void> loadLessonPlans({bool useCache = true});

  /// Format set serialized for the service-layer `formats` param.
  /// Empty list ↔ no filter (caller skips the param).
  List<String> get selectedFormatValues =>
      selectedFormats.map((f) => f.value).toList();

  /// True when at least one of the three filter axes is active.
  bool computeHasActiveFilter() {
    return selectedStatusFilter != null ||
        selectedFormats.isNotEmpty ||
        selectedMethod != null;
  }

  /// Builds a summary string of active filters — shown in the
  /// `LessonPlanHeader`'s "active filter" pill.
  String buildFilterSummary(LanguageProvider languageProvider) {
    final List<String> parts = [];

    if (selectedFormats.isNotEmpty) {
      final formatLabels = selectedFormats.map((f) => f.label).join(', ');
      parts.add(
        '${languageProvider.getTranslatedText({'en': 'Format', 'id': 'Format'})}: $formatLabels',
      );
    }

    if (selectedMethod != null) {
      final label = selectedMethod == 'ai'
          ? languageProvider.getTranslatedText({'en': 'AI', 'id': 'AI'})
          : languageProvider.getTranslatedText({
              'en': 'Manual',
              'id': 'Manual',
            });
      parts.add(
        '${languageProvider.getTranslatedText({'en': 'Method', 'id': 'Metode'})}: $label',
      );
    }

    if (selectedStatusFilter != null) {
      parts.add(
        '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: ${_localizedStatus(selectedStatusFilter!, languageProvider)}',
      );
    }

    return parts.join(' • ');
  }

  String _localizedStatus(String raw, LanguageProvider lang) {
    switch (raw) {
      case 'Pending':
        return lang.getTranslatedText({'en': 'Pending', 'id': 'Menunggu'});
      case 'Approved':
        return lang.getTranslatedText({'en': 'Approved', 'id': 'Disetujui'});
      case 'Rejected':
        return lang.getTranslatedText({'en': 'Rejected', 'id': 'Ditolak'});
      case 'Draft':
        return 'Draf';
      default:
        return raw;
    }
  }

  /// Clears all active filters and reloads the list.
  void clearAllFilters() {
    setState(() {
      selectedStatusFilter = null;
      selectedFormats = <LessonPlanFormat>{};
      selectedMethod = null;
      hasActiveFilter = false;
    });
    loadLessonPlans();
  }

  /// Shows the filter bottom sheet using shared components.
  void showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    showLessonPlanFilterSheet(
      context: context,
      primaryColor: getPrimaryColor(),
      languageProvider: languageProvider,
      currentStatus: selectedStatusFilter,
      currentFormats: selectedFormats,
      currentMethod: selectedMethod,
      onApply: (result) {
        setState(() {
          selectedStatusFilter = result.status;
          selectedFormats = result.formats;
          selectedMethod = result.method;
        });
        checkActiveFilter();
        loadLessonPlans();
      },
    );
  }

  /// Gets the primary color for the screen (bridge to state).
  Color getPrimaryColor() => ColorUtils.getRoleColor('guru');
}
