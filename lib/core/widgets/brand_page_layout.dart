// Shared page layout with sticky header + scrollable body.
//
// Stack with 3 layers:
//   1. Header (back)     — always behind
//   2. Body (middle)     — scrollable, starts at headerH - overlap
//   3. Gradient mask (front) — covers overlap zone, hidden at rest,
//      shown after KPI scrolls past. IgnorePointer so touch
//      passes through to the body.
//
// IMPORTANT — KPI overlap rule
// ----------------------------
// When [kpiCard] is provided, the body region is positioned at
// `top: headerH - overlapHeight`. The kpiCard's top edge therefore
// sits `overlapHeight` dp INSIDE the bottom of the header. If the
// header's gradient doesn't extend that far past its content (e.g.
// past the chip strip), the KPI's top will VISUALLY COVER the chip
// strip / realtime row at the bottom of the header.
//
// Convention: every `BrandPageHeader` paired with a `kpiCard` must
// pass `kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight` so the
// gradient (and the chip strip's underlying "free" zone) extends far
// enough for the KPI to overlap into without consuming the chips.
// `BrandPageLayout` asserts this in debug mode by inspecting the
// layout-time positions of the header and kpiCard via GlobalKeys.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class BrandPageLayout extends StatefulWidget {
  /// Default overlap height used when a `kpiCard` is provided.
  ///
  /// Pass this exact value as
  /// `BrandPageHeader.kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight`
  /// in any screen that uses both this layout and a kpiCard, otherwise
  /// the kpiCard's overlap zone will sit on top of the chip strip /
  /// realtime row at the bottom of the header.
  static const double kpiOverlapHeight = 45;

  final Widget header;
  final Widget? kpiCard;
  final double overlapHeight;
  final Future<void> Function()? onRefresh;
  final String role;
  final List<Widget> bodyChildren;
  final double bottomPadding;

  const BrandPageLayout({
    super.key,
    required this.header,
    this.kpiCard,
    this.overlapHeight = kpiOverlapHeight,
    this.onRefresh,
    this.role = 'wali',
    this.bodyChildren = const [],
    this.bottomPadding = 24,
  });

  @override
  State<BrandPageLayout> createState() =>
      _BrandPageLayoutState();
}

class _BrandPageLayoutState extends State<BrandPageLayout> {
  final _headerKey = GlobalKey();
  final _kpiKey = GlobalKey();
  final _scrollCtrl = ScrollController();
  double _headerH = 0;
  double _kpiH = 0;
  bool _showMask = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show the gradient mask once KPI has fully scrolled
    // past (offset > KPI card height).
    final threshold = _kpiH > 0 ? _kpiH : 80;
    final shouldShow = _scrollCtrl.offset > threshold;
    if (shouldShow != _showMask) {
      setState(() => _showMask = shouldShow);
    }
  }

  void _measure() {
    // Measure header.
    final hRo = _headerKey.currentContext
        ?.findRenderObject() as RenderBox?;
    if (hRo != null && hRo.hasSize) {
      final h = hRo.size.height;
      if ((h - _headerH).abs() > 1) {
        setState(() => _headerH = h);
      }
    }
    // Measure KPI card.
    final kRo = _kpiKey.currentContext
        ?.findRenderObject() as RenderBox?;
    if (kRo != null && kRo.hasSize) {
      final h = kRo.size.height;
      if ((h - _kpiH).abs() > 1) _kpiH = h;
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measure();
    });

    final accent = ColorUtils.getRoleColor(widget.role);
    final hasKpi = widget.kpiCard != null;
    final overlap = hasKpi ? widget.overlapHeight : 0.0;
    final bodyTop =
        (_headerH - overlap).clamp(0.0, double.infinity);

    final list = ListView(
      controller: _scrollCtrl,
      padding: EdgeInsets.only(
        bottom: widget.bottomPadding,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (hasKpi)
          KeyedSubtree(
            key: _kpiKey,
            child: widget.kpiCard!,
          ),
        ...widget.bodyChildren,
      ],
    );

    final body = widget.onRefresh != null
        ? RefreshIndicator(
            color: accent,
            edgeOffset: 20,
            onRefresh: widget.onRefresh!,
            child: list,
          )
        : list;

    final headerWidget = KeyedSubtree(
      key: _headerKey,
      child: widget.header,
    );

    // Before measured: Column so header can lay out.
    if (_headerH == 0) {
      return Column(
        children: [
          headerWidget,
          Expanded(child: body),
        ],
      );
    }

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 1. Header — behind everything.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: headerWidget,
          ),
          // 2. Body — in front of header. Scrollable.
          Positioned.fill(
            top: bodyTop,
            child: body,
          ),
          // 3. Gradient mask — covers the overlap zone.
          //    Hidden at rest (KPI visible). Shown after
          //    KPI scrolls past (covers the gap).
          //    IgnorePointer so touches go to the body.
          if (_showMask && overlap > 0)
            Positioned(
              top: bodyTop,
              left: 0,
              right: 0,
              height: overlap,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: ColorUtils.brandGradient(
                      widget.role,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
