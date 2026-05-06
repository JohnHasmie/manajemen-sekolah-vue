// Phase-3 brand-aligned page header for deep-tab screens — compact v2.
//
// What changed in v2 (compact redesign)
// -------------------------------------
// The header is now ~100dp shorter on parent role screens and ~70dp
// shorter on admin role screens. Two structural moves drive the
// savings:
//
//   1. Title block centers in a fixed 3-column toolbar (back / center
//      / actions) instead of stacking below the toolbar. The kicker
//      (subtitle) shrinks from 11px → 10px and sits *inside* the
//      center column above a 19px (was 24px) title.
//   2. The realtime indicator collapses from a full-width pill row
//      ("Terhubung realtime · 21:05") into a 6dp green/grey dot
//      placed inline beside the title. Pass `isRealtimeFresh`
//      instead of building a `BrandRealtimePill` for the new compact
//      surface. The legacy `realtimeIndicator` slot still renders
//      below the title for callers that haven't migrated yet — it's
//      now soft-deprecated.
//
// "PILIH ANAK" / "PILIH KELAS" labels above the child selector were
// dropped; the avatar chips are self-describing. Child chips and
// filter chips render at the new compact sizes (see
// `ChildSelectorChipRow` and `BrandFilterChipStrip`).
//
// M1 tapered hairline + title polish
// ----------------------------------
// Between the title block and any bottom section (childSelector,
// bottomSlot, legacy realtime row) we paint a tapered hairline — a
// 1px line whose alpha fades to 0 at the screen edges (32% white in
// the middle, transparent at the sides). Reads as a deliberate
// section break rather than a hard ruled line. Stripe / Linear use
// the same treatment.
//
// Title polish:
//   • title 19px / weight 700 / letter-spacing -0.1 / line-height 1.15
//   • kicker 10px / weight 700 / 72% white / letter-spacing 1.4
//   • kicker → title gap = 3dp
//
// Companion helpers
// -----------------
//   • [BrandHeaderIconButton] — the 32×32 white-translucent icon
//     button with optional notification badge, used in the action row.
//   • [BrandRealtimePill] — green-dot + "Terhubung realtime · HH:MM"
//     copy, with pulsing animation. Still exported because legacy
//     screens use it, but new screens should prefer the
//     [isRealtimeFresh] inline dot.
//
// Visual contract
// ---------------
// Source-of-truth tokens: `ColorUtils.brandGradient(role)`,
// `ColorUtils.getRoleColor(role)`. Mockup: `Header_Compact_v2.svg`.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A Phase-3 brand-aligned page header for deep-tab screens.
///
/// Compact v2 example:
/// ```dart
/// BrandPageHeader(
///   role: 'wali',
///   subtitle: 'Akademik · Anak',
///   title: 'Kehadiran',
///   isRealtimeFresh: true, // small green dot beside the title
///   actionIcons: [
///     BrandHeaderIconButton(
///       icon: Icons.tune_rounded,
///       onTap: _openFilterSheet,
///       badgeCount: 2,
///     ),
///   ],
///   childSelector: ChildSelectorChipRow(
///     children: _children,
///     selectedChildId: _selectedChildId,
///     onSelected: _onChildSelected,
///   ),
/// );
/// ```
class BrandPageHeader extends StatelessWidget {
  /// Role identifier — drives the gradient via
  /// [ColorUtils.brandGradient]. Accepts both Indonesian (`admin`,
  /// `guru`, `wali`) and English (`teacher`, `parent`) names.
  final String role;

  /// Main title text. Always required.
  final String title;

  /// Optional small kicker line above the title (e.g.
  /// `'Akademik · Anak'`). Renders centered, all-caps, 72% white.
  final String? subtitle;

  /// Back-button tap handler. When null, the back button auto-pops via
  /// [AppNavigator.pop] if [AppNavigator.canPop] is true.
  ///
  /// Pass [showBackButton] = false to suppress the back button entirely
  /// (e.g. for tab-root screens that sit directly inside the bottom
  /// nav shell).
  final VoidCallback? onBackPressed;

  /// Optional list of action icons displayed in the top-right. Each
  /// item is typically a [BrandHeaderIconButton]. Spaced 6px apart.
  final List<Widget>? actionIcons;

  /// When non-null, paints a 6dp dot beside the title — green for
  /// `true` (live), translucent slate for `false` (stale). Cheaper
  /// than the full-row [realtimeIndicator] and the recommended
  /// surface for the compact header.
  final bool? isRealtimeFresh;

  /// Soft-deprecated realtime indicator row (typically
  /// [BrandRealtimePill]). Kept for legacy call sites; new screens
  /// should pass [isRealtimeFresh] instead. When both are provided
  /// the inline dot wins and this widget is ignored.
  final Widget? realtimeIndicator;

  /// Optional row of child-selector chips (parent role typically).
  final Widget? childSelector;

  /// Optional bottom slot — filter chips, search field, or any custom
  /// row. Rendered last inside the gradient.
  final Widget? bottomSlot;

  /// Force-show or force-hide the back button. Defaults to auto:
  /// shown when [onBackPressed] is provided OR
  /// `AppNavigator.canPop(context)`.
  final bool? showBackButton;

  /// Extra bottom padding inside the gradient to reserve space for a
  /// KPI overlay card. Pair with `BrandPageLayout.kpiOverlapHeight`
  /// when the screen also passes a `kpiCard` to `BrandPageLayout`.
  ///
  /// When 0 (default), no extra space is added.
  final double kpiOverlayHeight;

