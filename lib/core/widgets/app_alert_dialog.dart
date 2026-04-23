// Standardized alert dialog with gradient header and consistent styling.
//
// Replaces 27+ scattered AlertDialog / showDialog patterns with a
// single, reusable component that supports:
//   - Gradient header with icon
//   - Plain (non-gradient) variant
//   - Confirm/cancel buttons with consistent styling
//   - Static show() helper for one-liner usage
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A standardized alert dialog with a gradient header, message body,
/// and Cancel/Confirm action buttons.
///
/// Use the static [show] method for the most common case:
/// ```dart
/// final confirmed = await AppAlertDialog.show(
///   context: context,
///   title: 'Delete Student?',
///   message: 'This action cannot be undone.',
///   confirmText: 'Delete',
///   confirmColor: Colors.red,
/// );
/// if (confirmed == true) _deleteStudent();
/// ```
///
/// For info-only dialogs (no cancel button):
/// ```dart
/// AppAlertDialog.show(
///   context: context,
///   title: 'Success',
///   message: 'Data has been saved.',
///   icon: Icons.check_circle_rounded,
///   confirmText: 'OK',
///   confirmColor: Colors.green,
///   showCancel: false,
/// );
/// ```
class AppAlertDialog extends StatelessWidget {
  /// Dialog title in the gradient header.
  final String title;

  /// Body message below the header.
  final String message;

  /// Icon displayed in the header. Defaults to warning icon.
  final IconData icon;

  /// Primary color for the gradient header and confirm button.
  final Color confirmColor;

  /// Confirm button label.
  final String confirmText;

  /// Cancel button label.
  final String cancelText;

  /// Whether to show the cancel button.
  final bool showCancel;

  /// Optional content widget displayed below the message.
  /// Useful for checkboxes, input fields, etc.
  final Widget? extraContent;

  const AppAlertDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.warning_rounded,
    this.confirmColor = Colors.red,
    this.confirmText = 'Konfirmasi',
    this.cancelText = 'Batal',
    this.showCancel = true,
    this.extraContent,
  });

  /// Shows this dialog and returns `true` if confirmed,
  /// `false` if cancelled, or `null` if dismissed.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.warning_rounded,
    Color confirmColor = Colors.red,
    String confirmText = 'Konfirmasi',
    String cancelText = 'Batal',
    bool showCancel = true,
    Widget? extraContent,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppAlertDialog(
        title: title,
        message: message,
        icon: icon,
        confirmColor: confirmColor,
        confirmText: confirmText,
        cancelText: cancelText,
        showCancel: showCancel,
        extraContent: extraContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      elevation: 8,
      shadowColor: Colors.black26,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildHeader(), _buildBody(), _buildActions(context)],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [confirmColor, confirmColor.withValues(alpha: 0.85)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        24,
        AppSpacing.xl,
        8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (extraContent != null) ...[
            const SizedBox(height: AppSpacing.lg),
            extraContent!,
          ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          if (showCancel) ...[
            Expanded(child: _cancelButton(context)),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(child: _confirmButton(context)),
        ],
      ),
    );
  }

  Widget _cancelButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.pop(context, false),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Text(
        cancelText,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _confirmButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.pop(context, true),
      style: ElevatedButton.styleFrom(
        backgroundColor: confirmColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
      ),
      child: Text(
        confirmText,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
