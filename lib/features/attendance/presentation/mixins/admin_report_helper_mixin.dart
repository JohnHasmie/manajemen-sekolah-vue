import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/admin_attendance_report_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';

/// Mixin for helper/utility methods in admin report screen.
/// Handles scroll, filtering helpers, color/gradient getters.
mixin AdminReportHelperMixin on ConsumerState<AdminAttendanceReportScreen> {
  // Access state variables from main state class
  AdminAttendanceReportController get controller;
  ScrollController get scrollController;
  List<AttendanceSummary> get attendanceSummaryList;
  String? get selectedDateFilter;
  List<String> get selectedSubjectIds;
  List<String> get selectedClassIds;
  List<String> get selectedDayIds;
  List<String> get selectedLessonHourIds;
  TextEditingController get searchController;
  bool get isLoadingClasses;
  set isLoadingClasses(bool value);
  List<dynamic> get classList;
  set classList(List<dynamic> value);
  List<dynamic> get fullTeacherList;
  set fullTeacherList(List<dynamic> value);
  List<dynamic> get subjectList;
  set subjectList(List<dynamic> value);
  List<dynamic> get lessonHours;
  set lessonHours(List<dynamic> value);

  Future<void> loadFilterData({bool useCache = true});
  Future<void> forceRefresh();
  Future<void> loadData({bool useCache = true});

  void loadMoreScrolling();

  Future<void> forceRefreshImpl() async {
    await controller.invalidateCaches(
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchController.text,
      showTableView: false,
    );
    if (classList.isEmpty) {
      loadFilterData(useCache: false);
    } else {
      await loadData(useCache: false);
    }
  }

  List<AttendanceSummary> getFilteredSummaries() {
    return controller.getFilteredSummaries(
      summaryList: attendanceSummaryList,
      searchText: searchController.text,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
    );
  }

  Color getPrimaryColor() => controller.getPrimaryColor();

  LinearGradient getCardGradient() => controller.getCardGradient();
}
