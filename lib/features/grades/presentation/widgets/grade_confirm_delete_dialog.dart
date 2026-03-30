// Confirmation dialog before permanently deleting all grades for one assessment.
// Like a Vue <ConfirmDeleteModal> — shows a red warning and Cancel / Delete buttons.
// Deletion is NOT performed here; it is triggered via the [onConfirm] callback.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A destructive-action confirmation dialog for deleting an assessment column.
///
/// Mirrors what `_confirmDeleteAssessment` used to build inline.
/// Like a Vue `<ConfirmDeleteModal>` component — data in via props,
/// result out via [onConfirm] callback (like `$emit('confirm')`).
///
/// No API calls happen here; the parent screen owns the delete logic.
class GradeConfirmDeleteDialog extends StatelessWidget {
  /// Pre-formatted confirmation message body (bilingual resolution done by parent).
  final String confirmMessage;

  /// Label for the Cancel button.
  final String labelCancel;

  /// Label for the Delete button.
  final String labelDelete;

  /// Label for the dialog header title, e.g. "Delete Assessment? / Hapus Penilaian?".
  final String labelHeader;

  /// Called when the user confirms deletion. Parent runs `_deleteAssessment()`.
  final VoidCallback onConfirm;

  const GradeConfirmDeleteDialog({
    super.key,
    required this.confirmMessage,
    required this.labelCancel,
    required this.labelDelete,
    required this.labelHeader,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Red gradient header ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.error600,
                  ColorUtils.error600.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    labelHeader,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body text ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              confirmMessage,
              style: TextStyle(color: ColorUtils.slate700, fontSize: 14),
            ),
          ),

          // ── Cancel / Delete buttons ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      labelCancel,
                      style: TextStyle(color: ColorUtils.slate600),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      AppNavigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.error600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      labelDelete,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens [GradeConfirmDeleteDialog] as a standard dialog.
///
/// The screen calls this thin wrapper instead of building the dialog inline —
/// like calling a Vue composable `confirmDelete(header, onConfirm)`.
void showGradeConfirmDeleteDialog({
  required BuildContext context,
  required String confirmMessage,
  required String labelCancel,
  required String labelDelete,
  required String labelHeader,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (_) => GradeConfirmDeleteDialog(
      confirmMessage: confirmMessage,
      labelCancel: labelCancel,
      labelDelete: labelDelete,
      labelHeader: labelHeader,
      onConfirm: onConfirm,
    ),
  );
}
