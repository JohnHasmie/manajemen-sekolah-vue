import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

/// Professional typography system for dashboard components
/// Provides consistent text styles with corporate design standards
class DashboardTypography {
  // Heading Styles
  static TextStyle heading1({Color? color}) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color ?? ColorUtils.slate900,
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle heading2({Color? color}) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color ?? ColorUtils.slate900,
        letterSpacing: -0.3,
        height: 1.3,
      );

  static TextStyle heading3({Color? color}) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? ColorUtils.slate900,
        letterSpacing: -0.2,
        height: 1.3,
      );

  // Body Text Styles
  static TextStyle subtitle({Color? color}) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color ?? ColorUtils.slate600,
        height: 1.4,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color ?? ColorUtils.slate700,
        height: 1.5,
      );

  static TextStyle bodyBold({Color? color}) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? ColorUtils.slate900,
        height: 1.5,
      );

  // Small Text Styles
  static TextStyle caption({Color? color}) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? ColorUtils.slate500,
        height: 1.4,
      );

  static TextStyle captionBold({Color? color}) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color ?? ColorUtils.slate700,
        height: 1.4,
      );

  // Specialized Text Styles
  static TextStyle label({Color? color}) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: color ?? ColorUtils.slate600,
        height: 1.3,
        letterSpacing: 0.5,
      );

  static TextStyle statValue({Color? color}) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color ?? ColorUtils.slate900,
        letterSpacing: -1.0,
        height: 1.1,
      );

  static TextStyle statTitle({Color? color}) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: color ?? ColorUtils.slate600,
        height: 1.3,
      );

  static TextStyle statSubtitle({Color? color}) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: color ?? ColorUtils.slate500,
        height: 1.3,
      );

  static TextStyle categoryTitle({Color? color}) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color ?? ColorUtils.slate700,
        letterSpacing: 0.8,
        height: 1.3,
      );

  static TextStyle menuTitle({Color? color}) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? ColorUtils.slate900,
        height: 1.3,
      );

  static TextStyle trendText({Color? color}) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.2,
      );
}
