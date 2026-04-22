import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/admin_attendance_report_controller.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_report_filter_sheet.dart';

/// Mixin for filter operations in admin report screen.
/// Handles filter state, chip building, clearing.
mixin AdminReportFilterMixin on ConsumerState<AdminAttendanceReportScreen> {
  // Access state variables from main state class
  AdminAttendanceReportController get controller;
  String? get selectedDateFilter;
  set selectedDateFilter(String? value);
  List<String> get selectedSubjectIds;
  List<String> get selectedClassIds;
  List<String> get selectedDayIds;
  List<String> get selectedLessonHourIds;
  bool get hasActiveFilter;
  set hasActiveFilter(bool value);
  List<dynamic> get subjectList;
  List<dynamic> get classList;
  List<dynamic> get lessonHours;
  Color get primaryColor;

  Future<void> loadData({bool useCache = true});
  Future<void> forceRefresh();

  void checkActiveFilter() {
    setState(() {
      hasActiveFilter = controller.checkActiveFilter(
        selectedDateFilter: selectedDateFilter,
        selectedSubjectIds: selectedSubjectIds,
        selectedClassIds: selectedClassIds,
        selectedDayIds: selectedDayIds,
        selectedLessonHourIds: selectedLessonHourIds,
      );
    });
  }

  void clearAllFilters() {
    setState(() {
      selectedDateFilter = null;
      selectedSubjectIds.clear();
      selectedClassIds.clear();
      selectedDayIds.clear();
      selectedLessonHourIds.clear();
      hasActiveFilter = false;
    });
  }

  List<ActiveFilter> buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    return controller.buildFilterChips(
      languageProvider: languageProvider,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      subjectList: subjectList,
      classList: classList,
      // Each chip's onRemove mutates screen state
      onRemoveSideEffect: (mutation) {
        setState(mutation);
        checkActiveFilter();
        loadData();
      },
    );
  }

  void showFilterSheet() {
    showAttendanceReportFilterSheet(
      context: context,
      ref: ref,
      primaryColor: primaryColor,
      initialDate: selectedDateFilter,
      initialSubjectIds: selectedSubjectIds,
      initialClassIds: selectedClassIds,
      initialDayIds: selectedDayIds,
      initialLessonHourIds: selectedLessonHourIds,
      subjectList: subjectList,
      classList: classList,
      lessonHours: lessonHours,
      onApply: (result) {
        setState(() {
          selectedDateFilter = result.selectedDate;
          selectedSubjectIds
            ..clear()
            ..addAll(result.selectedSubjectIds);
          selectedClassIds
            ..clear()
            ..addAll(result.selectedClassIds);
          selectedDayIds
            ..clear()
            ..addAll(result.selectedDayIds);
          selectedLessonHourIds
            ..clear()
            ..addAll(result.selectedLessonHourIds);
          checkActiveFilter();
        });
        loadData(); // Reload data with new filters
      },
    );
  }
}
