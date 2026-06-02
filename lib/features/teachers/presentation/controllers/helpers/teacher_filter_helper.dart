// Helper for the admin-teacher filter chip row.
//
// Pure functions — no side effects. Consumers pass in screen filter state
// plus one targeted callback per chip type; the helper produces a typed
// [ActiveFilter] list that the shared header renders. Each chip carries
// its own × handler, so tapping remove on "Mengajar: 7A" only clears the
// teaching-class filter, not every filter on the row (the bug fixed at
// the same time as the Siswa migration).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';

class TeacherFilterHelper {
  /// Returns true when any teacher-list filter is engaged.
  /// Used to drive the "active" highlight on the filter icon and to
  /// decide whether the "Clear All" affordance should show.
  static bool checkActiveFilter({
    required String? selectedHomeroomFilter,
    required String? selectedGender,
    required String? selectedEmploymentStatus,
    required String? selectedTeachingClassId,
    required String searchText,
  }) {
    return selectedHomeroomFilter != null ||
        selectedGender != null ||
        selectedEmploymentStatus != null ||
        selectedTeachingClassId != null ||
        searchText.trim().isNotEmpty;
  }

  /// Builds the typed [ActiveFilter] list rendered in the header's chip row.
  ///
  /// Each chip's removal callback is targeted — the caller supplies one
  /// callback per filter type and the helper routes the × press to it.
  static List<ActiveFilter> buildFilterChips({
    required String? selectedHomeroomFilter,
    required String? selectedGender,
    required String? selectedEmploymentStatus,
    required String? selectedTeachingClassId,
    required List<dynamic> availableClass,
    required List<dynamic> availableEmploymentStatus,
    required LanguageProvider languageProvider,
    required VoidCallback onClearHomeroom,
    required VoidCallback onClearGender,
    required VoidCallback onClearEmploymentStatus,
    required VoidCallback onClearTeachingClass,
  }) {
    final chips = <ActiveFilter>[];

    if (selectedHomeroomFilter != null) {
      chips.add(
        _homeroomChip(
          selectedHomeroomFilter,
          languageProvider,
          onClearHomeroom,
        ),
      );
    }

    if (selectedGender != null) {
      chips.add(_genderChip(selectedGender, languageProvider, onClearGender));
    }

    if (selectedEmploymentStatus != null) {
      chips.add(
        _employmentChip(
          selectedEmploymentStatus,
          availableEmploymentStatus,
          languageProvider,
          onClearEmploymentStatus,
        ),
      );
    }

    if (selectedTeachingClassId != null) {
      chips.add(
        _teachingClassChip(
          selectedTeachingClassId,
          availableClass,
          languageProvider,
          onClearTeachingClass,
        ),
      );
    }

    return chips;
  }

  static ActiveFilter _homeroomChip(
    String value,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final statusText = value == 'wali_kelas'
        ? lang.getTranslatedText(const {
            'en': 'Homeroom Teacher',
            'id': 'Wali Kelas',
          })
        : lang.getTranslatedText(const {
            'en': 'Regular Teacher',
            'id': 'Guru Biasa',
          });
    final statusLabel = lang.getTranslatedText(const {
      'en': 'Status',
      'id': 'Status',
    });
    return ActiveFilter(
      label: '$statusLabel: $statusText',
      onRemove: onRemove,
      icon: Icons.home_work_outlined,
    );
  }

  static ActiveFilter _genderChip(
    String value,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    // Backend canonical: `male` / `female`. Legacy: `L` / `P`.
    final genderText = (value == 'male' || value == 'L')
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

  static ActiveFilter _employmentChip(
    String value,
    List<dynamic> availableEmploymentStatus,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final entry = availableEmploymentStatus.firstWhere(
      (s) => s['value'].toString() == value,
      orElse: () => {'label': value},
    );
    final statusLabel = entry['label'];
    final fieldLabel = lang.getTranslatedText(const {
      'en': 'Employment',
      'id': 'Status Kepegawaian',
    });
    return ActiveFilter(
      label: '$fieldLabel: $statusLabel',
      onRemove: onRemove,
      icon: Icons.badge_outlined,
    );
  }

  static ActiveFilter _teachingClassChip(
    String classId,
    List<dynamic> availableClass,
    LanguageProvider lang,
    VoidCallback onRemove,
  ) {
    final entry = availableClass.firstWhere(
      (c) => c['id'].toString() == classId,
      orElse: () => {'name': classId},
    );
    final className = entry['name'] ?? entry['nama'] ?? classId;
    final fieldLabel = lang.getTranslatedText(const {
      'en': 'Teaching',
      'id': 'Kelas Ajar',
    });
    return ActiveFilter(
      label: '$fieldLabel: $className',
      onRemove: onRemove,
      icon: Icons.class_outlined,
    );
  }
}
