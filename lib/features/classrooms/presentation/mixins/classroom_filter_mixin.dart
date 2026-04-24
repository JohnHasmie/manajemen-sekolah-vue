import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/presentation/controllers/admin_classroom_controller.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_filter_sheet.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';

/// Mixin for filter operations and UI.
///
/// Provides methods for managing filters, filter chips, and filter sheet.
/// Assumes the State class provides setState() and context.
mixin ClassroomFilterMixin on ConsumerState<AdminClassManagementScreen> {
  // Abstract state fields
  String? get selectedGradeFilter;
  set selectedGradeFilter(String? value);

  String? get selectedHomeroomFilter;
  set selectedHomeroomFilter(String? value);

  bool get hasActiveFilter;
  set hasActiveFilter(bool value);

  List<String> get availableGradeLevels;

  bool get isMounted => mounted;

  /// Recomputes the active filter state.
  void checkActiveFilter() {
    setState(() {
      hasActiveFilter = ref
          .read(adminClassroomControllerProvider)
          .checkActiveFilter(
            selectedGradeFilter: selectedGradeFilter,
            selectedHomeroomFilter: selectedHomeroomFilter,
          );
    });
  }

  /// Clears all filters and resets search.
  void clearAllFilters() {
    final reset = ref.read(adminClassroomControllerProvider).clearAllFilters();
    setState(() {
      selectedGradeFilter = reset.gradeFilter;
      selectedHomeroomFilter = reset.homeroomFilter;
      hasActiveFilter = reset.hasActiveFilter;
    });
    onFiltersCleared();
  }

  /// Builds chip data for active filter badges.
  List<Map<String, dynamic>> buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    return ref
        .read(adminClassroomControllerProvider)
        .buildFilterChips(
          selectedGradeFilter: selectedGradeFilter,
          selectedHomeroomFilter: selectedHomeroomFilter,
          languageProvider: languageProvider,
          onRemoveGrade: () {
            setState(() => selectedGradeFilter = null);
            checkActiveFilter();
            onGradeFilterRemoved();
          },
          onRemoveHomeroom: () {
            setState(() => selectedHomeroomFilter = null);
            checkActiveFilter();
            onHomeroomFilterRemoved();
          },
        );
  }

  /// Shows the filter bottom-sheet.
  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassroomFilterSheet(
        initialGradeFilter: selectedGradeFilter,
        initialHomeroomFilter: selectedHomeroomFilter,
        availableGradeLevels: availableGradeLevels,
        languageProvider: ref.read(languageRiverpod),
        onApply: (grade, homeroom) {
          setState(() {
            selectedGradeFilter = grade;
            selectedHomeroomFilter = homeroom;
          });
          checkActiveFilter();
          onFilterApplied();
        },
      ),
    );
  }

  /// Called when filters are cleared (hook for data reload, etc.).
  void onFiltersCleared();

  /// Called when grade filter is removed.
  void onGradeFilterRemoved();

  /// Called when homeroom filter is removed.
  void onHomeroomFilterRemoved();

  /// Called when filters are applied from the sheet.
  void onFilterApplied();
}
