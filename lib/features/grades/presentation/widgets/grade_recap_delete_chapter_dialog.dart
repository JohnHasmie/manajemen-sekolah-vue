// Delete-chapter confirmation dialog for the grade recap screen.
// Extracted from _GradeRecapPageState._deleteChapter() to keep the main
// screen file lean.
// Like a Vue `<DeleteColumnConfirmModal>` component — purely presentational.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Shows an [AlertDialog] asking the user to confirm deletion of a bab column.
///
/// [onConfirm] is called (after closing the dialog) when the user taps the
/// delete button.  All actual data-mutation logic lives in the callback, which
/// stays in the parent [_GradeRecapPageState] so no state is leaked here.
///
/// In Laravel terms: a "confirm destroy" modal before `DELETE /chapters/{id}`.
void showGradeRecapDeleteChapterDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppLocalizations.deleteMaterial.tr),
      content: Text(AppLocalizations.deleteColumnConfirm.tr),
      actions: [
        TextButton(
          onPressed: () => AppNavigator.pop(context),
          child: Text(AppLocalizations.cancel.tr),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            AppNavigator.pop(context);
            onConfirm();
          },
          child: Text(AppLocalizations.delete.tr),
        ),
      ],
    ),
  );
}
