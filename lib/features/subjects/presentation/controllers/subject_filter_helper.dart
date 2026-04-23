/// Helper for subject filter operations: checkActiveFilter, buildFilterChips.
/// Keeps UI-related filtering logic out of the main controller.
library;

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
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
