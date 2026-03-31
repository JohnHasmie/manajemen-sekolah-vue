/// app_spacing.dart - Centralized spacing constants for consistent UI.
/// Like a CSS variables file or Tailwind's spacing scale.
///
/// Replaces 2000+ hardcoded SizedBox/EdgeInsets values across the app.
/// Use `AppSpacing.sm` instead of magic number `8.0`.
library;

import 'package:flutter/material.dart';

/// Standard spacing scale used throughout the app.
/// Based on a 4px grid system (like Tailwind's default spacing scale).
class AppSpacing {
  AppSpacing._();

  /// 4.0 — Extra small gaps (between icon and text, list separators)
  static const double xs = 4.0;

  /// 8.0 — Small gaps (between form fields, card padding)
  static const double sm = 8.0;

  /// 12.0 — Medium gaps (section separators, card margins)
  static const double md = 12.0;

  /// 16.0 — Large gaps (page padding, major section separators)
  static const double lg = 16.0;

  /// 20.0 — Extra large gaps
  static const double xl = 20.0;

  /// 24.0 — Double extra large gaps (page top/bottom padding)
  static const double xxl = 24.0;

  /// 32.0 — Triple extra large gaps (major sections)
  static const double xxxl = 32.0;

  // Vertical Spacing (height)
  static const SizedBox v2 = SizedBox(height: 2.0);
  static const SizedBox v4 = SizedBox(height: 4.0);
  static const SizedBox v6 = SizedBox(height: 6.0);
  static const SizedBox v8 = SizedBox(height: 8.0);
  static const SizedBox v10 = SizedBox(height: 10.0);
  static const SizedBox v12 = SizedBox(height: 12.0);
  static const SizedBox v16 = SizedBox(height: 16.0);
  static const SizedBox v20 = SizedBox(height: 20.0);
  static const SizedBox v24 = SizedBox(height: 24.0);
  static const SizedBox v32 = SizedBox(height: 32.0);

  // Horizontal Spacing (width)
  static const SizedBox h2 = SizedBox(width: 2.0);
  static const SizedBox h4 = SizedBox(width: 4.0);
  static const SizedBox h6 = SizedBox(width: 6.0);
  static const SizedBox h8 = SizedBox(width: 8.0);
  static const SizedBox h10 = SizedBox(width: 10.0);
  static const SizedBox h12 = SizedBox(width: 12.0);
  static const SizedBox h16 = SizedBox(width: 16.0);
  static const SizedBox h20 = SizedBox(width: 20.0);
  static const SizedBox h24 = SizedBox(width: 24.0);
  static const SizedBox h32 = SizedBox(width: 32.0);
}

/// Extension to provide convenient non-static methods if needed.
extension AppSpacingExtension on AppSpacing {}
