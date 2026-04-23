import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/students/presentation/screens/student_detail_screen.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_add_edit_dialog.dart';

/// Mixin for student action operations (view, edit, delete, etc.).
///
/// Handles navigation to student details, showing add/edit dialogs,
/// and deleting students.
mixin StudentActionsMixin on ConsumerState<StudentManagementScreen> {
  // Abstract properties
  abstract List<dynamic> classList;

  /// Public interface for loading data
  Future<void> loadData({bool resetPage = true});

  /// Gets localized gender text for a student.
  String getGenderText(String? gender, LanguageProvider languageProvider) {
    return ref
        .read(adminStudentControllerProvider)
        .getGenderText(gender, languageProvider);
  }

  /// Navigates to student detail screen.
  void navigateToStudentDetail(Map<String, dynamic> student) {
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    AppNavigator.push(
      context,
      StudentDetailScreen(
        student: student,
        onEdit: isReadOnly ? null : () => showStudentDialog(student: student),
      ),
    );
  }

  /// Shows add/edit student dialog.
  void showStudentDialog({Map<String, dynamic>? student}) {
    showStudentAddEditDialog(
      context: context,
      ref: ref,
      classList: classList,
      primaryColor: ColorUtils.getRoleColor('admin'),
      student: student,
      onSave: loadData,
    );
  }

  /// Deletes a student and reloads data.
  Future<void> deleteStudent(Map<String, dynamic> student) async {
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
}
