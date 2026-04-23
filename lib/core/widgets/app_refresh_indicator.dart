import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// A standardized pull-to-refresh wrapper used across all screens.
///
/// Provides consistent refresh UX:
/// - Role-based indicator color (defaults to current role color)
/// - Optional success/error snackbar feedback
/// - Standardized displacement and stroke width
/// - Error handling with user-friendly messages
///
/// Usage:
/// ```dart
/// AppRefreshIndicator(
///   onRefresh: () => forceRefresh(),
///   role: 'guru',
///   child: ListView(...),
/// )
/// ```
class AppRefreshIndicator extends StatelessWidget {
  /// The async callback triggered on pull-to-refresh.
  final Future<void> Function() onRefresh;

  /// The child widget (must be scrollable).
  final Widget child;

  /// The user role for theming the indicator color.
  /// If null, uses the app's default primary color.
  final String? role;

  /// Override the indicator color directly.
  /// Takes precedence over [role] if provided.
  final Color? color;

  /// Whether to show a success snackbar after refresh completes.
  final bool showSuccessFeedback;

  /// Custom success message. Defaults to 'Data berhasil diperbarui'.
  final String? successMessage;

  /// Whether to show an error snackbar if refresh throws.
  final bool showErrorFeedback;

  /// Custom error message. Defaults to 'Gagal memperbarui data'.
  final String? errorMessage;

  /// Displacement of the indicator from the top edge.
  final double displacement;

  /// Stroke width of the indicator circle.
  final double strokeWidth;

  /// Background color of the indicator circle.
  final Color? backgroundColor;

  /// Edge offset for the indicator (useful with SliverAppBar).
  final double edgeOffset;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.role,
    this.color,
    this.showSuccessFeedback = false,
    this.successMessage,
    this.showErrorFeedback = true,
    this.errorMessage,
    this.displacement = 40.0,
    this.strokeWidth = 2.5,
    this.backgroundColor,
    this.edgeOffset = 0.0,
  });

  Color _resolveColor() {
    if (color != null) return color!;
    if (role != null) return ColorUtils.getRoleColor(role!);
    return ColorUtils.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _handleRefresh(context),
      color: _resolveColor(),
      backgroundColor: backgroundColor ?? Colors.white,
      displacement: displacement,
      strokeWidth: strokeWidth,
      edgeOffset: edgeOffset,
      child: child,
    );
  }

  Future<void> _handleRefresh(BuildContext context) async {
    try {
      await onRefresh();
      if (showSuccessFeedback && context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          successMessage ?? 'Data berhasil diperbarui',
        );
      }
    } catch (e) {
      AppLogger.error('app_refresh_indicator', 'Refresh failed: $e');
      if (showErrorFeedback && context.mounted) {
        SnackBarUtils.showError(
          context,
          errorMessage ?? 'Gagal memperbarui data',
        );
      }
    }
  }
}
