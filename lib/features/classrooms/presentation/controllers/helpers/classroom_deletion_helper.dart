import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';

/// Encapsulates class deletion workflow.
class ClassroomDeletionHelper {
  final Ref ref;

  const ClassroomDeletionHelper(this.ref);

  /// Shows confirmation dialog and deletes class if confirmed.
  ///
  /// Returns `true` on success, `false` if cancelled or error.
  Future<bool> deleteClass(
    Map<String, dynamic> classData,
    BuildContext context,
    Future<void> Function(String) apiDelete,
  ) async {
    final languageProvider = ref.read(languageRiverpod);

    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: languageProvider.getTranslatedText({
        'en': 'Delete Class',
        'id': 'Hapus Kelas',
      }),
      message: languageProvider.getTranslatedText({
        'en': 'Are you sure you want to delete this class?',
        'id': 'Yakin ingin menghapus kelas ini?',
      }),
      confirmText: languageProvider.getTranslatedText({
        'en': 'Delete',
        'id': 'Hapus',
      }),
      isDestructive: true,
    );

    if (confirmed != true) return false;

    try {
      await apiDelete(classData['id'].toString());
      if (context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': 'Class successfully deleted',
            'id': 'Kelas berhasil dihapus',
          }),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        final errorMsg = languageProvider.getTranslatedText({
          'en': 'Gagal menghapus kelas',
          'id': 'Gagal menghapus kelas',
        });
        SnackBarUtils.showError(
          context,
          '$errorMsg: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
      return false;
    }
  }
}
