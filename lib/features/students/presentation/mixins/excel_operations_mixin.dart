import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';

/// Mixin for Excel import/export operations.
///
/// Handles exporting student data to Excel, importing from Excel files,
/// and downloading templates.
mixin ExcelOperationsMixin on ConsumerState<StudentManagementScreen> {
  // Abstract properties
  abstract List<String> selectedClassIds;
  abstract String? selectedGradeLevel;
  abstract String? selectedGenderFilter;
  abstract String searchText;

  TextEditingController get searchController;

  /// Public interface for loading data
  Future<void> loadData({bool resetPage = true});

  /// Exports current student data to Excel file.
  Future<void> exportToExcel() async {
    await ref
        .read(adminStudentControllerProvider)
        .exportToExcel(
          context: context,
          selectedClassIds: selectedClassIds,
          selectedGradeLevel: selectedGradeLevel,
          selectedGenderFilter: selectedGenderFilter,
          searchText: searchController.text,
        );
  }

  /// Imports student data from Excel file and reloads data.
  Future<void> importFromExcel() async {
    final imported = await ref
        .read(adminStudentControllerProvider)
        .importFromExcel(context);
    if (!imported || !mounted) return;
    await loadData();
    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Students imported successfully',
          'id': 'Data siswa berhasil diimpor',
        }),
      );
    }
  }

  /// Downloads Excel template for student import.
  Future<void> downloadTemplate() async {
    await ref.read(adminStudentControllerProvider).downloadTemplate(context);
  }
}
