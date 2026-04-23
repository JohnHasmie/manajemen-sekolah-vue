import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for styling and colors in AdminAttendanceDetailPage
mixin admin_detail_style_mixin {
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.85)],
    );
  }
}
