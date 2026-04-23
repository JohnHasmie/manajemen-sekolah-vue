import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_add_edit_dialog.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_filter_sheet.dart';

/// Handles dialog and sheet interactions for
/// [StudentManagementScreenState].
mixin DialogMixin on ConsumerState<StudentManagementScreen> {
  String? get selectedStatusFilter;
  set selectedStatusFilter(String? value);
  List<String> get selectedClassIds;
  set selectedClassIds(List<String> value);
  String? get selectedGenderFilter;
  set selectedGenderFilter(String? value);
  String? get selectedGuardian;
  set selectedGuardian(String? value);
  List<dynamic> get classList;
  int get currentPage;
  set currentPage(int value);
  bool get hasActiveFilter;
  set hasActiveFilter(bool value);

  Future<void> loadData({bool resetPage = true});
  void _checkActiveFilter();

  void showFilterSheet() => _showFilterSheet();
  void _showFilterSheet() {
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
            _checkActiveFilter();
            loadData();
          },
    );
  }

  void showStudentDialog({Map<String, dynamic>? student}) =>
      _showStudentDialog(student: student);
  void _showStudentDialog({Map<String, dynamic>? student}) {
    showStudentAddEditDialog(
      context: context,
      ref: ref,
      classList: classList,
      primaryColor: ColorUtils.getRoleColor('admin'),
      student: student,
      onSave: loadData,
    );
  }
}
