import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/dashboard_screen.dart';

/// Provides helper methods for Dashboard state management.
/// Includes role mapping, color selection, and sync trigger handling.
mixin HelpersMixin on ConsumerState<Dashboard> {
  /// Normalizes role names (teacher → guru, parent → wali).
  String get effectiveRole {
    if (widget.role == 'teacher') return 'guru';
    if (widget.role == 'parent') return 'wali';
    return widget.role;
  }

  /// Gets the primary color based on the current effective role.
  /// - admin: Blue
  /// - guru/teacher: Teal
  /// - staff: Orange
  /// - wali/parent: Purple
  Color getPrimaryColor() {
    switch (effectiveRole) {
      case 'admin':
        return ColorUtils.corporateBlue600;
      case 'guru':
        return const Color(0xFF16A34A);
      case 'staff':
        return const Color(0xFFFF9F1C);
      case 'wali':
        return const Color(0xFF9333EA);
      default:
        return const Color.fromARGB(255, 17, 19, 29);
    }
  }

  /// Handles FCM sync triggers to refresh dashboard data.
  /// Triggered when background/foreground sync events occur
  /// (e.g., announcement refresh notifications).
  void handleSyncTrigger() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null) {
      if (trigger['type'] == 'refresh_announcements') {
        AppLogger.debug(
          'dashboard',
          'Dashboard refreshing data due to background/foreground sync',
        );
        if (mounted) {
          ref.read(dashboardProvider.notifier).initialize(widget.role);
        }
      }
    }
  }
}
