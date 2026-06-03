import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for styling and colors in AdminAttendanceDetailPage
mixin AdminDetailStyleMixin {
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient getCardGradient() {
    return ColorUtils.headerFadeGradient(getPrimaryColor());
  }
}
