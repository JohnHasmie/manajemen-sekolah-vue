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
