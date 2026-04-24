/// Helper for subject filter operations: checkActiveFilter, buildFilterChips.
/// Keeps UI-related filtering logic out of the main controller.
library;

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

/// Pure filter helper — no state, no API calls.
class SubjectFilterHelper {
  /// Returns true if any filter or search is currently active.
  /// Like a Vue computed: `hasActiveFilter: () => status != null || ...`.
  static bool checkActiveFilter({
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
  /// Returns a list of `{label: String, onRemove: VoidCallback}` maps.
  /// [onFilterRemoved] callbacks are invoked after each chip's close tap —
  /// the screen uses them to setState + reload.
  static List<Map<String, dynamic>> buildFilterChips({
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
      final statusLabel = languageProvider.getTranslatedText({
        'en': 'Status',
        'id': 'Status',
      });
      filterChips.add({
        'label': '$statusLabel: $statusText',
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
      final classesLabel = languageProvider.getTranslatedText({
        'en': 'Classes',
        'id': 'Kelas',
      });
      filterChips.add({
        'label': '$classesLabel: $statusText',
        'onRemove': onClassesStatusRemoved,
      });
    }

    if (selectedGradeLevelFilter != null) {
      final gradeLabel = languageProvider.getTranslatedText({
        'en': 'Grade',
        'id': 'Tingkat Kelas',
      });
      filterChips.add({
        'label': '$gradeLabel: $selectedGradeLevelFilter',
        'onRemove': onGradeLevelRemoved,
      });
    }

    if (selectedClassNameFilter != null) {
      final classLabel = languageProvider.getTranslatedText({
        'en': 'Class',
        'id': 'Nama Kelas',
      });
      filterChips.add({
        'label': '$classLabel: $selectedClassNameFilter',
        'onRemove': onClassNameRemoved,
      });
    }

    return filterChips;
  }

  /// Builds typed [ActiveFilter] chips for [AdminCrudScaffold]'s header.
  ///
  /// Phase-1 version of [buildFilterChips] that returns one chip per active
  /// filter, each carrying its own × removal callback. Preferred over the
  /// map-based builder — fixes the shared-callback bug where every chip's
  /// close tap would clear the same filter.
  static List<ActiveFilter> buildActiveFilterChips({
    required String? selectedStatusFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassNameFilter,
    required LanguageProvider languageProvider,
    required VoidCallback onClearStatus,
    required VoidCallback onClearClassesStatus,
    required VoidCallback onClearGradeLevel,
    required VoidCallback onClearClassName,
  }) {
    final chips = <ActiveFilter>[];

    if (selectedStatusFilter != null) {
      final statusText = selectedStatusFilter == 'active'
          ? languageProvider.getTranslatedText(const {
              'en': 'Active',
              'id': 'Aktif',
            })
          : selectedStatusFilter == 'inactive'
          ? languageProvider.getTranslatedText(const {
              'en': 'Inactive',
              'id': 'Tidak Aktif',
            })
          : languageProvider.getTranslatedText(const {
              'en': 'All',
              'id': 'Semua',
            });
      final prefix = languageProvider.getTranslatedText(const {
        'en': 'Status',
        'id': 'Status',
      });
      chips.add(
        ActiveFilter(
          label: '$prefix: $statusText',
          onRemove: onClearStatus,
          icon: Icons.toggle_on_outlined,
        ),
      );
    }

    if (selectedClassesStatusFilter != null) {
      final statusText = selectedClassesStatusFilter == 'ada'
          ? languageProvider.getTranslatedText(const {
              'en': 'Has Classes',
              'id': 'Ada Kelas',
            })
          : languageProvider.getTranslatedText(const {
              'en': 'No Classes',
              'id': 'Tidak Ada Kelas',
            });
      final prefix = languageProvider.getTranslatedText(const {
        'en': 'Classes',
        'id': 'Kelas',
      });
      chips.add(
        ActiveFilter(
          label: '$prefix: $statusText',
          onRemove: onClearClassesStatus,
          icon: Icons.class_outlined,
        ),
      );
    }

    if (selectedGradeLevelFilter != null) {
      final prefix = languageProvider.getTranslatedText(const {
        'en': 'Grade',
        'id': 'Tingkat Kelas',
      });
      chips.add(
        ActiveFilter(
          label: '$prefix: $selectedGradeLevelFilter',
          onRemove: onClearGradeLevel,
          icon: Icons.school_outlined,
        ),
      );
    }

    if (selectedClassNameFilter != null) {
      final prefix = languageProvider.getTranslatedText(const {
        'en': 'Class',
        'id': 'Nama Kelas',
      });
      chips.add(
        ActiveFilter(
          label: '$prefix: $selectedClassNameFilter',
          onRemove: onClearClassName,
          icon: Icons.grid_view_outlined,
        ),
      );
    }

    return chips;
  }

  /// Applies client-side filtering on top of the server-filtered list.
  /// Handles filters not sent to the API (class status, class name).
  /// Like a Laravel Collection `filter()` after an Eloquent query.
  static List<dynamic> getFilteredSubjects({
    required List<dynamic> subjectList,
    required String searchText,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
  }) {
    return subjectList.where((subject) {
      final model = Subject.fromJson(subject as Map<String, dynamic>);
      final searchTerm = searchText.toLowerCase();
      final subjectName = model.name.toLowerCase();
      final subjectCode = (model.code ?? '').toLowerCase();

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          subjectCode.contains(searchTerm);

      final hasClasses = model.classCount > 0;
      final matchesClassStatusFilter =
          selectedClassesStatusFilter == null ||
          (selectedClassesStatusFilter == 'ada' && hasClasses) ||
          (selectedClassesStatusFilter == 'tidak_ada' && !hasClasses);

      final matchesClassNameFilter =
          selectedClassNameFilter == null ||
          model.classNameList.contains(selectedClassNameFilter);

      return matchesSearch &&
          matchesClassStatusFilter &&
          matchesClassNameFilter;
    }).toList();
  }
}
