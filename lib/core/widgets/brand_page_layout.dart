// Shared page layout with sticky header + KPI overlap.
//
// Uses a Stack where the header is painted first (fills its intrinsic
// height) and the scrollable body is positioned to start [overlapHeight]
// px above the header's bottom edge. This creates a true visual overlap
// where the KPI card sits on the header's gradient rounded area.
//
// Usage:
// ```dart
// BrandPageLayout(
//   header: BrandPageHeader(role: 'wali', title: 'Nilai', ...),
//   kpiCard: BrandKpiStrip(columns: [...]),
//   onRefresh: () => loadData(),
//   bodyChildren: [gradeList, ...],
// )
// ```
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class BrandPageLayout extends StatefulWidget {
  /// Sticky header — typically [BrandPageHeader].
  final Widget header;

  /// Optional KPI card that overlaps the header's bottom rounded area.
  final Widget? kpiCard;

  /// Overlap amount. The body starts this many px above the header's
  /// bottom edge. Only applies when [kpiCard] is set. Default: 40.
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
  State<BrandPageLayout> createState() => _BrandPageLayoutState();
}

class _BrandPageLayoutState extends State<BrandPageLayout> {
  final _headerKey = GlobalKey();
  double _headerHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && mounted) {
      final h = box.size.height;
      if (h != _headerHeight) setState(() => _headerHeight = h);
    }
  }

  @override
  void didUpdateWidget(covariant BrandPageLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  Widget build(BuildContext context) {
    final hasKpi = widget.kpiCard != null;
    final overlap = hasKpi ? widget.overlapHeight : 0.0;
    // Top inset for the body = header height minus overlap.
    // Before measurement, use 0 (header renders on top, body fills).
    final bodyTop =
        _headerHeight > 0 ? _headerHeight - overlap : 0.0;

    return Stack(
      children: [
        // Header — painted first, measures itself
        Positioned(
          key: _headerKey,
          top: 0,
          left: 0,
          right: 0,
          child: widget.header,
        ),
        // Body — starts overlap-px above header bottom
        Positioned(
          top: bodyTop,
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final accent = ColorUtils.getRoleColor(widget.role);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      children: [
        if (widget.kpiCard != null) widget.kpiCard!,
        ...widget.bodyChildren,
      ],
    );

    if (widget.onRefresh == null) return list;

    return RefreshIndicator(
      color: accent,
      edgeOffset: 20,
      onRefresh: widget.onRefresh!,
      child: list,
    );
  }
}
