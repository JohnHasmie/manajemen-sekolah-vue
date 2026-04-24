// Mixin providing UI builders for TeacherScheduleFilterSheet.
// Handles header, content sections, footer, and chip rendering.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

/// Mixin providing UI builder methods for teacher schedule filter sheet.
/// Requires state to expose temp selections, widget data, and callbacks.
mixin TeacherScheduleUiMixin {
  // Required from State — must be provided by the mixing class.
  void setState(VoidCallback fn);
  BuildContext get context;

  // Abstract members for state access.
  Color get primaryColor => Colors.blue;
  List<String> get tempDayIds => [];
  set tempDayIds(List<String> value);
  String? get tempClassId;
  set tempClassId(String? value);
  String? get tempSemester;
  set tempSemester(String? value);
  List<String> get dayOptions => [];
  Map<String, String> get dayIdMap => {};
  List<Map<String, String>> get availableClasses => [];
  List<dynamic> get semesterList => [];
  String get currentSemester => '';
  dynamic get languageProvider => null;
  void Function(
    List<String> dayIds,
    String? classId,
    String? semester,
    bool needsReload,
  )
  get onApplyCallback => (_, __, ___, ____) {};

  /// Translates a raw Indonesian day name to current UI language.
  String getLocalizedDay(String dayRaw) {
    final dayMap = <String, Map<String, String>>{
      'senin': {'en': 'Monday', 'id': 'Senin'},
      'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
      'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
      'kamis': {'en': 'Thursday', 'id': 'Kamis'},
      'jumat': {'en': 'Friday', 'id': 'Jumat'},
      "jum'at": {'en': 'Friday', 'id': 'Jumat'},
      'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
      'minggu': {'en': 'Sunday', 'id': 'Minggu'},
    };
    final key = dayRaw.toLowerCase();
    return dayMap[key] != null
        ? languageProvider.getTranslatedText(dayMap[key]!)
        : dayRaw;
  }

  /// Scrollable filter-chip sections.
  ///
  /// Each logical section (day, class, semester) is rendered as a pair
  /// of `[FilterSectionHeader, FilterChipGrid]` wrapped in a `Column`,
  /// and the parent [TeacherFilterContent] handles the inter-section
  /// gap. This matches the pattern used by grade-input and activity
  /// filter mixins so all teacher filter sheets share the same visual
  /// rhythm: tinted icon + title, then chips.
  Widget buildScrollableContent() {
    return TeacherFilterContent(
      sections: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Day',
                'id': 'Hari',
              }),
              icon: Icons.calendar_today_rounded,
              primaryColor: primaryColor,
            ),
            FilterChipGrid<String>(
              options: dayOptions
                  .where((d) => d != 'Semua Hari')
                  .map(
                    (day) => FilterOption(
                      value: dayIdMap[day] ?? '',
                      label: getLocalizedDay(day),
                    ),
                  )
                  .toList(),
              selectedValues: Set<String>.from(tempDayIds),
              onMultiSelected: (values) => setState(() {
                tempDayIds.clear();
                tempDayIds.addAll(values);
              }),
              multiSelect: true,
              selectedColor: primaryColor,
            ),
          ],
        ),
        if (availableClasses.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: languageProvider.getTranslatedText({
                  'en': 'Class',
                  'id': 'Kelas',
                }),
                icon: Icons.class_outlined,
                primaryColor: primaryColor,
              ),
              FilterChipGrid<String>(
                options: availableClasses
                    .map(
                      (cls) => FilterOption(
                        value: cls['id'] ?? '',
                        label: cls['name'] ?? '',
                      ),
                    )
                    .toList(),
                selectedValue: tempClassId,
                onSelected: (val) => setState(() => tempClassId = val),
                selectedColor: primaryColor,
              ),
            ],
          ),
        if (semesterList.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: languageProvider.getTranslatedText({
                  'en': 'Semester',
                  'id': 'Semester',
                }),
                icon: Icons.event_note_rounded,
                primaryColor: primaryColor,
              ),
              FilterChipGrid<String>(
                options: semesterList.map((sem) {
                  final semId = sem['id'].toString();
                  return FilterOption(
                    value: semId,
                    label: sem['name'] ?? sem['nama'] ?? 'Semester',
                  );
                }).toList(),
                selectedValue: tempSemester,
                onSelected: (val) => setState(() => tempSemester = val),
                selectedColor: primaryColor,
              ),
            ],
          ),
      ],
    );
  }
}
