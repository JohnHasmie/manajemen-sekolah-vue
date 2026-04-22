import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';

/// Helper class for student deletion operations.
/// Handles showing confirmation dialogs and performing deletions.
class StudentDeletionHelper {
  /// Deletes a student after showing a confirmation dialog.
  /// Returns true if deleted successfully, false if cancelled or failed.
  /// Screen calls loadData() and shows snackbar after getting true.
  static Future<bool> deleteStudent(
    Map<String, dynamic> student,
    BuildContext context,
    Ref ref,
  ) async {
    final languageProvider = ref.read(languageRiverpod);
    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: languageProvider.getTranslatedText({
        'en': 'Delete Student',
        'id': 'Hapus Siswa',
      }),
      message: languageProvider.getTranslatedText({
        'en': 'Are you sure you want to delete this student?',
        'id': 'Yakin ingin menghapus siswa ini?',
      }),
      confirmText: languageProvider.getTranslatedText({
        'en': 'Delete',
        'id': 'Hapus',
      }),
      isDestructive: true,
    );

    if (confirmed != true) return false;

    try {
      await getIt<ApiStudentService>().deleteStudent(student['id']);
      return true;
    } catch (e) {
      AppLogger.error('student', 'Delete student error: $e');
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          ref.read(languageRiverpod).getTranslatedText({
            'en':
                'Failed to delete student: ${ErrorUtils.getFriendlyMessage(e)}',
            'id': 'Gagal menghapus siswa: ${ErrorUtils.getFriendlyMessage(e)}',
          }),
        );
      }
      return false;
    }
  }
}
