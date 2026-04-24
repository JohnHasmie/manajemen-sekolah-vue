import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Helper class for student filter operations.
/// Handles filter chip building, active filter checking, and gender text
/// translation.
class StudentFilterHelper {
  /// Returns true if any filter or search text is currently active.
  /// Screen calls this and stores the result in [_hasActiveFilter] via
  /// setState.
  static bool checkActiveFilter({
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
  /// Callbacks inside onRemove call setState on the screen then trigger
  /// loadData.
  static List<Map<String, dynamic>> buildFilterChips({
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
      _addStatusFilterChip(
        filterChips,
        selectedStatusFilter,
        languageProvider,
        onFilterChanged,
      );
    }

    if (selectedClassIds.isNotEmpty) {
      _addClassFilterChips(
        filterChips,
        selectedClassIds,
        classList,
        languageProvider,
        onFilterChanged,
      );
    }

    if (selectedGenderFilter != null) {
      _addGenderFilterChip(
        filterChips,
        selectedGenderFilter,
        languageProvider,
        onFilterChanged,
      );
    }

    if (selectedGuardian != null) {
      _addGuardianFilterChip(
        filterChips,
        selectedGuardian,
        languageProvider,
        onFilterChanged,
      );
    }

    return filterChips;
  }

  static void _addStatusFilterChip(
    List<Map<String, dynamic>> chips,
    String selectedStatus,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final statusText = selectedStatus == 'active'
        ? lang.getTranslatedText({'en': 'Active', 'id': 'Aktif'})
        : lang.getTranslatedText({'en': 'Inactive', 'id': 'Tidak Aktif'});
    final statusLabel = lang.getTranslatedText({
      'en': 'Status',
      'id': 'Status',
    });
    final label = '$statusLabel: $statusText';
    chips.add({'label': label, 'onRemove': onRemove});
  }

  static void _addClassFilterChips(
    List<Map<String, dynamic>> chips,
    List<String> classIds,
    List<dynamic> classList,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    for (final classId in classIds) {
      final classInfo = classList.firstWhere(
        (k) => k['id'].toString() == classId,
        orElse: () => {'name': classId},
      );
      final className = classInfo['name'] ?? classInfo['nama'] ?? 'Unknown';
      final classLabel = lang.getTranslatedText({'en': 'Class', 'id': 'Kelas'});
      final label = '$classLabel: $className';
      chips.add({'label': label, 'onRemove': onRemove});
    }
  }

  static void _addGenderFilterChip(
    List<Map<String, dynamic>> chips,
    String selectedGender,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final genderText = selectedGender == 'M'
        ? lang.getTranslatedText({'en': 'Male', 'id': 'Laki-laki'})
        : lang.getTranslatedText({'en': 'Female', 'id': 'Perempuan'});
    final genderLabel = lang.getTranslatedText({
      'en': 'Gender',
      'id': 'Jenis Kelamin',
    });
    final label = '$genderLabel: $genderText';
    chips.add({'label': label, 'onRemove': onRemove});
  }

  static void _addGuardianFilterChip(
    List<Map<String, dynamic>> chips,
    String guardian,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final guardianLabel = lang.getTranslatedText({
      'en': 'Guardian',
      'id': 'Wali',
    });
    final label = '$guardianLabel: $guardian';
    chips.add({'label': label, 'onRemove': onRemove});
  }

  /// Returns translated gender display text for a gender code.
  /// Accepts 'M'/'L' (male), 'F'/'P' (female), or returns 'Unknown'.
  static String getGenderText(
    String? gender,
    LanguageProvider languageProvider,
  ) {
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
}
