/// app_spacing.dart - Centralized spacing constants for consistent UI.
/// Like a CSS variables file or Tailwind's spacing scale.
///
/// Replaces 2000+ hardcoded SizedBox/EdgeInsets values across the app.
/// Use `AppSpacing.sm` instead of magic number `8.0`.
library;

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
}
