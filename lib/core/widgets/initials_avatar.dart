// Reusable circular initials avatar — the canonical "person/school
// disc with one or two letters" widget used across every role.
//
// Replaces the duplicated initials logic that was scattered across:
//   • SchoolPill._SchoolAvatar
//   • dashboard_school_selection_dialog.dart (_initials helper)
//   • Switcher hero/tile cards (`Text(_initials(name), …)` blocks)
//   • Various student/teacher list tiles
//
// One widget, three ways to fill it:
//   1. solid color background  — `InitialsAvatar(name: 'KA', accent: navy)`
//   2. gradient background     — `InitialsAvatar.gradient(name: 'KA', gradient: brandGradient)`
//   3. translucent-on-dark     — `InitialsAvatar.onDark(name: 'KA')`
//
// Logo URL takes precedence — when a non-empty URL is passed the
// network image is loaded and the initials become the error fallback,
// so callers don't need to special-case schools that uploaded a logo.
import 'package:flutter/material.dart';

/// Cached whitespace splitter — recreated-per-build allocations were
/// showing up in the perf audit. `_initialsFor` calls this once per
/// avatar build, but since `InitialsAvatar` rebuilds on every list
/// state change the per-build allocation was non-trivial.
final RegExp _whitespace = RegExp(r'\s+');

/// Compute the two-letter initials for [name]. "Al-Kamil" → "AK",
/// "Yahya" → "Y", empty → "?". Public so callers that don't render
/// the avatar (e.g., monogram chips) can share the same logic.
String initialsFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final tokens = trimmed.split(_whitespace);
  if (tokens.length == 1) {
    return tokens.first.characters.first.toUpperCase();
  }
  return (tokens[0].characters.first + tokens[1].characters.first)
      .toUpperCase();
}

/// Visual style for the avatar disc.
enum InitialsAvatarStyle {
  /// Solid fill in [InitialsAvatar.color] with white text.
  solid,

  /// Linear gradient in [InitialsAvatar.gradient] with white text.
  gradient,

  /// 12% tinted fill in [InitialsAvatar.color] with the accent color
  /// for text — used on white backgrounds where a solid fill would
  /// be too loud.
  tinted,

  /// Translucent white fill (18% alpha) with white text — for use
  /// inside gradient hero cards where the disc sits on a colored
  /// background and inherits its tone.
  onDark,
}

class InitialsAvatar extends StatelessWidget {
  /// Source string for the initials. The first 1–2 characters of the
  /// first 1–2 whitespace-separated tokens become the label.
  final String name;

  /// Edge length of the disc. The text size is computed as 38% of
  /// this value so the letters fill the disc consistently.
  final double size;

  /// Visual style. Defaults to [InitialsAvatarStyle.solid].
  final InitialsAvatarStyle style;

  /// Solid fill color (or tinted color base). Required when [style]
  /// is solid or tinted; ignored for gradient/onDark.
  final Color? color;

  /// Gradient fill. Required when [style] is gradient; ignored
  /// otherwise.
  final Gradient? gradient;

  /// Optional logo URL — when non-empty, replaces the initials with
  /// a network image. The initials remain as the error fallback.
  final String? logoUrl;

  /// Border radius for the disc. Defaults to a perfect circle when
  /// null; pass a value (e.g., `12`) to get a rounded square.
  final double? borderRadius;

  const InitialsAvatar({
    super.key,
    required this.name,
    required this.size,
    this.color,
    this.logoUrl,
    this.borderRadius,
  }) : style = InitialsAvatarStyle.solid,
       gradient = null;

  /// Gradient-filled variant. Pass [gradient] to get the brand
  /// LinearGradient on the disc.
  const InitialsAvatar.gradient({
    super.key,
    required this.name,
    required this.size,
    required this.gradient,
    this.logoUrl,
    this.borderRadius,
  }) : style = InitialsAvatarStyle.gradient,
       color = null;

  /// Tinted variant — 12% fill in [color], accent text in [color].
  /// Use on white backgrounds where a solid fill would dominate.
  const InitialsAvatar.tinted({
    super.key,
    required this.name,
    required this.size,
    required Color this.color,
    this.logoUrl,
    this.borderRadius,
  }) : style = InitialsAvatarStyle.tinted,
       gradient = null;

  /// On-dark variant — 18% white fill, white text. For use inside
  /// gradient hero cards where the disc inherits the card's tone.
  const InitialsAvatar.onDark({
    super.key,
    required this.name,
    required this.size,
    this.logoUrl,
    this.borderRadius,
  }) : style = InitialsAvatarStyle.onDark,
       color = null,
       gradient = null;

  @override
  Widget build(BuildContext context) {
    final shape = borderRadius == null
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius!),
          );

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return _LogoAvatar(
        url: logoUrl!,
        size: size,
        shape: shape,
        fallback: _initialsTile(),
      );
    }
    return _initialsTile();
  }

  Widget _initialsTile() {
    final fg = _foreground();
    final bg = _background();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style == InitialsAvatarStyle.gradient ? null : bg,
        gradient: style == InitialsAvatarStyle.gradient ? gradient : null,
        borderRadius: borderRadius == null
            ? null
            : BorderRadius.circular(borderRadius!),
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
      ),
      alignment: Alignment.center,
      child: Text(
        initialsFor(name),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1,
        ),
      ),
    );
  }

  Color _foreground() {
    switch (style) {
      case InitialsAvatarStyle.tinted:
        return color ?? Colors.black;
      case InitialsAvatarStyle.solid:
      case InitialsAvatarStyle.gradient:
      case InitialsAvatarStyle.onDark:
        return Colors.white;
    }
  }

  Color _background() {
    switch (style) {
      case InitialsAvatarStyle.solid:
        return color ?? const Color(0xFF94A3B8);
      case InitialsAvatarStyle.tinted:
        return (color ?? const Color(0xFF94A3B8)).withValues(alpha: 0.12);
      case InitialsAvatarStyle.onDark:
        return Colors.white.withValues(alpha: 0.18);
      case InitialsAvatarStyle.gradient:
        return Colors.transparent; // gradient takes over
    }
  }
}

/// Network-image variant with graceful fallback to initials. Kept
/// internal so callers always go through the named [InitialsAvatar]
/// constructors.
class _LogoAvatar extends StatelessWidget {
  final String url;
  final double size;
  final ShapeBorder shape;
  final Widget fallback;

  const _LogoAvatar({
    required this.url,
    required this.size,
    required this.shape,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final clip = shape is CircleBorder
        ? const _CircleClip()
        : _RoundedClip(
            borderRadius: (shape as RoundedRectangleBorder).borderRadius
                .resolve(Directionality.of(context)),
          );
    return SizedBox(
      width: size,
      height: size,
      child: clip.applyTo(
        Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

abstract class _Clip {
  Widget applyTo(Widget child);
}

class _CircleClip implements _Clip {
  const _CircleClip();
  @override
  Widget applyTo(Widget child) => ClipOval(child: child);
}

class _RoundedClip implements _Clip {
  final BorderRadius borderRadius;
  const _RoundedClip({required this.borderRadius});
  @override
  Widget applyTo(Widget child) =>
      ClipRRect(borderRadius: borderRadius, child: child);
}
