import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';

/// Handles filter logic for [StudentManagementScreenState].
mixin FilterMixin on ConsumerState<StudentManagementScreen> {
  String? get selectedStatusFilter;
  set selectedStatusFilter(String? value);
  List<String> get selectedClassIds;
  set selectedClassIds(List<String> value);
  String? get selectedGenderFilter;
  set selectedGenderFilter(String? value);
  String? get selectedGradeLevel;
  set selectedGradeLevel(String? value);
  String? get selectedGuardian;
  set selectedGuardian(String? value);
  bool get hasActiveFilter;
  set hasActiveFilter(bool value);
  String get searchText;
  int get currentPage;
  set currentPage(int value);
  List<dynamic> get classList;

  Future<void> loadData({bool resetPage = true});

  void checkActiveFilter() => _checkActiveFilter();
  void _checkActiveFilter() {
    setState(() {
      hasActiveFilter = ref
          .read(adminStudentControllerProvider)
          .checkActiveFilter(
            selectedStatusFilter: selectedStatusFilter,
            selectedClassIds: selectedClassIds,
            selectedGenderFilter: selectedGenderFilter,
            selectedGradeLevel: selectedGradeLevel,
            selectedGuardian: selectedGuardian,
            searchText: searchText,
          );
    });
  }

  void _clearAllFilters() {
    setState(() {
      selectedStatusFilter = null;
      selectedClassIds = [];
      selectedGenderFilter = null;
      selectedGradeLevel = null;
      selectedGuardian = null;
      currentPage = 1;
      hasActiveFilter = false;
    });
    loadData();
  }

  List<ActiveFilter> buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    void onChanged() {
      _checkActiveFilter();
      loadData();
    }

    return ref
        .read(adminStudentControllerProvider)
        .buildFilterChips(
          selectedStatusFilter: selectedStatusFilter,
          selectedClassIds: selectedClassIds,
          selectedGenderFilter: selectedGenderFilter,
          selectedGuardian: selectedGuardian,
          classList: classList,
          languageProvider: languageProvider,
          onClearStatus: () {
            setState(() => selectedStatusFilter = null);
            onChanged();
          },
          onClearClass: (classId) {
            setState(() => selectedClassIds.remove(classId));
            onChanged();
          },
          onClearGender: () {
            setState(() => selectedGenderFilter = null);
            onChanged();
          },
          onClearGuardian: () {
            setState(() => selectedGuardian = null);
            onChanged();
          },
        );
  }
}
