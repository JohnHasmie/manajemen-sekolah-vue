/// dashboard_typography.dart - Centralized text style definitions for the dashboard UI.
/// Like a Laravel Helper function file but for typography, or a Vue design-system
/// composable that returns pre-configured text styles. Similar to defining a
/// Tailwind `@apply` typography utility layer.
library;

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Provides a consistent set of [TextStyle] factory methods for all dashboard text.
/// Like a Laravel Helper function class for typography. Each method returns a
/// configured [TextStyle] with optional color override.
///
/// Usage: `Text('Hello', style: DashboardTypography.heading1())`
///
/// Style hierarchy:
/// - Headings: [heading1] (24px), [heading2] (20px), [heading3] (18px)
/// - Body: [subtitle] (14px medium), [body] (14px regular), [bodyBold] (14px semibold)
/// - Small: [caption] (12px), [captionBold] (12px semibold), [label] (10px)
/// - Specialized: [statValue] (28px, for big numbers), [statTitle], [statSubtitle],
///   [categoryTitle], [menuTitle], [trendText]
class DashboardTypography {
  /// Heading styles - decreasing size from h1 to h3. Optional [color] overrides the default slate.
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

  /// Body text styles for general content. [subtitle] is medium-weight, [body] is regular, [bodyBold] is semibold.
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

  /// Small text styles for captions, labels, and secondary info.
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

  /// Specialized text styles for dashboard widgets (stats, categories, menus, trends).
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
