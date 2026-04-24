import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_filter_sheet.dart';

/// Mixin for filter operations and display.
///
/// Handles building filter chips, checking active filters,
/// showing filter sheets, and clearing filters.
mixin FilterHelperMixin on ConsumerState<StudentManagementScreen> {
  // Abstract properties
  abstract int currentPage;
  abstract List<dynamic> classList;
  abstract List<String> selectedClassIds;
  abstract String? selectedGradeLevel;
  abstract String? selectedGenderFilter;
  abstract String? selectedGuardian;
  abstract String? selectedStatusFilter;
  abstract bool hasActiveFilter;
  abstract String searchText;

  TextEditingController get searchController;

  /// Public interface for loading data
  Future<void> loadData({bool resetPage = true});

  /// Builds filter chip list for display in header.
  List<Map<String, dynamic>> buildFilterChips(LanguageProvider lang) {
    return ref
        .read(adminStudentControllerProvider)
        .buildFilterChips(
          selectedStatusFilter: selectedStatusFilter,
          selectedClassIds: selectedClassIds,
          selectedGenderFilter: selectedGenderFilter,
          selectedGuardian: selectedGuardian,
          classList: classList,
          languageProvider: lang,
          onFilterChanged: () {
            checkActiveFilter();
            loadData();
          },
        );
  }

  /// Updates [hasActiveFilter] based on current filter state.
  void checkActiveFilter() {
    setState(() {
      hasActiveFilter = ref
          .read(adminStudentControllerProvider)
          .checkActiveFilter(
            selectedStatusFilter: selectedStatusFilter,
            selectedClassIds: selectedClassIds,
            selectedGenderFilter: selectedGenderFilter,
            selectedGradeLevel: selectedGradeLevel,
            selectedGuardian: selectedGuardian,
            searchText: searchController.text,
          );
    });
  }

  /// Shows the filter bottom sheet.
  void showFilterSheet() {
    showStudentFilterSheet(
      context: context,
      classList: classList,
      primaryColor: ColorUtils.getRoleColor('admin'),
      initialStatus: selectedStatusFilter,
      initialClassIds: selectedClassIds,
      initialGender: selectedGenderFilter,
      initialGuardian: selectedGuardian,
      translate: ref.read(languageRiverpod).getTranslatedText,
      onApply:
          ({
            required String? status,
            required List<String> classIds,
            required String? gender,
            required String? guardian,
          }) {
            setState(() {
              selectedStatusFilter = status;
              selectedClassIds = classIds;
              selectedGenderFilter = gender;
              selectedGuardian = guardian;
            });
            checkActiveFilter();
            loadData();
          },
    );
  }

  /// Clears all active filters and resets pagination.
  void clearAllFilters() {
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
}
