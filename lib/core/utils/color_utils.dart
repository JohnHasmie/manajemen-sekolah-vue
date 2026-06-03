/// color_utils.dart - Centralized color constants and color-mapping utilities.
/// Like a Laravel Helper function file (e.g., `helpers.php`) but for colors.
/// In Vue terms, this is like a `colors.ts` utility module or a Tailwind
/// config that defines your design system's color palette and semantic color
/// mappings.
library;

import 'package:flutter/material.dart';

part 'color_utils_mappings.dart';

/// Provides static color constants, semantic color mappers, and decoration
/// builders
/// for the entire app. Like a Laravel Helper function class for UI colors.
///
/// Usage: `ColorUtils.primaryColor`, `ColorUtils.getStatusColor('active')`,
/// etc.
/// All methods are static - no instantiation needed (like Laravel helper
/// functions).
///
/// Key sections:
/// - Index-based colors: Rotating palette for lists (like chart colors).
/// - Day/semester colors: Maps day names to consistent colors.
/// - Status/grade/role colors: Semantic color mapping based on business logic.
/// - Subject colors: Color-codes school subjects by keyword matching.
/// - Card gradients & decorations: Reusable `BoxDecoration` builders for UI
/// cards.
/// - Slate palette: Tailwind CSS-inspired neutral gray scale.
/// - Corporate blue palette: Professional blue scale for dashboard elements.
class ColorUtils {
  /// Returns a color from a rotating palette based on [index].
  /// Useful for assigning consistent colors to list items (e.g., chart
  /// segments).
  /// Uses modulo to cycle through 6 colors. Like a Laravel Helper function.
  static Color getColorForIndex(int index) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  /// The app's primary brand color (indigo).
  static Color get primaryColor => const Color(0xFF4F46E5);

  /// Returns black or white text color for optimal contrast against
  /// [backgroundColor].
  /// Uses the perceived luminance formula (ITU-R BT.601) to determine
  /// readability.
  /// Like a CSS `color-contrast()` function.
  ///
  /// [backgroundColor] - The background color to check against.
  /// Returns [Colors.black] for light backgrounds, [Colors.white] for dark
  /// ones.
  static Color getTextColorForBackground(Color backgroundColor) {
    // Calculate the perceptive luminance
    final luminance =
        (0.299 * ((backgroundColor.r * 255.0).round() & 0xff) +
            0.587 * ((backgroundColor.g * 255.0).round() & 0xff) +
            0.114 * ((backgroundColor.b * 255.0).round() & 0xff)) /
        255;

    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Shimmer loading animation colors (base and highlight).
  static Color get shimmerBaseColor => Colors.grey[300]!;
  static Color get shimmerHighlightColor => Colors.grey[100]!;

  /// Common UI element colors.
  static Color get borderColor => Colors.grey[300]!;
  static Color get dividerColor => Colors.grey[200]!;
  static Color get shadowColor => Colors.black.withValues(alpha: 0.1);
  static Color get disabledColor => Colors.grey[400]!;

  /// Semantic color variants (light for backgrounds, dark for text/icons).
  static Color get successLight => const Color(0xFFD1FAE5);
  static Color get successDark => const Color(0xFF065F46);

  static Color get warningLight => const Color(0xFFFEF3C7);
  static Color get warningDark => const Color(0xFF92400E);

  static Color get errorLight => const Color(0xFFFEE2E2);
  static Color get errorDark => const Color(0xFF991B1B);

  static Color get infoLight => const Color(0xFFE0F2FE);
  static Color get infoDark => const Color(0xFF0C4A6E);

  /// Slate gray scale (Tailwind CSS-inspired). Used throughout the app for
  /// text, borders, and backgrounds. Like Tailwind's `slate-50` through
  /// `slate-950`.
  static Color get slate50 => const Color(0xFFF8FAFC);
  static Color get slate100 => const Color(0xFFF1F5F9);
  static Color get slate200 => const Color(0xFFE2E8F0);
  static Color get slate300 => const Color(0xFFCBD5E1);
  static Color get slate400 => const Color(0xFF94A3B8);
  static Color get slate500 => const Color(0xFF64748B);
  static Color get slate600 => const Color(0xFF475569);
  static Color get slate700 => const Color(0xFF334155);
  static Color get slate800 => const Color(0xFF1E293B);
  static Color get slate900 => const Color(0xFF0F172A);
  static Color get slate950 => const Color(0xFF020617);

  /// Alias for [primaryColor].
  static Color get primary => primaryColor;

  /// Corporate blue scale for professional dashboard elements.
  /// Ranges from dark (900) to light (50), like Tailwind's blue palette.
  static Color get corporateBlue900 => const Color(0xFF1E3A8A); // Dark headings
  static Color get corporateBlue800 => const Color(0xFF1E40AF);
  static Color get corporateBlue700 =>
      const Color(0xFF1D4ED8); // Primary actions
  static Color get corporateBlue600 => const Color(0xFF2563EB);
  static Color get corporateBlue500 =>
      const Color(0xFF3B82F6); // Interactive elements
  static Color get corporateBlue400 => const Color(0xFF60A5FA);
  static Color get corporateBlue300 => const Color(0xFF93C5FD);
  static Color get corporateBlue200 => const Color(0xFFBFDBFE);
  static Color get corporateBlue100 =>
      const Color(0xFFDBEAFE); // Light backgrounds
  static Color get corporateBlue50 => const Color(0xFFEFF6FF);

  // ── Kamil Edu brand palette ──
  // Sourced from `Kamil Edu - Brand Colour Guide.pdf`. Use these instead
  // of inline hex literals so a future brand refresh changes one file.
  // For role-aware lookup prefer [getRoleColor] + [brandGradient].

  /// Brand Dark Blue — admin primary, teacher gradient start.
  static Color get brandDarkBlue => const Color(0xFF143068);

  /// Slightly lightened Dark Blue used as the second stop on the admin
  /// hero gradient (~+16% HSL lightness off [brandDarkBlue]).
  static Color get brandDarkBlueDeep => const Color(0xFF1F4A8F);

  /// Brand Azzure Blue — parent primary, teacher gradient end.
  static Color get brandAzure => const Color(0xFF21AFE6);

  /// Deeper Azzure — second stop on the parent hero gradient so the
  /// gradient still reads as "depth" while staying inside the brand swatch.
  static Color get brandAzureDeep => const Color(0xFF1A8FBE);

  /// Cobalt Blue — teacher accent. The HSL midpoint of [brandDarkBlue]
  /// and [brandAzure]; gives the teacher its own identity rather than
  /// borrowing admin's dark blue or parent's azure.
  static Color get brandCobalt => const Color(0xFF1B6FB8);

  /// Returns the canonical hero gradient for [role]. Used by every
  /// role-themed page header so the visual identity is consistent
  /// between dashboard and deep tabs.
  ///
  ///   • admin  → Dark Blue → its lightened variant
  ///   • guru   → Dark Blue → Azzure Blue (literal brand pair, since
  ///                          teacher bridges admin & parent)
  ///   • wali   → Azzure → its deeper variant
  static LinearGradient brandGradient(String role) {
    final normalized = role.toLowerCase();
    final stops = switch (normalized) {
      'admin' || 'administrator' => (brandDarkBlue, brandDarkBlueDeep),
      'guru' || 'teacher' => (brandDarkBlue, brandAzure),
      'wali' || 'parent' || 'orang_tua' => (brandAzure, brandAzureDeep),
      _ => (brandDarkBlue, brandDarkBlueDeep),
    };
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [stops.$1, stops.$2],
    );
  }

