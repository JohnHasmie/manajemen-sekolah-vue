// Reusable school-switcher pill used across admin screens.
//
// Why this exists
// ---------------
// Multi-school admins need to see the currently-active school at a glance on
// every admin screen AND have a one-tap affordance to switch. Today the
// dashboard paints its own pill, Sistem Settings paints a different (bigger)
// one, and the CRUD screens paint yet a third variant next to their title.
// Three visual languages for one piece of data.
//
// `SchoolPill` ships two variants that share the same semantics:
//   • [SchoolPill] — compact (AppBar / header trailing slot).
//   • [SchoolPill.expanded] — full-width row (Settings hero, dashboard top).
//
// Both render the school logo/initial, name, secondary line (role or
// academic year), and a chevron when [onTap] is provided. The expanded
// variant adds a "Ganti" button hint. Tapping invokes [onTap]; callers
// typically open a school-picker bottom sheet.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A compact pill displaying the active school, suitable for AppBar trailing
/// slots or gradient-header right edges.
///
/// Example:
/// ```dart
/// SchoolPill(
///   schoolName: 'SMA Al-Kamil',
///   subtitle: '2025/2026 · Admin',
///   onTap: () => _openSchoolPicker(context),
/// )
/// ```
class SchoolPill extends StatelessWidget {
  /// The active school's display name.
  final String schoolName;

  /// Secondary line — typically the academic year or the admin's role label.
  /// When null, only the school name is rendered.
  final String? subtitle;

  /// URL for the school's logo. When null, falls back to a monogrammed
  /// initial derived from [schoolName].
  final String? logoUrl;

  /// Called when the pill is tapped. When null, the chevron is hidden and
  /// the pill reads as a static display.
  final VoidCallback? onTap;

  /// Accent color used for the border, logo fallback, and chevron. Defaults
  /// to the admin navy.
  final Color accentColor;

  /// Background color of the pill. Defaults to white so the pill reads as a
  /// "card" against colored gradient headers.
  final Color backgroundColor;

  /// Text color used for the school name. Defaults to
  /// [accentColor] so the pill theming stays consistent.
  final Color? foregroundColor;

  /// Whether this pill sits atop a dark/gradient surface. When true, the
  /// pill uses a translucent white background and white foreground, matching
  /// the teacher header convention for contrast. Ignored when
  /// [backgroundColor]/[foregroundColor] are set explicitly.
  final bool onDarkSurface;

  const SchoolPill({
    super.key,
    required this.schoolName,
    this.subtitle,
    this.logoUrl,
    this.onTap,
    this.accentColor = const Color(0xFF0F172A),
    this.backgroundColor = Colors.white,
    this.foregroundColor,
    this.onDarkSurface = false,
  });

  /// Builds the Settings-hero variant: full-width row with logo, name,
  /// subtitle, and a trailing "Ganti" button.
  ///
  /// When [onDarkSurface] is true the pill renders with a translucent white
  /// background and white text — matching the Phase 3 mockup where the pill
  /// sits inside the navy gradient header.
  static Widget expanded({
    Key? key,
    required String schoolName,
    String? subtitle,
    String? logoUrl,
    VoidCallback? onTap,
    String actionLabel = 'Ganti',
    Color accentColor = const Color(0xFF0F172A),
    bool onDarkSurface = false,
  }) {
    return _ExpandedSchoolPill(
      key: key,
      schoolName: schoolName,
      subtitle: subtitle,
      logoUrl: logoUrl,
      onTap: onTap,
      actionLabel: actionLabel,
      accentColor: accentColor,
      onDarkSurface: onDarkSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    // On a dark/gradient surface the pill inverts: translucent-white tile
    // with white text, no border. This matches the aesthetic used by
    // TeacherPageHeader's 0.2-alpha white chips.
    final bg = onDarkSurface
        ? Colors.white.withValues(alpha: 0.18)
        : backgroundColor;
    final fg = foregroundColor ?? (onDarkSurface ? Colors.white : accentColor);
    final subtitleColor = onDarkSurface
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.grey.shade600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: onDarkSurface
                ? null
                : Border.all(color: accentColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SchoolAvatar(
                schoolName: schoolName,
                logoUrl: logoUrl,
                size: 26,
                accentColor: accentColor,
                onDarkSurface: onDarkSurface,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: subtitleColor,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The full-width settings/dashboard-hero variant.
class _ExpandedSchoolPill extends StatelessWidget {
  final String schoolName;
  final String? subtitle;
  final String? logoUrl;
  final VoidCallback? onTap;
  final String actionLabel;
  final Color accentColor;
  final bool onDarkSurface;

  const _ExpandedSchoolPill({
    super.key,
    required this.schoolName,
    this.subtitle,
    this.logoUrl,
    this.onTap,
    required this.actionLabel,
    required this.accentColor,
    this.onDarkSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    // On-dark: translucent white bg + white text (mockup SVG line 29-35).
    // On-light (default): solid white bg + accent-colored text.
    final bg = onDarkSurface
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white;
    final fg = onDarkSurface ? Colors.white : accentColor;
    final subtitleColor = onDarkSurface
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.grey.shade600;
    final borderColor = onDarkSurface
        ? Colors.white.withValues(alpha: 0.14)
        : accentColor.withValues(alpha: 0.12);
    final actionBg = onDarkSurface
        ? Colors.white.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.1);

    return Material(
      color: bg,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Initials avatar — gives the dashboard hero its
              // "school identity" anchor before the name. Sized to
              // match the academic-year chip's left-icon weight so
              // the two pills sit on the same visual rhythm.
              _SchoolAvatar(
                schoolName: schoolName,
                logoUrl: logoUrl,
                size: 36,
                accentColor: accentColor,
                onDarkSurface: onDarkSurface,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular avatar: tries to load [logoUrl]; if absent or errored, falls back
/// to a monogrammed initial on an accent-tinted disc.
class _SchoolAvatar extends StatelessWidget {
  final String schoolName;
  final String? logoUrl;
  final double size;
  final Color accentColor;
  final bool onDarkSurface;

  const _SchoolAvatar({
    required this.schoolName,
    required this.logoUrl,
    required this.size,
    required this.accentColor,
    required this.onDarkSurface,
  });

  String _initial() {
    final trimmed = schoolName.trim();
    if (trimmed.isEmpty) return '?';
    // Compose up to 2 chars from the first two tokens ("Al-Kamil" → "AK")
    // for better legibility on the 44 px avatar. On the 26 px avatar the
    // second char is clipped by the container anyway.
    final tokens = trimmed.split(RegExp(r'\s+'));
    if (tokens.length == 1) return tokens.first.characters.first.toUpperCase();
    return (tokens[0].characters.first + tokens[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = onDarkSurface
        ? Colors.white.withValues(alpha: 0.9)
        : accentColor;
    final bg = onDarkSurface
        ? Colors.white.withValues(alpha: 0.25)
        : accentColor.withValues(alpha: 0.12);

    final child = logoUrl != null && logoUrl!.isNotEmpty
        ? ClipOval(
            child: Image.network(
              logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialAvatar(baseColor, bg),
            ),
          )
        : _initialAvatar(baseColor, bg);

    return SizedBox(width: size, height: size, child: child);
  }

  Widget _initialAvatar(Color fg, Color bg) {
    return Container(
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _initial(),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1,
        ),
      ),
    );
  }
}
