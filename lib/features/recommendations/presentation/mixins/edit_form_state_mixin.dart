import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Mixin for form state management and utility methods.
///
/// Handles saving recommendations, color management based on
/// teacher roles, and state lifecycle operations.
mixin EditFormStateMixin {
  /// Gets saving state flag.
  bool get isSaving;

  /// Sets saving state flag.
  set isSaving(bool value);

  /// Gets teacher data.
  Map<String, String> get teacher;

  /// Gets context.
  BuildContext get context;

  /// Gets mounted status.
  bool get mounted;

  /// Sets state in the widget.
  void setState(VoidCallback fn);

  /// Saves edited recommendations and navigates back.
  ///
  /// Sets saving state, simulates network latency, shows success
  /// message, and returns true to parent to indicate changes
  /// were saved.
  Future<void> saveChanges() async {
    setState(() => isSaving = true);

    await Future.delayed(const Duration(seconds: 1));

    if (context.mounted) {
      setState(() => isSaving = false);
      SnackBarUtils.showInfo(context, 'Perubahan berhasil disimpan!');
      AppNavigator.pop(context, true);
    }
  }

  /// Gets primary color based on teacher role.
  ///
  /// Uses ColorUtils to determine role-specific color.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(teacher['role'] ?? 'guru');
  }
}
