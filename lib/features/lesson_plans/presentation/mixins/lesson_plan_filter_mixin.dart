import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_filter_sheet.dart';

/// Mixin for filter sheet management in lesson plan screens.
/// Handles filter UI, state, and application logic.
mixin LessonPlanFilterMixin on ConsumerState<LessonPlanScreen> {
  /// Abstract getter: subclass provides the selected status filter.
  String? get selectedStatusFilter;

  /// Abstract setter: subclass updates the selected status filter.
  set selectedStatusFilter(String? value);

  /// Abstract getter: subclass provides the filter active state.
  bool get hasActiveFilter;

  /// Abstract setter: subclass updates the filter active state.
  set hasActiveFilter(bool value);

  /// Abstract method: subclass implements filter application.
  void checkActiveFilter();

  /// Abstract method: subclass implements list reload on filter change.
  Future<void> loadLessonPlans({bool useCache = true});

  /// Builds a summary string of active filters.
  String buildFilterSummary(LanguageProvider languageProvider) {
    final List<String> filters = [];

    if (selectedStatusFilter != null) {
      filters.add(
        '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $selectedStatusFilter',
      );
    }

    return filters.join(' • ');
  }

  /// Clears all active filters and reloads the list.
  void clearAllFilters() {
    setState(() {
      selectedStatusFilter = null;
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
      onApply: (newStatus) {
        setState(() {
          selectedStatusFilter = newStatus;
        });
        checkActiveFilter();
        loadLessonPlans();
      },
    );
  }

  /// Gets the primary color for the screen (bridge to state).
  Color getPrimaryColor() => ColorUtils.getRoleColor('guru');
}
