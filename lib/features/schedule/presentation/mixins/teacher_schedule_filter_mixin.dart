import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/teacher_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_filter_sheet.dart';

/// Mixin for filter logic and UI.
mixin TeacherScheduleFilterMixin on ConsumerState<TeachingScheduleScreen> {
  List<String> selectedDayIdsInternal = [];
  String? selectedFilterSemesterInternal;
  String? selectedClassIdInternal;
  bool hasActiveFilterInternal = false;
  List<Map<String, String>> availableClassesInternal = [];
  List<dynamic> termListInternal = [];

  final List<String> dayOptionsInternal = [
    'Semua Hari',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  final Map<String, String> dayIdMapInternal = {
    'Senin': '1',
    'Selasa': '2',
    'Rabu': '3',
    'Kamis': '4',
    'Jumat': '5',
    'Sabtu': '6',
  };

  void checkActiveFilter(String selectedTerm) {
    setState(() {
      hasActiveFilterInternal =
          selectedDayIdsInternal.isNotEmpty ||
          selectedClassIdInternal != null ||
          (selectedFilterSemesterInternal != null &&
              selectedFilterSemesterInternal != selectedTerm);
    });
  }

  void clearAllFilters(
    String selectedTerm,
    Future<void> Function() loadTermData,
    Future<void> Function({
      required TextEditingController searchController,
      required List<String> selectedDayIds,
      required String? selectedClassId,
      required String? selectedFilterSemester,
      required Map<String, String> dayIdMap,
    })
    loadSchedule,
    TextEditingController searchController,
  ) {
    setState(() {
      selectedDayIdsInternal.clear();
      selectedFilterSemesterInternal = null;
      selectedClassIdInternal = null;
      checkActiveFilter(selectedTerm);
    });
    loadTermData().then(
      (_) => loadSchedule(
        searchController: searchController,
        selectedDayIds: selectedDayIdsInternal,
        selectedClassId: selectedClassIdInternal,
        selectedFilterSemester: selectedFilterSemesterInternal,
        dayIdMap: dayIdMapInternal,
      ),
    );
  }

  List<ActiveFilter> buildFilterChips(
    LanguageProvider languageProvider,
    String selectedTerm,
    Future<void> Function({
      required TextEditingController searchController,
      required List<String> selectedDayIds,
      required String? selectedClassId,
      required String? selectedFilterSemester,
      required Map<String, String> dayIdMap,
    })
    loadSchedule,
    TextEditingController searchController,
  ) {
    final List<ActiveFilter> filterChips = [];

    for (final dayId in selectedDayIdsInternal) {
      final dayNameRaw = dayOptionsInternal.firstWhere(
        (h) => dayIdMapInternal[h] == dayId,
        orElse: () => 'Hari',
      );

      final dayMap = {
        'senin': {'en': 'Monday', 'id': 'Senin'},
        'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
        'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
        'kamis': {'en': 'Thursday', 'id': 'Kamis'},
        'jumat': {'en': 'Friday', 'id': 'Jumat'},
        'jum\'at': {'en': 'Friday', 'id': 'Jumat'},
        'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
        'minggu': {'en': 'Sunday', 'id': 'Minggu'},
      };

      final normalizedKey = dayNameRaw.toLowerCase();
      final label = dayMap[normalizedKey] != null
          ? languageProvider.getTranslatedText(dayMap[normalizedKey]!)
          : dayNameRaw;

      filterChips.add(ActiveFilter(
        label: label,
        onRemove: () {
          setState(() {
            selectedDayIdsInternal.remove(dayId);
            checkActiveFilter(selectedTerm);
          });
          loadSchedule(
            searchController: searchController,
            selectedDayIds: selectedDayIdsInternal,
            selectedClassId: selectedClassIdInternal,
            selectedFilterSemester: selectedFilterSemesterInternal,
            dayIdMap: dayIdMapInternal,
          );
        },
      ));
    }

    if (selectedClassIdInternal != null) {
      final cls = availableClassesInternal.firstWhere(
        (c) => c['id'] == selectedClassIdInternal,
        orElse: () => {'name': 'Class'},
      );
      filterChips.add(ActiveFilter(
        label: cls['name'] ?? 'Class',
        onRemove: () {
          setState(() {
            selectedClassIdInternal = null;
            checkActiveFilter(selectedTerm);
          });
          loadSchedule(
            searchController: searchController,
            selectedDayIds: selectedDayIdsInternal,
            selectedClassId: selectedClassIdInternal,
            selectedFilterSemester: selectedFilterSemesterInternal,
            dayIdMap: dayIdMapInternal,
          );
        },
      ));
    }

    if (selectedFilterSemesterInternal != null &&
        selectedFilterSemesterInternal != selectedTerm) {
      final semester = termListInternal.firstWhere(
        (s) => s['id'].toString() == selectedFilterSemesterInternal,
        orElse: () => {'nama': 'Semester $selectedFilterSemesterInternal'},
      );
      filterChips.add(ActiveFilter(
        label: semester['nama'] ?? 'Semester',
        onRemove: () {
          setState(() {
            selectedFilterSemesterInternal = null;
            checkActiveFilter(selectedTerm);
          });
          loadSchedule(
            searchController: searchController,
            selectedDayIds: selectedDayIdsInternal,
            selectedClassId: selectedClassIdInternal,
            selectedFilterSemester: selectedFilterSemesterInternal,
            dayIdMap: dayIdMapInternal,
          );
        },
      ));
    }

    return filterChips;
  }

  void showFilterSheet(
    Color primaryColor,
    LanguageProvider languageProvider,
    String selectedTerm,
    Future<void> Function({
      required TextEditingController searchController,
      required List<String> selectedDayIds,
      required String? selectedClassId,
      required String? selectedFilterSemester,
      required Map<String, String> dayIdMap,
    })
    loadSchedule,
    TextEditingController searchController,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherScheduleFilterSheet(
        primaryColor: primaryColor,
        dayOptions: dayOptionsInternal,
        dayIdMap: dayIdMapInternal,
        availableClasses: availableClassesInternal,
        semesterList: termListInternal,
        currentSemester: selectedTerm,
        selectedDayIds: selectedDayIdsInternal,
        selectedClassId: selectedClassIdInternal,
        selectedFilterSemester: selectedFilterSemesterInternal,
        languageProvider: languageProvider,
        onApply:
            ({
              required List<String> dayIds,
              required String? classId,
              required String? semester,
              required bool needsReload,
            }) {
              setState(() {
                selectedDayIdsInternal = dayIds;
                selectedClassIdInternal = classId;
                selectedFilterSemesterInternal = semester;
                checkActiveFilter(selectedTerm);
              });
              if (needsReload) {
                loadSchedule(
                  searchController: searchController,
                  selectedDayIds: selectedDayIdsInternal,
                  selectedClassId: selectedClassIdInternal,
                  selectedFilterSemester: selectedFilterSemesterInternal,
                  dayIdMap: dayIdMapInternal,
                );
              }
            },
      ),
    );
  }

  List<dynamic> getFilteredSchedules(
    List<dynamic> scheduleList,
    String searchText,
  ) {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    return ctrl.getFilteredSchedules(
      scheduleList: scheduleList,
      searchText: searchText,
      selectedDayIds: selectedDayIdsInternal,
      selectedClassId: selectedClassIdInternal,
      dayIdMap: dayIdMapInternal,
    );
  }

  // Getters and setters
  List<String> get selectedDayIds => selectedDayIdsInternal;
  String? get selectedFilterSemester => selectedFilterSemesterInternal;
  String? get selectedClassId => selectedClassIdInternal;
  bool get hasActiveFilter => hasActiveFilterInternal;
  List<Map<String, String>> get availableClasses => availableClassesInternal;
  List<String> get dayOptions => dayOptionsInternal;
  Map<String, String> get dayIdMap => dayIdMapInternal;
  List<dynamic> get termList => termListInternal;

  set selectedDayIds(List<String> v) => selectedDayIdsInternal = v;
  set selectedFilterSemester(String? v) => selectedFilterSemesterInternal = v;
  set selectedClassId(String? v) => selectedClassIdInternal = v;
  set hasActiveFilter(bool v) => hasActiveFilterInternal = v;
  set availableClasses(List<Map<String, String>> v) =>
      availableClassesInternal = v;
  set dayOptions(List<String> v) {}
  set dayIdMap(Map<String, String> v) {}
  set termList(List<dynamic> v) => termListInternal = v;
}
