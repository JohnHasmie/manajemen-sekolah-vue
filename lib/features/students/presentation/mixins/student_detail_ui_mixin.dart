import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Provides UI styling and color utilities for student detail screen.
mixin StudentDetailUiMixin {
  /// Gets primary color for UI elements (admin role).
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Generates avatar color from string hash (e.g., student name).
  Color getAvatarColor(String text) {
    final hash = text.codeUnits.fold(0, (sum, c) => sum + c);
    return ColorUtils.getColorForIndex(hash);
  }

  /// Gets avatar initial from text (first character or '?').
  String getAvatarInitial(String text) {
    return text.isNotEmpty ? text[0].toUpperCase() : '?';
  }
}
