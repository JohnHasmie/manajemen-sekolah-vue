// Chip-builder methods for AttendanceFilterSheet.
//
// Header / footer / section-header helpers were retired when the sheet
// migrated to AppFilterBottomSheet + TeacherFilterContent — those primitives
// now own the gradient header, section spacing, and footer chrome.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

/// Abstract contract for state required by the mixin.
abstract class _FilterSheetStateGetter {
  /// Language provider for translations.
  LanguageProvider get filterLang;

  /// Primary color for the filter sheet.
  Color get filterPrimaryColor;

  /// Temporary date filter value.
  String? get tempDateFilter;
  set tempDateFilter(String? value);

  /// Temporary subject IDs.
  List<String> get tempSubjectIds;

  /// Temporary day IDs.
  List<String> get tempDayIds;

  /// Temporary lesson hour IDs.
  List<String> get tempLessonHourIds;

  /// Available subjects.
  List<dynamic> get filterSubjects;

  /// Available lesson hours.
  List<dynamic> get filterLessonHours;

  /// Called when applying filters.
  Function get onFilterApply;
}

// Build methods for the filter sheet UI.
mixin AttendanceFilterUiMixin implements _FilterSheetStateGetter {
  // Required from State.
  void setState(VoidCallback fn);
  BuildContext get context;
  // Static day data.
  static const List<Map<String, String>> _days = [
    {'en': 'Monday', 'id': 'Senin', 'val': '1'},
    {'en': 'Tuesday', 'id': 'Selasa', 'val': '2'},
    {'en': 'Wednesday', 'id': 'Rabu', 'val': '3'},
    {'en': 'Thursday', 'id': 'Kamis', 'val': '4'},
    {'en': 'Friday', 'id': 'Jumat', 'val': '5'},
    {'en': 'Saturday', 'id': 'Sabtu', 'val': '6'},
    {'en': 'Sunday', 'id': 'Minggu', 'val': '7'},
  ];

  // ==================== Chip Sections ====================

  Widget buildDateRangeChips() {
    final options = [
      FilterOption<String>(
        value: 'today',
        label: filterLang.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
      ),
      FilterOption<String>(
        value: 'week',
        label: filterLang.getTranslatedText({
          'en': 'This Week',
          'id': 'Minggu Ini',
        }),
      ),
      FilterOption<String>(
        value: 'month',
        label: filterLang.getTranslatedText({
          'en': 'This Month',
          'id': 'Bulan Ini',
        }),
      ),
      // Fix-DD — Semester (6 bulan) + Tahunan options. Date ranges
      // computed in `attendance_table_helper.dart` and
      // `attendance_summary_helper.dart`.
      FilterOption<String>(
        value: 'semester',
        label: filterLang.getTranslatedText({
          'en': 'Last 6 Months',
          'id': 'Semester (6 Bulan)',
        }),
      ),
      FilterOption<String>(
        value: 'year',
        label: filterLang.getTranslatedText({
          'en': 'This Year',
          'id': 'Tahunan',
        }),
      ),
    ];

    return FilterChipGrid<String>(
      options: options,
      selectedValue: tempDateFilter,
      onSelected: (value) {
        setState(() {
          tempDateFilter = value;
        });
      },
      selectedColor: filterPrimaryColor,
      spacing: 8,
      runSpacing: 8,
    );
  }

  Widget buildSubjectChips() {
    final options = filterSubjects.map((subject) {
      final map = subject as Map<String, dynamic>;
      final model = Subject.fromJson(map);
      final subjectId = model.id;
      final label = model.name.isNotEmpty
          ? model.name
          : (map['mata_pelajaran_nama']?.toString() ?? 'Subject');
      return FilterOption<String>(value: subjectId, label: label);
    }).toList();

    return FilterChipGrid<String>(
      options: options,
      selectedValues: Set<String>.from(tempSubjectIds),
      onMultiSelected: (values) {
        setState(() {
          tempSubjectIds.clear();
          tempSubjectIds.addAll(values);
        });
      },
      selectedColor: filterPrimaryColor,
      multiSelect: true,
      spacing: 8,
      runSpacing: 8,
    );
  }

  Widget buildDayChips() {
    final options = _days.map((d) {
      final val = d['val']!;
      final label = filterLang.getTranslatedText({
        'en': d['en']!,
        'id': d['id']!,
      });
      return FilterOption<String>(value: val, label: label);
    }).toList();

    return FilterChipGrid<String>(
      options: options,
      selectedValues: Set<String>.from(tempDayIds),
      onMultiSelected: (values) {
        setState(() {
          tempDayIds.clear();
          tempDayIds.addAll(values);
        });
      },
      selectedColor: filterPrimaryColor,
      multiSelect: true,
      spacing: 8,
      runSpacing: 8,
    );
  }

  Widget buildLessonHourChips() {
    final options = filterLessonHours.map((lh) {
      final lhId = lh['id'].toString();
      return FilterOption<String>(value: lhId, label: lh['name'] ?? 'Jam');
    }).toList();

    return FilterChipGrid<String>(
      options: options,
      selectedValues: Set<String>.from(tempLessonHourIds),
      onMultiSelected: (values) {
        setState(() {
          tempLessonHourIds.clear();
          tempLessonHourIds.addAll(values);
        });
      },
      selectedColor: filterPrimaryColor,
      multiSelect: true,
      spacing: 8,
      runSpacing: 8,
    );
  }
}
