/// snackbar_utils.dart - Centralized snackbar display utilities.
/// Like Laravel's `session()->flash('success', 'message')` but for Flutter SnackBars.
///
/// Replaces 100+ scattered `ScaffoldMessenger.of(context).showSnackBar(...)` calls
/// with a clean, consistent API.
library;

import 'package:flutter/material.dart';

/// Utility class for displaying consistent SnackBars across the app.
class SnackBarUtils {
  SnackBarUtils._();

  /// Shows a success (green) snackbar.
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, backgroundColor: Colors.green);
  }

  /// Shows an error (red) snackbar.
  static void showError(BuildContext context, String message) {
    _show(context, message, backgroundColor: Colors.red);
  }

  /// Shows an error snackbar from an exception/error object.
  /// Extracts the message from common exception types.
  static void showErrorFromException(BuildContext context, dynamic error) {
    String message;
    if (error is Exception) {
      message = error.toString().replaceFirst('Exception: ', '');
    } else {
      message = error.toString();
    }
    showError(context, message);
  }

  /// Shows a warning (orange) snackbar.
  static void showWarning(BuildContext context, String message) {
    _show(context, message, backgroundColor: Colors.orange);
  }

  /// Shows an info (blue) snackbar.
  static void showInfo(BuildContext context, String message) {
    _show(context, message, backgroundColor: Colors.blue);
  }

  /// Clears any in-flight snackbars on the nearest [ScaffoldMessenger].
  ///
  /// Use this before kicking off a flow that transitions between
  /// inline-multi-step states on the same Scaffold (e.g. login →
  /// school picker → role picker), so a stale error toast from the
  /// previous step doesn't leak into the next.
  static void dismiss(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Shows a snackbar with one or more inline action buttons.
  ///
  /// Plain success / error / info snacks should keep using the simpler
  /// [showSuccess] / [showError] / [showInfo] helpers — this variant is
  /// intentionally heavier and reserved for richer "toast" flows where
  /// the user needs an inline rollback (Urungkan) or alternate-path
  /// nudge (Paksa simpan) tied to the toast's lifetime.
  ///
  /// Unlike Flutter's built-in [SnackBarAction] (which only allows one
  /// per snackbar), this helper supports any number of action buttons
  /// by composing a custom [Row] inside the snack body. The bar is
  /// auto-dismissed when an action fires — handlers shouldn't pop it
  /// manually.
  static void showWithActions(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required List<SnackBarToastAction> actions,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            for (final a in actions)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: a.labelColor ?? Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    a.onTap();
                  },
                  child: Text(
                    a.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      ),
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    Color backgroundColor = Colors.black87,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Descriptor for an inline action button rendered inside a snackbar
/// by [SnackBarUtils.showWithActions]. Multiple actions are supported
/// (unlike Flutter's built-in [SnackBarAction] which only allows one).
///
/// Used by the admin Jadwal drag-to-reschedule flow for the Urungkan
/// (undo) + Paksa simpan (force-save) buttons that ride alongside the
/// success / conflict toasts.
class SnackBarToastAction {
  /// Button label — displayed in upper-case-ish chrome.
  final String label;

  /// Handler invoked after the snackbar is dismissed automatically.
  final VoidCallback onTap;

  /// Optional override for the label color. Defaults to white so the
  /// button reads against both success-green and error-red backgrounds.
  final Color? labelColor;

  const SnackBarToastAction({
    required this.label,
    required this.onTap,
    this.labelColor,
  });
}
