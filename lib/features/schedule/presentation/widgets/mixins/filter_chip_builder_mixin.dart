// Mixin to build FilterChip rows for schedule filters.
// Provides methods to render day, class, semester, and lesson hour chips.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';

/// Mixin providing FilterChip building methods for schedule filter sheet.
/// Requires state to expose temp selection getters/setters and widget data.
mixin FilterChipBuilderMixin {
  // Required from State — must be provided by the mixing class.
  void setState(VoidCallback fn);

  // Abstract members to be implemented by the consuming state class.
  String? get tempSelectedHariId;
  set tempSelectedHariId(String? value);
  String? get tempSelectedClassId;
  set tempSelectedClassId(String? value);
  String? get tempSelectedSemester;
  set tempSelectedSemester(String? value);
  String? get tempSelectedLessonHour;
  set tempSelectedLessonHour(String? value);

  // Stub for widget data access - derived classes override.
  List<dynamic> get availableDays => [];
  List<dynamic> get availableClasses => [];
  List<dynamic> get semesterList => [];
  List<dynamic> get lessonHourList => [];

  /// Builds FilterChip row for days with bilingual name normalization.
  Widget buildDayChips(dynamic languageProvider) {
    const dayMap = <String, Map<String, String>>{
      'senin': {'en': 'Monday', 'id': 'Senin'},
      'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
      'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
      'kamis': {'en': 'Thursday', 'id': 'Kamis'},
      'jumat': {'en': 'Friday', 'id': 'Jumat'},
      "jum'at": {'en': 'Friday', 'id': 'Jumat'},
      'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
      'minggu': {'en': 'Sunday', 'id': 'Minggu'},
      'monday': {'en': 'Monday', 'id': 'Senin'},
      'tuesday': {'en': 'Tuesday', 'id': 'Selasa'},
      'wednesday': {'en': 'Wednesday', 'id': 'Rabu'},
      'thursday': {'en': 'Thursday', 'id': 'Kamis'},
      'friday': {'en': 'Friday', 'id': 'Jumat'},
      'saturday': {'en': 'Saturday', 'id': 'Sabtu'},
      'sunday': {'en': 'Sunday', 'id': 'Minggu'},
    };

    return FilterChipGrid<String>(
      options: availableDays.map<FilterOption<String>>((day) {
        final dayId = day['id'].toString();
        final dayNameRaw = day['name'] ?? day['nama'] ?? '';
        final normalizedKey = dayNameRaw.toString().toLowerCase();
        final dayName = dayMap[normalizedKey] != null
            ? languageProvider.getTranslatedText(dayMap[normalizedKey]!)
            : dayNameRaw;

        return FilterOption(value: dayId, label: dayName);
      }).toList(),
      selectedValue: tempSelectedHariId,
      onSelected: (val) => setState(() => tempSelectedHariId = val),
      selectedColor: Theme.of(context).primaryColor,
    );
  }

  /// Builds FilterChip row for class groups.
  Widget buildClassChips() {
    return FilterChipGrid<String>(
      options: availableClasses.map<FilterOption<String>>((cls) {
        return FilterOption(
          value: cls['id'].toString(),
          label: cls['name'] ?? cls['nama'] ?? '',
        );
      }).toList(),
      selectedValue: tempSelectedClassId,
      onSelected: (val) => setState(() => tempSelectedClassId = val),
      selectedColor: Theme.of(context).primaryColor,
    );
  }

  /// Builds FilterChip row for semesters with academic year suffix.
  Widget buildTermChips() {
    return FilterChipGrid<String>(
      options: semesterList.map<FilterOption<String>>((semester) {
        final semesterId = semester['id'].toString();
        String semesterName =
            semester['name'] ?? semester['nama'] ?? 'Semester $semesterId';
        if (semester['academic_year'] != null &&
            semester['academic_year']['year'] != null) {
          semesterName += ' (${semester['academic_year']['year']})';
        }
        return FilterOption(value: semesterId, label: semesterName);
      }).toList(),
      selectedValue: tempSelectedSemester,
      onSelected: (val) => setState(() => tempSelectedSemester = val),
      selectedColor: Theme.of(context).primaryColor,
    );
  }

  /// Builds FilterChip row for lesson hours (deduplicated & sorted).
  Widget buildLessonHourChips() {
    final Set<String> uniqueHours = {};
    for (final jp in lessonHourList) {
      final h = (jp['hour_number'] ?? jp['jam_ke'])?.toString();
      if (h != null) uniqueHours.add(h);
    }
    final sortedHours = uniqueHours.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

    return FilterChipGrid<String>(
      options: sortedHours.map<FilterOption<String>>((hourNum) {
        return FilterOption(value: hourNum, label: 'Jam $hourNum');
      }).toList(),
      selectedValue: tempSelectedLessonHour,
      onSelected: (val) => setState(() => tempSelectedLessonHour = val),
      selectedColor: Theme.of(context).primaryColor,
    );
  }

  BuildContext get context;
}
