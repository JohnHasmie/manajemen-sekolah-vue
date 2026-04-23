import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/students/presentation/screens/student_detail_screen.dart';

/// Handles user actions (delete, export, import, navigate) for
/// [StudentManagementScreenState].
mixin ActionMixin on ConsumerState<StudentManagementScreen> {
  String get searchText;
  List<String> get selectedClassIds;
  String? get selectedGradeLevel;
  String? get selectedGenderFilter;

  Future<void> loadData({bool resetPage = true});

  Future<void> deleteStudent(Map<String, dynamic> student) =>
      _deleteStudent(student);
  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final deleted = await ref
        .read(adminStudentControllerProvider)
        .deleteStudent(student, context);
    if (!deleted || !mounted) return;
    await loadData();
    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Student successfully deleted',
          'id': 'Siswa berhasil dihapus',
        }),
      );
    }
  }

  Future<void> exportToExcel() => _exportToExcel();
  Future<void> _exportToExcel() async {
    await ref
        .read(adminStudentControllerProvider)
        .exportToExcel(
          context: context,
          selectedClassIds: selectedClassIds,
          selectedGradeLevel: selectedGradeLevel,
          selectedGenderFilter: selectedGenderFilter,
          searchText: searchText,
        );
  }

  Future<void> importFromExcel() => _importFromExcel();
  Future<void> _importFromExcel() async {
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

  Future<void> downloadTemplate() => _downloadTemplate();
  Future<void> _downloadTemplate() async {
    await ref.read(adminStudentControllerProvider).downloadTemplate(context);
  }

  void navigateToStudentDetail(Map<String, dynamic> student) =>
      _navigateToStudentDetail(student);
  void _navigateToStudentDetail(Map<String, dynamic> student) {
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    AppNavigator.push(
      context,
      StudentDetailScreen(
        student: student,
        onEdit: isReadOnly ? null : () => _showStudentDialog(student: student),
      ),
    );
  }

  void _showStudentDialog({Map<String, dynamic>? student});

  String getGenderText(String? gender, LanguageProvider languageProvider) =>
      _getGenderText(gender, languageProvider);
  String _getGenderText(String? gender, LanguageProvider languageProvider) {
    return ref
        .read(adminStudentControllerProvider)
        .getGenderText(gender, languageProvider);
  }
}