  /// Canonical sheet/header fade gradient. Pairs [base] with the same colour
  /// faded to [endOpacity] (default ~85 %) along the topLeft → bottomRight
  /// diagonal.
  ///
  /// Use this instead of inlining
  /// `LinearGradient(colors: [c, c.withValues(alpha: 0.85)])` for sheet
  /// headers, dialog headers, KPI hero cards, and any other surface that
  /// wants the standard role-tinted fade.
  ///
  /// Some legacy sites tune [endOpacity] for slightly punchier surfaces
  /// (0.75–0.82) — pass that through rather than reverting to inline
  /// construction.
  ///
  /// Prefer [brandGradient] when the gradient should pair two distinct brand
  /// tokens (admin / teacher / parent) rather than a fade of one runtime
  /// colour.
  static LinearGradient headerFadeGradient(
    Color base, {
    double endOpacity = 0.85,
  }) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        base,
        base.withValues(alpha: endOpacity),
      ],
    );
  }

  /// Semantic dashboard colors at the 600 weight for consistent contrast.
  static Color get success600 => const Color(0xFF059669);
  static Color get warning600 => const Color(0xFFD97706);
  static Color get error600 => const Color(0xFFDC2626);
  static Color get info600 => const Color(0xFF0891B2);

  /// Tailwind 700-weight tints used by the admin RPP mockup palette
  /// (status pill foregrounds, KPI numerals, audit timeline dot fg,
  /// pill borders). Slightly less saturated than the 600s so they read
  /// as text on tinted-50 backgrounds without screaming.
  static Color get success700 => const Color(0xFF15803D);
  static Color get warning700 => const Color(0xFFB45309);
  static Color get error700 => const Color(0xFFB91C1C);

  /// Tailwind green-600 — the mockup's status-pill / approve-CTA
  /// canonical green. `success600` is emerald-600 (#059669) which
  /// reads cooler; this hue matches the design tokens 1:1.
  static Color get green600 => const Color(0xFF16A34A);

  // ── Common UI colors (Tailwind-inspired) ──
  static Color get emerald500 => const Color(0xFF10B981);
  static Color get violet500 => const Color(0xFF8B5CF6);
  static Color get amber500 => const Color(0xFFF59E0B);
  static Color get red500 => const Color(0xFFEF4444);
  static Color get indigo500 => const Color(0xFF6366F1);
  // Slightly lighter green for "realtime fresh" pulsing-dot
  // affordances — sits between emerald500 and white so it still
  // reads as alive against a tinted scrim.
  static Color get green400 => const Color(0xFF4ADE80);
  static Color get blue600 => const Color(0xFF4361EE);
  static Color get darkBlue => const Color(0xFF0D47A1);
  static Color get cyan500 => const Color(0xFF06B6D4);
  static Color get violet700 => const Color(0xFF7C3AED);
  static Color get lime500 => const Color(0xFF84CC16);
  static Color get indigo600 => const Color(0xFF4F46E5);
  static Color get pink500 => const Color(0xFFEC4899);
  static Color get lightGray => const Color(0xFFF8F9FA);

  /// Professional card decoration for corporate dashboard
  static BoxDecoration corporateCard({
    Color? accentColor,
    bool withBorder = true,
  }) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(
        Radius.circular(12),
      ), // Sharper than default 16
      border: withBorder ? Border.all(color: slate200, width: 1) : null,
      boxShadow: corporateShadow(),
    );
  }

  /// Layered shadow for professional depth
  static List<BoxShadow> corporateShadow({double elevation = 1.0}) {
    return [
      BoxShadow(
        color: slate900.withValues(alpha: 0.04 * elevation),
        blurRadius: 6 * elevation,
        offset: Offset(0, 2 * elevation),
      ),
      BoxShadow(
        color: slate900.withValues(alpha: 0.02 * elevation),
        blurRadius: 12 * elevation,
        offset: Offset(0, 4 * elevation),
      ),
    ];
  }

  /// Subtle gradient for cards
  static LinearGradient corporateGradient({
    required Color color,
    double opacity = 0.1,
  }) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: opacity),
        color.withValues(alpha: opacity * 0.5),
      ],
    );
  }

  /// Professional stat card decoration
  static BoxDecoration statCardDecoration({required Color accentColor}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      border: Border.all(color: slate200, width: 1),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: slate900.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Category header decoration
  static BoxDecoration categoryHeaderDecoration({
    required Color accentColor,
    bool isExpanded = true,
  }) {
    return BoxDecoration(
      color: accentColor.withValues(alpha: 0.05),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
    );
  }

  /// Kamil Edu brand-specific professional colors.
  static Color get kamilPrimary =>
      const Color(0xFF143068); // Deep professional blue
  static Color get kamilAccent => const Color(0xFF21AFE6); // Vibrant teal
  static Color get kamilPrimaryLight => const Color(0xFFE8EEF7);
  static Color get kamilAccentLight => const Color(0xFFE6F7FD);

  /// Modern hero gradient with vibrant colors
  static LinearGradient heroGradient({required Color primaryColor}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor,
        ColorMappings._adjustColor(primaryColor, 0.15),
        ColorMappings._adjustColor(primaryColor, 0.35),
      ],
      stops: const [0.0, 0.5, 1.4],
    );
  }

  /// Glass morphism effect
  static BoxDecoration glassMorphism({
    Color? color,
    double blur = 10,
    double opacity = 0.1,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: opacity),
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: blur,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Quick action button decoration
  static BoxDecoration quickActionDecoration({required Color color}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      border: Border.all(color: slate200, width: 1),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ── Delegating static methods to ColorMappings ──
  // These forward to the extension so callers can use
  // `ColorUtils.getRoleColor(...)` etc.

  /// Returns a color for a user role string.
  static Color getRoleColor(String role) => ColorMappings.getRoleColor(role);

  /// Returns a color for a day/semester name.
  static Color getDayColor(String day) => ColorMappings.getDayColor(day);

  /// Returns a color for a status string.
  static Color getStatusColor(String status) =>
      ColorMappings.getStatusColor(status);

  /// Returns a color for a numeric grade.
  static Color getGradeColor(double grade) =>
      ColorMappings.getGradeColor(grade);

  /// Returns a color for a subject name.
  static Color getSubjectColor(String subjectName) =>
      ColorMappings.getSubjectColor(subjectName);

  /// Returns a gradient pair for a card type.
  static List<Color> getCardGradient(String type) =>
      ColorMappings.getCardGradient(type);
}
