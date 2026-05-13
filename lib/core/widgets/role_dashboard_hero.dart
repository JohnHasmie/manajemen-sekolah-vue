// Shared dashboard hero shell — gradient + rounded bottom + shadow
// + status-bar-aware padding — used by every role's dashboard body
// (admin / guru / wali).
//
// Why a dedicated widget instead of `BrandPageHeader`:
//   • The dashboard hero has a very different content shape from a
//     page header: greeting + name + icon-button cluster + school
//     pill + KPI overlap band. `BrandPageHeader` is tailored for
//     page-level titling (title + subtitle + back button + actions).
//   • All three dashboard bodies previously hand-rolled the same
//     outer shell with role-color tweaks — extracting it removes the
//     copy-and-paste burden and keeps the brand styling
//     (28dp rounded bottom, 18dp shadow at α=0.18, 6dp y-offset) in
//     one place.
//
// Per CLAUDE.md: role colors come exclusively from
// `ColorUtils.brandGradient(role)`. The shadow color uses the
// gradient's first stop so it matches the visually-darker corner of
// the hero.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Outer shell for every dashboard body's hero.
///
/// The widget owns:
///   - role-tinted gradient (via [ColorUtils.brandGradient])
///   - 28dp bottom-corner radius
///   - drop shadow at α=0.18, blur 18, y-offset 6 (matches brand)
///   - status-bar-aware top padding
///   - configurable empty band at the bottom of the gradient so
///     floating KPI cards can overlap without sitting on the
///     greeting/school-pill content.
///
/// The caller owns the inner content (greeting row, school pill,
/// any role-specific affordances) by passing it via [child].
class RoleDashboardHero extends StatelessWidget {
  /// Role identifier — accepts both Indonesian (`admin`, `guru`,
  /// `wali`) and English (`teacher`, `parent`) names. Same matrix
  /// as [ColorUtils.brandGradient].
  final String role;

  /// Hero body — greeting + name + icon buttons + school pill.
  /// The widget already wraps this in a `Column(start)`, so callers
  /// can pass a `Column` of children directly.
  final Widget child;

  /// Bottom padding OUTSIDE the gradient — reserves vertical space
  /// for the KPI strip that floats over the empty band at the
  /// bottom of the hero. The previous hand-rolled shells used 100;
  /// keep that as the default.
  final double bottomOverlap;

  /// Bottom padding INSIDE the gradient, between the last inner row
  /// (typically the school pill) and the rounded edge. 48 in the
  /// pre-extraction implementations.
  final double innerBottomPad;

  const RoleDashboardHero({
    super.key,
    required this.role,
    required this.child,
    this.bottomOverlap = 100,
    this.innerBottomPad = 48,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final gradient = ColorUtils.brandGradient(role);
    final shadowColor = gradient.colors.first;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomOverlap),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            statusBarHeight + AppSpacing.md,
            AppSpacing.md,
            innerBottomPad,
          ),
          child: child,
        ),
      ),
    );
  }
}
