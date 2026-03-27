// Confirmation dialog component for destructive actions (delete, etc.).
//
// Like a Vue component `<ConfirmModal>` or a SweetAlert2 confirmation popup
// you would use in a Laravel/Vue app before deleting a record.
// Returns `true` via Navigator.pop when confirmed, `false` when cancelled.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A reusable confirmation dialog with a gradient header and confirm/cancel buttons.
///
/// Like a Vue `<ConfirmDialog>` component, or using SweetAlert2 in a Laravel app:
/// ```js
/// Swal.fire({ title: 'Delete?', confirmButtonText: 'Delete' })
/// ```
///
/// Props (parameters):
/// - [title] - dialog title displayed in the gradient header
/// - [content] - body message explaining the action
/// - [confirmText] - label for the confirm button (defaults to translated 'Delete')
/// - [confirmColor] - color theme for the header and confirm button
///
/// Returns `bool` via `Navigator.pop(context, true/false)`.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? _confirmText;
  final Color confirmColor;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    String? confirmText,
    this.confirmColor = Colors.red,
  }) : _confirmText = confirmText;

  String get confirmText => _confirmText ?? AppLocalizations.delete.tr;

  /// Builds the dialog UI with gradient header, message body, and cancel/confirm buttons.
  /// Like the `<template>` section of a Vue SFC modal component.
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  confirmColor,
                  confirmColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Actions
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      AppLocalizations.cancel.tr,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => AppNavigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      confirmText,
                      style: TextStyle(color: Colors.white),
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
