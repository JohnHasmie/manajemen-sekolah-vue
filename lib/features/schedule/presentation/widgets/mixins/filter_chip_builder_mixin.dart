// Mixin to build FilterChip rows for schedule filters.
// Provides methods to render day, class, semester, and lesson hour chips.
// Teacher and Subject filters dynamically cross-filter: selecting a teacher
// narrows subjects to chips; selecting a subject narrows teachers to chips.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
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
  String? get tempSelectedTeacherId;
  set tempSelectedTeacherId(String? value);
  String? get tempSelectedSubjectId;
  set tempSelectedSubjectId(String? value);
  String? get tempSelectedSemester;
  set tempSelectedSemester(String? value);
  String? get tempSelectedLessonHour;
  set tempSelectedLessonHour(String? value);

  // Stub for widget data access - derived classes override.
  List<dynamic> get availableDays => [];
  List<dynamic> get availableClasses => [];
  List<dynamic> get availableTeachers => [];
  List<dynamic> get availableSubjects => [];
  List<dynamic> get semesterList => [];
  List<dynamic> get lessonHourList => [];

  /// Schedule list used to derive teacher↔subject relationships.
  List<dynamic> get scheduleList => [];

  // ── Cross-filtering helpers ─────────────────────────────────────────

  /// Returns the set of subject IDs that a given teacher teaches,
  /// derived from the loaded schedule rows.
  Set<String> _subjectIdsForTeacher(String teacherId) {
    final ids = <String>{};
    for (final row in scheduleList) {
      if (row is! Map) continue;
      final tId = (row['teacher_id'] ?? row['guru_id'])?.toString();
      if (tId == teacherId) {
        final sId = (row['subject_id'] ?? row['mata_pelajaran_id'])?.toString();
        if (sId != null && sId.isNotEmpty) ids.add(sId);
      }
    }
    return ids;
  }

  /// Returns the set of teacher IDs that teach a given subject,
  /// derived from the loaded schedule rows.
  Set<String> _teacherIdsForSubject(String subjectId) {
    final ids = <String>{};
    for (final row in scheduleList) {
      if (row is! Map) continue;
      final sId = (row['subject_id'] ?? row['mata_pelajaran_id'])?.toString();
      if (sId == subjectId) {
        final tId = (row['teacher_id'] ?? row['guru_id'])?.toString();
        if (tId != null && tId.isNotEmpty) ids.add(tId);
      }
    }
    return ids;
  }

  // ── Autocomplete builder (shared) ───────────────────────────────────

  Widget _buildAutocompleteField({
    required BuildContext context,
    required String hintText,
    required List<dynamic> items,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) {
    final options = items
        .map(
          (item) => {
            'id': item['id'].toString(),
            'name': (item['name'] ?? item['nama'] ?? '').toString(),
          },
        )
        .toList();

    return Autocomplete<Map<String, String>>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, String>>.empty();
        }
        return options.where(
          (option) => option['name']!.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          ),
        );
      },
      displayStringForOption: (option) => option['name']!,
      onSelected: (option) => onSelected(option['id']),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (selectedValue != null && controller.text.isEmpty) {
          final matched = options.where((o) => o['id'] == selectedValue);
          if (matched.isNotEmpty) {
            controller.text = matched.first['name']!;
          }
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: ColorUtils.slate50,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: ColorUtils.getRoleColor('admin'),
                width: 2,
              ),
            ),
            prefixIcon: Icon(Icons.search_rounded, color: ColorUtils.slate400),
            suffixIcon: selectedValue != null
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      controller.clear();
                      onSelected(null);
                      focusNode.unfocus();
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200,
                maxWidth: MediaQuery.of(context).size.width - 40,
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option['name']!),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Day chips ───────────────────────────────────────────────────────

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
      selectedColor: ColorUtils.getRoleColor('admin'),
    );
  }

  // ── Class chips ─────────────────────────────────────────────────────

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
      selectedColor: ColorUtils.getRoleColor('admin'),
    );
  }

  // ── Teacher chips / autocomplete ────────────────────────────────────

  /// When a subject is already selected → show chip list of teachers
  /// who teach that subject. Otherwise → show autocomplete search.
  Widget buildTeacherChips(dynamic languageProvider) {
    // Subject selected → narrow to chip list
    if (tempSelectedSubjectId != null && tempSelectedSubjectId!.isNotEmpty) {
      final teacherIds = _teacherIdsForSubject(tempSelectedSubjectId!);
      final filtered = availableTeachers.where((t) {
        final tId = t['id']?.toString() ?? '';
        return teacherIds.contains(tId);
      }).toList();

      return FilterChipGrid<String>(
        options: filtered.map<FilterOption<String>>((t) {
          return FilterOption(
            value: t['id'].toString(),
            label: (t['name'] ?? t['nama'] ?? '').toString(),
          );
        }).toList(),
        selectedValue: tempSelectedTeacherId,
        onSelected: (val) => setState(() => tempSelectedTeacherId = val),
        selectedColor: ColorUtils.getRoleColor('admin'),
      );
    }

    // No subject selected → full autocomplete
    return _buildAutocompleteField(
      context: context,
      hintText: languageProvider.getTranslatedText({
        'en': 'Search teacher...',
        'id': 'Cari guru...',
      }),
      items: availableTeachers,
      selectedValue: tempSelectedTeacherId,
      onSelected: (val) => setState(() {
        tempSelectedTeacherId = val;
        // When a teacher is selected, clear subject so it
        // switches to chip list mode for subjects.
        if (val != null) {
          tempSelectedSubjectId = null;
        }
      }),
    );
  }

  // ── Subject chips / autocomplete ────────────────────────────────────

  /// When a teacher is already selected → show chip list of subjects
  /// that teacher teaches. Otherwise → show autocomplete search.
  Widget buildSubjectChips(dynamic languageProvider) {
    // Teacher selected → narrow to chip list
    if (tempSelectedTeacherId != null && tempSelectedTeacherId!.isNotEmpty) {
      final subjectIds = _subjectIdsForTeacher(tempSelectedTeacherId!);
      final filtered = availableSubjects.where((s) {
        final sId = s['id']?.toString() ?? '';
        return subjectIds.contains(sId);
      }).toList();

      return FilterChipGrid<String>(
        options: filtered.map<FilterOption<String>>((s) {
          return FilterOption(
            value: s['id'].toString(),
            label: (s['name'] ?? s['nama'] ?? '').toString(),
          );
        }).toList(),
        selectedValue: tempSelectedSubjectId,
        onSelected: (val) => setState(() => tempSelectedSubjectId = val),
        selectedColor: ColorUtils.getRoleColor('admin'),
      );
    }

    // No teacher selected → full autocomplete
    return _buildAutocompleteField(
      context: context,
      hintText: languageProvider.getTranslatedText({
        'en': 'Search subject...',
        'id': 'Cari mata pelajaran...',
      }),
      items: availableSubjects,
      selectedValue: tempSelectedSubjectId,
      onSelected: (val) => setState(() {
        tempSelectedSubjectId = val;
        // When a subject is selected, clear teacher so it
        // switches to chip list mode for teachers.
        if (val != null) {
          tempSelectedTeacherId = null;
        }
      }),
    );
  }

  // ── Semester chips ──────────────────────────────────────────────────

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
      selectedColor: ColorUtils.getRoleColor('admin'),
    );
  }

  // ── Lesson hour chips ───────────────────────────────────────────────

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
      selectedColor: ColorUtils.getRoleColor('admin'),
    );
  }

  BuildContext get context;
}
