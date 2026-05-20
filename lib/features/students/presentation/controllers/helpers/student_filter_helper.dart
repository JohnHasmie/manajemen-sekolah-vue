import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';

/// Helper class for student filter operations.
///
/// Pure functions — no side effects beyond assembling UI models. Consumers
/// pass in screen state and typed per-filter-type callbacks; the helper
/// never reads or mutates controller state directly.
class StudentFilterHelper {
  /// Returns true if any filter or search text is currently active.
  /// Screen calls this and stores the result in `_hasActiveFilter` via
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

  /// Builds the typed active-filter chip list for the header bar.
  ///
  /// Each chip carries its own targeted removal callback — tapping the ×
  /// on a class chip removes that specific class, not "all filters".
  ///
  /// Callbacks:
  /// - [onClearStatus]   — status filter (Active/Inactive)
  /// - [onClearClass]    — remove a single class id from the multi-select
  /// - [onClearGender]   — gender filter (M/F)
  /// - [onClearGuardian] — guardian name contains filter
  static List<ActiveFilter> buildFilterChips({
    required String? selectedStatusFilter,
    required List<String> selectedClassIds,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required List<dynamic> classList,
    required LanguageProvider languageProvider,
    required VoidCallback onClearStatus,
    required void Function(String classId) onClearClass,
    required VoidCallback onClearGender,
    required VoidCallback onClearGuardian,
  }) {
    final chips = <ActiveFilter>[];

    if (selectedStatusFilter != null) {
      chips.add(
        _statusChip(selectedStatusFilter, languageProvider, onClearStatus),
      );
    }

    for (final classId in selectedClassIds) {
      chips.add(
        _classChip(classId, classList, languageProvider, () {
          onClearClass(classId);
        }),
      );
    }

    if (selectedGenderFilter != null) {
      chips.add(
        _genderChip(selectedGenderFilter, languageProvider, onClearGender),
      );
    }

    if (selectedGuardian != null) {
      chips.add(
        _guardianChip(selectedGuardian, languageProvider, onClearGuardian),
      );
    }

    return chips;
  }

  static ActiveFilter _statusChip(
    String selectedStatus,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final statusText = selectedStatus == 'active'
        ? lang.getTranslatedText(const {'en': 'Active', 'id': 'Aktif'})
        : lang.getTranslatedText(const {'en': 'Inactive', 'id': 'Tidak Aktif'});
    final statusLabel = lang.getTranslatedText(const {
      'en': 'Status',
      'id': 'Status',
    });
    return ActiveFilter(
      label: '$statusLabel: $statusText',
      onRemove: onRemove,
      icon: Icons.check_circle_outline,
    );
  }

  static ActiveFilter _classChip(
    String classId,
    List<dynamic> classList,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final classInfo = classList.firstWhere(
      (k) => k['id'].toString() == classId,
      orElse: () => {'name': classId},
    );
    final className = classInfo['name'] ?? classInfo['nama'] ?? 'Unknown';
    final classLabel = lang.getTranslatedText(const {
      'en': 'Class',
      'id': 'Kelas',
    });
    return ActiveFilter(
      label: '$classLabel: $className',
      onRemove: onRemove,
      icon: Icons.class_outlined,
    );
  }

  static ActiveFilter _genderChip(
    String selectedGender,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final genderText = selectedGender == 'L'
        ? lang.getTranslatedText(const {'en': 'Male', 'id': 'Laki-laki'})
        : lang.getTranslatedText(const {'en': 'Female', 'id': 'Perempuan'});
    final genderLabel = lang.getTranslatedText(const {
      'en': 'Gender',
      'id': 'Jenis Kelamin',
    });
    return ActiveFilter(
      label: '$genderLabel: $genderText',
      onRemove: onRemove,
      icon: Icons.wc_outlined,
    );
  }

  static ActiveFilter _guardianChip(
    String guardian,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final guardianLabel = lang.getTranslatedText(const {
      'en': 'Guardian',
      'id': 'Wali',
    });
    return ActiveFilter(
      label: '$guardianLabel: $guardian',
      onRemove: onRemove,
      icon: Icons.person_outline,
    );
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
        return languageProvider.getTranslatedText(const {
          'en': 'Male',
          'id': 'Laki-laki',
        });
      case 'F':
      case 'P':
        return languageProvider.getTranslatedText(const {
          'en': 'Female',
          'id': 'Perempuan',
        });
      default:
        return languageProvider.getTranslatedText(const {
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }
}