  const BrandPageHeader({
    super.key,
    required this.role,
    required this.title,
    this.subtitle,
    this.onBackPressed,
    this.actionIcons,
    this.isRealtimeFresh,
    this.realtimeIndicator,
    this.childSelector,
    this.bottomSlot,
    this.showBackButton,
    this.kpiOverlayHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final accentColor = ColorUtils.getRoleColor(role);
    final showBack = showBackButton ??
        (onBackPressed != null || Navigator.canPop(context));

    final List<Widget> rightIcons = actionIcons ?? const [];

    final bool hasBottomSection = (isRealtimeFresh == null &&
            realtimeIndicator != null) ||
        childSelector != null ||
        bottomSlot != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ColorUtils.brandGradient(role),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        statusBarHeight + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + kpiOverlayHeight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top toolbar: back / centered title block / actions.
          //
          // Layout: back button gets a fixed 32dp slot, action icons
          // take their natural (intrinsic) width, and the title is
          // wrapped in `Expanded` so it can never push the action
          // icons off-screen. The trade-off is that when the right
          // side is significantly wider than the left, the title is
          // optically centered within its `Expanded` slot rather
          // than within the full toolbar — which is fine for normal
          // 1–3 icon counts and never overflows when callers pass
          // compound action menus (Row of multiple buttons).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                child: showBack
                    ? _HeaderBackButton(
                        onTap:
                            onBackPressed ?? () => AppNavigator.pop(context),
                      )
                    : null,
              ),
              Expanded(
                child: _CenteredTitleBlock(
                  subtitle: subtitle,
                  title: title,
                  isRealtimeFresh: isRealtimeFresh,
                ),
              ),
              if (rightIcons.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 6),
                    for (int i = 0; i < rightIcons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      rightIcons[i],
                    ],
                  ],
                ),
            ],
          ),
          // Tapered hairline divider — fades to transparent at both
          // edges so it reads as a deliberate section break rather
          // than a hard ruled line. Painted only when there's a
          // bottom section (childSelector / bottomSlot / legacy
          // realtime row) to separate from the title block.
          if (hasBottomSection) ...[
            const SizedBox(height: AppSpacing.md),
            const _TaperedHairline(),
            const SizedBox(height: AppSpacing.sm + 2),
          ],
          // Legacy realtime row — only when `isRealtimeFresh` is null
          // and a custom widget was provided. New screens skip this
          // path entirely.
          if (isRealtimeFresh == null && realtimeIndicator != null)
            Center(child: realtimeIndicator!),
          if (childSelector != null) childSelector!,
          if (bottomSlot != null) ...[
            if (childSelector != null) const SizedBox(height: AppSpacing.sm),
            bottomSlot!,
          ],
        ],
      ),
    );
  }
}

/// Internal centered title block: kicker (small caps) above a 19px
/// title with an optional inline live-status dot. Kept private so the
/// header's centering rules can't be broken by callers passing custom
/// alignment.
class _CenteredTitleBlock extends StatelessWidget {
  final String? subtitle;
  final String title;
  final bool? isRealtimeFresh;

  const _CenteredTitleBlock({
    required this.title,
    required this.subtitle,
    required this.isRealtimeFresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle!,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              // Polished: 72% white instead of solid — title still
              // pops harder against it.
              color: Colors.white.withValues(alpha: 0.72),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.1,
                  height: 1.15,
                ),
              ),
            ),
            if (isRealtimeFresh != null) ...[
              const SizedBox(width: 6),
              _LiveDot(isFresh: isRealtimeFresh!),
            ],
          ],
        ),
      ],
    );
  }
}

/// 1px horizontal divider that fades to transparent at the edges —
/// reads as a deliberate section break rather than a hard ruled line.
/// Used between the title block and the bottom sections (child
/// selector, filter chips, legacy realtime row) inside the gradient
/// header.
class _TaperedHairline extends StatelessWidget {
  const _TaperedHairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.25, 0.75, 1.0],
        ),
      ),
    );
  }
}

/// 6dp dot used as the compact realtime indicator. Green when fresh,
/// translucent slate when stale. No animation — keeps the header
/// repaint-free during pulse cycles.
class _LiveDot extends StatelessWidget {
  final bool isFresh;
  const _LiveDot({required this.isFresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: isFresh
            ? const Color(0xFF4ADE80)
            : Colors.white.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Internal back button matching the [BrandHeaderIconButton] idiom but
/// without the badge slot — kept private since back buttons are
/// rendered automatically by [BrandPageHeader].
class _HeaderBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HeaderBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// A 32×32 white-translucent action icon button used in the
/// [BrandPageHeader] top row.
///
/// Optional [badgeCount] paints a small red notification badge at the
/// top-right (rounded-pill for 10+, circle for 1–9, "99+" capped).
/// [badgeBorderColor] should match the gradient stop behind the button
/// for the badge's outer ring — pass `ColorUtils.brandAzure` for parent,
/// `brandDarkBlue` for admin, etc.
class BrandHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badgeCount;
  final Color? badgeBorderColor;

  const BrandHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount,
    this.badgeBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount != null && badgeCount! > 0;
    final isWide = hasBadge && badgeCount! > 9;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            onTap: onTap,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(icon, size: 16, color: Colors.white),
            ),
          ),
        ),
        if (hasBadge)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 4 : 0),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: const BorderRadius.all(Radius.circular(9)),
                border: Border.all(
                  color: badgeBorderColor ?? Colors.white,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount! > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
