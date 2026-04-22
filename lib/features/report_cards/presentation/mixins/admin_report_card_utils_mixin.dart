import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';

/// Mixin for utility methods.
mixin AdminReportCardUtilsMixin on State<AdminReportCardScreen> {
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }
}
