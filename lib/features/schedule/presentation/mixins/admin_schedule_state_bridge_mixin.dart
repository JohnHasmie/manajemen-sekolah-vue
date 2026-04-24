import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';

/// State bridge mixin: provides all getter/setter bridges for data and filter mixins.
///
/// Centralizes the repetitive bridge getters/setters so they don't clutter the main
/// state class. This mixin just provides pass-through access to the fields in the
/// main state class — the actual field declarations and business logic live in the
/// state class or in AdminScheduleDataMixin/AdminScheduleFilterMixin.
mixin AdminScheduleStateBridgeMixin
    on ConsumerState<TeachingScheduleManagementScreen> {
  // These are declared/implemented by the main state class

  // ===== Data getters =====
  AdminScheduleController get controller;
  List<dynamic> get scheduleList;
  List<dynamic> get subjectList;
  List<dynamic> get classList;
  List<dynamic> get dayList;
  List<dynamic> get termList;
  List<dynamic> get lessonHourList;
  bool get isLoading;
  String get selectedTerm;
  String get selectedAcademicYear;
  int get currentPage;
  int get perPage;
  bool get hasMoreData;
  bool get isLoadingMore;
  String? get lastCachedAcademicYear;
  String? get lastCachedTerm;
  List<dynamic> get availableTeachers;
  List<dynamic> get availableClasses;
  List<dynamic> get availableDays;
  List<dynamic> get availableSemesters;
  List<dynamic> get availableAcademicYears;

  // ===== Filter getters =====
  String? get selectedTeacherId;
  String? get selectedClassId;
  String? get selectedDayId;
  String? get selectedFilterTerm;
  String? get selectedLessonHour;
  bool get hasActiveFilter;

  // ===== Data setters =====
  void updateScheduleList(List<dynamic> value);
  void updateSubjectList(List<dynamic> value);
  void updateClassList(List<dynamic> value);
  void updateDayList(List<dynamic> value);
  void updateTermList(List<dynamic> value);
  void updateLessonHourList(List<dynamic> value);
  void updateIsLoading(bool value);
  void updateCurrentPage(int value);
  void updateHasMoreData(bool value);
  void updateIsLoadingMore(bool value);
  void updateLastCachedAcademicYear(String? value);
  void updateLastCachedTerm(String? value);
  void updateAvailableTeachers(List<dynamic> value);
  void updateAvailableClasses(List<dynamic> value);
  void updateAvailableDays(List<dynamic> value);
  void updateAvailableSemesters(List<dynamic> value);
  void updateAvailableAcademicYears(List<dynamic> value);
  void updateSelectedAcademicYear(String value);
  void updateSelectedTerm(String value);

  // ===== Filter setters =====
  void updateSelectedTeacherId(String? value);
  void updateSelectedClassId(String? value);
  void updateSelectedDayId(String? value);
  void updateSelectedFilterTerm(String? value);
  void updateSelectedLessonHour(String? value);
  void updateHasActiveFilter(bool value);
}
