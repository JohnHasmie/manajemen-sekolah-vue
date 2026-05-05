// Shared page layout with sticky header + scrollable body.
//
// Simple Column(header, Expanded(body)) pattern. The header stays
// pinned at the top. The body scrolls independently with pull-to-refresh.
//
// When [kpiCard] is provided, it renders as the first child of the
// body's ListView. The header's [kpiOverlayHeight] extends the gradient
// so the KPI visually sits on the gradient area.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class BrandPageLayout extends StatelessWidget {
  /// Sticky header — typically [BrandPageHeader].
  final Widget header;

  /// Optional KPI card rendered as the first body child.
  final Widget? kpiCard;

  /// Overlap amount — not used directly here but kept for API compat.
  final double overlapHeight;

  /// Pull-to-refresh callback.
  final Future<void> Function()? onRefresh;

  /// Role for accent color on RefreshIndicator.
  final String role;

  /// Body widgets rendered below the KPI card (if any).
  final List<Widget> bodyChildren;

  /// Bottom padding for the scroll area.
  final double bottomPadding;

  const BrandPageLayout({
    super.key,
    required this.header,
    this.kpiCard,
    this.overlapHeight = 40,
    this.onRefresh,
    this.role = 'wali',
    this.bodyChildren = const [],
    this.bottomPadding = 24,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.getRoleColor(role);

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: [
        if (kpiCard != null) kpiCard!,
        ...bodyChildren,
      ],
    );

    final body = onRefresh != null
        ? RefreshIndicator(
            color: accent,
            edgeOffset: 20,
            onRefresh: onRefresh!,
            child: list,
          )
        : list;

    return Column(
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }
}
