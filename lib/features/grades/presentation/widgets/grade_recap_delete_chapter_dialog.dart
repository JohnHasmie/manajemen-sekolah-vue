// Delete-chapter confirmation dialog for the grade recap screen.
// Extracted from _GradeRecapPageState._deleteChapter() to keep the main
// screen file lean.
// Like a Vue `<DeleteColumnConfirmModal>` component — purely presentational.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Shows an [AppAlertDialog] asking the user to confirm deletion of a bab column.
///
/// [onConfirm] is called (after closing the dialog) when the user taps the
/// delete button.  All actual data-mutation logic lives in the callback, which
/// stays in the parent [_GradeRecapPageState] so no state is leaked here.
///
/// In Laravel terms: a "confirm destroy" modal before `DELETE /chapters/{id}`.
Future<void> showGradeRecapDeleteChapterDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) async {
  final confirmed = await AppAlertDialog.show(
    context: context,
    title: AppLocalizations.deleteMaterial.tr,
    message: AppLocalizations.deleteColumnConfirm.tr,
    confirmText: AppLocalizations.delete.tr,
    cancelText: AppLocalizations.cancel.tr,
    confirmColor: Colors.red,
    showCancel: true,
  );

  if (confirmed == true) {
    onConfirm();
  }
}
