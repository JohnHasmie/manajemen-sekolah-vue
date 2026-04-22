// Color helper methods for TeacherScheduleController.
// Provides color utilities for teacher role styling.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Helper class for color-related operations.
class TeacherScheduleColorHelper {
  /// Returns the primary theme color for the teacher role.
  /// Like a Vue computed `primaryColor` that maps a role to a color.
  static Color getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  /// Returns the gradient used on the screen header card.
  static LinearGradient getCardGradient() {
    final primaryColor = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
    );
  }
}
