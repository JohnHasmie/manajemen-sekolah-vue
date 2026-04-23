import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Encapsulates filter-related helper methods for classroom management.
///
/// Handles filter state checks, chip building, and UI-related utilities.
class ClassroomFilterHelper {
  final Ref ref;

  const ClassroomFilterHelper(this.ref);

  /// Returns `true` when any filter is currently active.
  bool checkActiveFilter({
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
  }) {
    return selectedGradeFilter != null || selectedHomeroomFilter != null;
  }

  /// Builds the chip data list for active filters shown in the header.
  List<Map<String, dynamic>> buildFilterChips({
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required LanguageProvider languageProvider,
    required VoidCallback onRemoveGrade,
    required VoidCallback onRemoveHomeroom,
  }) {
    final filterChips = <Map<String, dynamic>>[];

    if (selectedGradeFilter != null) {
      final label = languageProvider.getTranslatedText({
        'en': 'Grade',
        'id': 'Kelas',
      });
      filterChips.add({
        'label': '$label: $selectedGradeFilter',
        'onRemove': onRemoveGrade,
      });
    }

    if (selectedHomeroomFilter != null) {
      final hLabel = _buildHomeroomLabel(
        selectedHomeroomFilter,
        languageProvider,
      );
      final statusLabel = languageProvider.getTranslatedText({
        'en': 'Status',
        'id': 'Status',
      });
      filterChips.add({
        'label': '$statusLabel: $hLabel',
        'onRemove': onRemoveHomeroom,
      });
    }

    return filterChips;
  }

  /// Converts a numeric grade level to human-readable string.
  String getGradeLevelText(
    dynamic gradeLevel,
    LanguageProvider languageProvider,
  ) {
    if (gradeLevel == null) return '-';

    final level = int.tryParse(gradeLevel.toString());
    if (level == null) return '-';

    final prefix = languageProvider.getTranslatedText({
      'en': 'Grade',
      'id': 'Kelas',
    });
    if (level <= 6) {
      return '$prefix $level SD';
    } else if (level <= 9) {
      return '$prefix $level SMP';
    } else {
      return '$prefix $level SMA';
    }
  }

  /// Generates the list of grade level strings based on [jenjang].
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

  /// Returns the reset filter values for the screen.
  ({String? gradeFilter, String? homeroomFilter, bool hasActiveFilter})
  clearAllFilters() {
    return (gradeFilter: null, homeroomFilter: null, hasActiveFilter: false);
  }

  // ─────────────────────────────────────────────────────────────

  String _buildHomeroomLabel(
    String homeroomFilter,
    LanguageProvider languageProvider,
  ) {
    if (homeroomFilter == 'true') {
      return languageProvider.getTranslatedText({
        'en': 'Has Homeroom Teacher',
        'id': 'Sudah Ada Wali Kelas',
      });
    } else {
      return languageProvider.getTranslatedText({
        'en': 'No Homeroom Teacher',
        'id': 'Belum Ada Wali Kelas',
      });
    }
  }
}
