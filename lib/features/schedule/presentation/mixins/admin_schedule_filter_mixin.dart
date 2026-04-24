import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_state_bridge_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_filter_sheet.dart';

/// Mixin for filter management and chip building.
///
/// Owns all filter building/management methods. Requires AdminScheduleStateBridgeMixin.
mixin AdminScheduleFilterMixin
    on
        ConsumerState<TeachingScheduleManagementScreen>,
        AdminScheduleStateBridgeMixin {
  Future<void> loadData({
    bool resetPage,
    bool useCache,
    required String searchText,
    required bool showTableView,
  });

  static const _dayTranslations = <String, Map<String, String>>{
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

  /// Clear all filters and reload.
  void clearAllFilters() {
    setState(() {
      updateSelectedTeacherId(null);
      updateSelectedClassId(null);
      updateSelectedDayId(null);
      updateSelectedFilterTerm(null);
      updateSelectedLessonHour(null);
      updateHasActiveFilter(false);
    });
    loadData(
      resetPage: true,
      useCache: true,
      searchText: '',
      showTableView: false,
    );
  }

  /// Build list of active filter chips.
  List<ActiveFilter> buildFilterChips(LanguageProvider lp) {
    final chips = <ActiveFilter>[];
    final dayChip = _buildDayFilterChip(lp);
    if (dayChip != null) chips.add(dayChip);
    final classChip = _buildClassFilterChip(lp);
    if (classChip != null) chips.add(classChip);
    final semesterChip = _buildSemesterFilterChip(lp);
    if (semesterChip != null) chips.add(semesterChip);
    return chips;
  }

  ActiveFilter? _buildDayFilterChip(LanguageProvider lp) {
    if (selectedDayId == null) return null;
    final day = availableDays.firstWhere(
      (d) => d['id'].toString() == selectedDayId,
      orElse: () => {},
    );
    final raw = day.isNotEmpty ? (day['name'] ?? day['nama'] ?? '') : 'Day';
    final key = raw.toString().toLowerCase();
    final label = _dayTranslations[key] != null
        ? lp.getTranslatedText(_dayTranslations[key]!)
        : raw;
    return ActiveFilter(
      label: '${lp.getTranslatedText({'en': 'Day', 'id': 'Hari'})}: $label',
      onRemove: () {
        setState(() {
          updateSelectedDayId(null);
          updateHasActiveFilter(
            controller.checkActiveFilter(
              selectedDayId: null,
              selectedClassId: selectedClassId,
              selectedJamPelajaran: selectedLessonHour,
              selectedFilterSemester: selectedFilterTerm,
              selectedSemester: selectedTerm,
            ),
          );
        });
        loadData(
          resetPage: true,
          useCache: true,
          searchText: '',
          showTableView: false,
        );
      },
    );
  }

  ActiveFilter? _buildClassFilterChip(LanguageProvider lp) {
    if (selectedClassId == null) return null;
    final cls = availableClasses.firstWhere(
      (c) => c['id'].toString() == selectedClassId,
      orElse: () => {},
    );
    final label = cls.isNotEmpty ? (cls['name'] ?? cls['nama']) : 'Class';
    return ActiveFilter(
      label:
          '${lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: $label',
      onRemove: () {
        setState(() {
          updateSelectedClassId(null);
          updateHasActiveFilter(
            controller.checkActiveFilter(
              selectedDayId: selectedDayId,
              selectedClassId: null,
              selectedJamPelajaran: selectedLessonHour,
              selectedFilterSemester: selectedFilterTerm,
              selectedSemester: selectedTerm,
            ),
          );
        });
        loadData(
          resetPage: true,
          useCache: true,
          searchText: '',
          showTableView: false,
        );
      },
    );
  }

  ActiveFilter? _buildSemesterFilterChip(LanguageProvider lp) {
    if (selectedFilterTerm == null || selectedFilterTerm == selectedTerm) {
      return null;
    }
    final semester = termList.firstWhere(
      (s) => s['id'].toString() == selectedFilterTerm,
      orElse: () => {},
    );
    var label = semester.isNotEmpty
        ? (semester['name'] ??
              semester['nama'] ??
              'Semester $selectedFilterTerm')
        : 'Semester $selectedFilterTerm';
    if (semester.isNotEmpty &&
        semester['academic_year'] != null &&
        semester['academic_year']['year'] != null) {
      label += ' (${semester['academic_year']['year']})';
    }
    return ActiveFilter(
      label:
          '${lp.getTranslatedText({'en': 'Semester', 'id': 'Semester'})}: $label',
      onRemove: () {
        setState(() {
          updateSelectedFilterTerm(null);
          updateHasActiveFilter(
            controller.checkActiveFilter(
              selectedDayId: selectedDayId,
              selectedClassId: selectedClassId,
              selectedJamPelajaran: selectedLessonHour,
              selectedFilterSemester: null,
              selectedSemester: selectedTerm,
            ),
          );
        });
        loadData(
          resetPage: true,
          useCache: true,
          searchText: '',
          showTableView: false,
        );
      },
    );
  }

  /// Show filter bottom sheet.
  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFilterSheet(
        availableDays: availableDays,
        availableClasses: availableClasses,
        semesterList: termList,
        lessonHourList: lessonHourList,
        currentSemester: selectedTerm,
        selectedDayId: selectedDayId,
        selectedClassId: selectedClassId,
        selectedFilterSemester: selectedFilterTerm,
        selectedJamPelajaran: selectedLessonHour,
        onApply:
            ({
              required String? dayId,
              required String? classId,
              required String? semester,
              required String? lessonHour,
            }) {
              setState(() {
                updateSelectedDayId(dayId);
                updateSelectedClassId(classId);
                updateSelectedFilterTerm(semester);
                updateSelectedLessonHour(lessonHour);
                updateHasActiveFilter(
                  controller.checkActiveFilter(
                    selectedDayId: dayId,
                    selectedClassId: classId,
                    selectedJamPelajaran: lessonHour,
                    selectedFilterSemester: semester,
                    selectedSemester: selectedTerm,
                  ),
                );
              });
              loadData(
                resetPage: true,
                useCache: true,
                searchText: '',
                showTableView: false,
              );
            },
      ),
    );
  }

  /// Get filtered schedules from controller.
  List<dynamic> getFilteredSchedules(
    List<dynamic> scheduleList,
    List<dynamic> dayList,
    String searchText,
  ) {
    return controller.getFilteredSchedules(
      scheduleList: scheduleList,
      dayList: dayList,
      searchText: searchText,
      selectedTeacherId: selectedTeacherId,
      selectedClassId: selectedClassId,
      selectedDayId: selectedDayId,
      selectedJamPelajaran: selectedLessonHour,
    );
  }
}
