// A confirmation bottom sheet for destructive or important actions.
//
// Replaces 15+ inline showModalBottomSheet confirmation patterns
// for delete, approve, reject, and submit actions.
//
// Now composes DragHandle primitive for consistency.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/drag_handle.dart';

/// A confirmation bottom sheet with icon, title, message,
/// and confirm/cancel buttons.
///
/// Use the static [show] method for convenience:
/// ```dart
/// final confirmed = await ActionConfirmSheet.show(
///   context: context,
///   title: 'Delete Record?',
///   message: 'This action cannot be undone.',
///   confirmText: 'Delete',
///   isDestructive: true,
/// );
/// if (confirmed == true) _deleteRecord();
/// ```
class ActionConfirmSheet extends StatelessWidget {
  /// Title text.
  final String title;

  /// Descriptive message.
  final String message;

  /// Confirm button label. Default: 'Confirm'.
  final String confirmText;

  /// Cancel button label. Default: 'Cancel'.
  final String cancelText;

  /// Color of the confirm button. Overrides [isDestructive] when set.
  final Color? confirmColor;

  /// Icon displayed above the title.
  final IconData icon;

  /// If true, uses red styling for destructive actions.
  final bool isDestructive;

  const ActionConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Konfirmasi',
    this.cancelText = 'Batal',
    this.confirmColor,
    this.icon = Icons.warning_rounded,
    this.isDestructive = false,
  });

  Color get _effectiveColor =>
      confirmColor ?? (isDestructive ? Colors.red : Colors.blue);

  /// Shows an [ActionConfirmSheet] as a modal bottom sheet.
  ///
  /// Returns `true` if the user tapped confirm, `false` or
  /// `null` otherwise.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Konfirmasi',
    String cancelText = 'Batal',
    Color? confirmColor,
    IconData icon = Icons.warning_rounded,
    bool isDestructive = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ActionConfirmSheet(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        icon: icon,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DragHandle(),

          // Icon
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _effectiveColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _effectiveColor, size: 28),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              left: AppSpacing.xl,
              right: AppSpacing.xl,
            ),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),

          // Message
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              left: AppSpacing.xxl,
              right: AppSpacing.xxl,
            ),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.lg + bottomPadding,
            ),
            child: Row(
              children: [
                // Cancel
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      cancelText,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Confirm
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _effectiveColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      confirmText,
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
