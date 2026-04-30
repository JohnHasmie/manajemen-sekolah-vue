// Phase-3 brand-aligned page header for deep-tab screens.
//
// What this is for
// ----------------
// Every deep-tab screen in the parent role (and eventually teacher/admin)
// gets the same gradient hero pattern: brand gradient background, back
// button on the left, kicker-subtitle + title in the middle, action
// icons on the right, and optional rows for a realtime indicator,
// child-selector chips, or filter chips below.
//
// `BrandPageHeader` is the canonical implementation. The dashboard
// bodies build their own variant inline because they need a more
// complex hero (greeting, school pill, KPI overlay) — but every other
// screen should use this widget so a brand refresh changes one place.
//
// Companion helpers
// -----------------
//   • [BrandHeaderIconButton] — the 36×36 white-translucent icon
//     button with optional notification badge, used in the action row.
//   • [BrandRealtimePill] — green-dot + "Terhubung realtime · HH:MM"
//     copy, with pulsing animation; matches the dashboard hero exactly.
//
// Visual contract
// ---------------
// Mirrors the gradient-hero idiom used in the role dashboards and
// documented in the parent Phase-3 mockup SVGs. Source-of-truth tokens:
// `ColorUtils.brandGradient(role)`, `ColorUtils.getRoleColor(role)`.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A Phase-3 brand-aligned page header for deep-tab screens.
///
/// Example:
/// ```dart
/// BrandPageHeader(
///   role: 'wali',
///   subtitle: 'Akademik · Anak',
///   title: 'Kehadiran',
///   actionIcons: [
///     BrandHeaderIconButton(
///       icon: Icons.tune_rounded,
///       onTap: _openFilterSheet,
///       badgeCount: 2,
///     ),
///   ],
///   realtimeIndicator: BrandRealtimePill(
///     isFresh: _isFresh,
///     lastSync: _lastSync,
///   ),
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
  /// `'Akademik · Anak'`). Renders in 78% white when present.
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

  /// Optional realtime indicator row (use [BrandRealtimePill]). Sits
  /// between the title row and any child selector / filter chips.
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
  /// KPI overlay card. The body's scroll view should start with a
  /// negative top margin (e.g. `padding: EdgeInsets.only(top: 0)` +
  /// the KPI as the first child) so the KPI sits ON this extended
  /// gradient area, creating the overlap effect.
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
    // Use Navigator.canPop (Flutter navigator) instead of context.canPop
    // (go_router) because screens pushed via AppNavigator.push use
    // Flutter's Navigator, not go_router's routing.
    final showBack = showBackButton ??
        (onBackPressed != null || Navigator.canPop(context));

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
        statusBarHeight + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg + kpiOverlayHeight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: back + title block + action icons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBack) ...[
                _HeaderBackButton(
                  onTap: onBackPressed ?? () => AppNavigator.pop(context),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subtitle != null) ...[
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          // Solid white — hard color, no semi-transparent
                          // greys. Reads cleanly on the brand gradient.
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.1,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionIcons != null && actionIcons!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                for (int i = 0; i < actionIcons!.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  actionIcons![i],
                ],
              ],
            ],
          ),
          if (realtimeIndicator != null) ...[
            const SizedBox(height: AppSpacing.md),
            realtimeIndicator!,
          ],
          if (childSelector != null) ...[
            const SizedBox(height: AppSpacing.md),
            childSelector!,
          ],
          if (bottomSlot != null) ...[
            const SizedBox(height: AppSpacing.md),
            bottomSlot!,
          ],
        ],
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
          width: 36,
          height: 36,
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// A 36×36 white-translucent action icon button used in the
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
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: Colors.white),
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
