import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A standardized inline error state widget for use inside screen bodies.
///
/// Unlike [ErrorScreen] (which is a full Scaffold), this widget can be
/// embedded inside an existing page layout alongside headers, filters, etc.
///
/// Provides a consistent error display with:
/// - Error icon
/// - Title and message
/// - Retry button with role-based color
///
/// Usage:
/// ```dart
/// if (errorMessage != null)
///   AppErrorState(
///     message: errorMessage,
///     onRetry: loadData,
///     role: 'guru',
///   )
/// ```
class AppErrorState extends StatelessWidget {
  /// The error message to display.
  final String? message;

  /// Called when the retry button is pressed.
  final VoidCallback onRetry;

  /// User role for theming the retry button.
  final String? role;

  /// Optional title text. Defaults to 'Terjadi Kesalahan'.
  final String? title;

  /// Optional icon. Defaults to error_outline.
  final IconData icon;

  const AppErrorState({
    super.key,
    this.message,
    required this.onRetry,
    this.role,
    this.title,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = role != null
        ? ColorUtils.getRoleColor(role!)
        : ColorUtils.primaryColor;

    // Wrap the column in a scroll view so verbose backend error
    // messages (multi-paragraph DioException dumps, RFC links, etc.)
    // don't overflow the constrained body region of small phone
    // screens. The `mainAxisSize: min` keeps the layout vertically
    // centered when the message is short — only kicks in when the
    // content actually exceeds the viewport.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.red.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.v16,
            Text(
              title ?? 'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              AppSpacing.v8,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  message!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            AppSpacing.v20,
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
