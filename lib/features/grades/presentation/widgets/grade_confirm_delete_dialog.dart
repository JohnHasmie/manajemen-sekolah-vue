// Confirmation bottom sheet before permanently deleting all grades for one
// assessment. Migrated from a hand-rolled `showDialog(Dialog(...))`
// red-gradient
// dialog to the shared [ActionConfirmSheet] so destructive flows across the
// app stay visually consistent (drag handle → red gradient header → message →
// Samsung-safe Cancel/Delete footer).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';

/// Opens an [ActionConfirmSheet] for deleting an assessment column.
///
/// The screen calls this thin wrapper instead of building the dialog inline —
/// like calling a Vue composable `confirmDelete(header, onConfirm)`.
///
/// [onConfirm] only fires after the user explicitly taps the destructive
/// confirm button; tapping Cancel (or dismissing the sheet) is a no-op.
Future<void> showGradeConfirmDeleteDialog({
  required BuildContext context,
  required String confirmMessage,
  required String labelCancel,
  required String labelDelete,
  required String labelHeader,
  required VoidCallback onConfirm,
}) async {
  final confirmed = await ActionConfirmSheet.show(
    context: context,
    title: labelHeader,
    message: confirmMessage,
    confirmText: labelDelete,
    cancelText: labelCancel,
    icon: Icons.delete_outline,
    isDestructive: true,
  );
  if (confirmed == true) {
    onConfirm();
  }
}
