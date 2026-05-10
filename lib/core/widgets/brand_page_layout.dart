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

  /// When true, the [kpiCard] stays pinned at the top of the body
  /// region (below the gradient header) and does NOT scroll with the
  /// content. The body's scrollable area starts below the pinned KPI
  /// instead of at `bodyTop`.
  ///
  /// Default `false` keeps the existing scroll-with-body pattern.
  /// Use `true` for screens where the KPI must remain visible while
  /// the user scrolls a long body — e.g. Ambil Presensi where the
  /// live status counts (Hadir / Sakit / Izin / Alpa) are the
  /// teacher's primary feedback during data entry.
  ///
  /// The gradient mask layer is suppressed when sticky because there
  /// is no "KPI scrolls past" event; the KPI itself permanently
  /// covers the overlap zone.
  final bool kpiSticky;

  const BrandPageLayout({
    super.key,
    required this.header,
    this.kpiCard,
    this.overlapHeight = kpiOverlapHeight,
    this.onRefresh,
    this.role = 'wali',
    this.bodyChildren = const [],
    this.bottomPadding = 24,
    this.kpiSticky = false,
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

    // Sticky mode pulls the KPI out of the scrollable list and
    // pins it as an absolute layer just below the header. The
    // body's scrollable area starts below the pinned KPI so the
    // first row isn't hidden behind it.
    final sticky = widget.kpiSticky && hasKpi;

    final list = ListView(
      controller: _scrollCtrl,
      padding: EdgeInsets.only(
        bottom: widget.bottomPadding,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Scroll-with-body mode: KPI is the first list item.
        // Sticky mode: skip — KPI is rendered as an absolute layer.
        if (hasKpi && !sticky)
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

    // Sticky mode pushes the body down so the first scrollable
    // row sits below the pinned KPI rather than under it. Falls
    // back to bodyTop on first frames before _kpiH is measured.
    final effectiveBodyTop = sticky ? bodyTop + _kpiH : bodyTop;

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
            top: effectiveBodyTop,
            child: body,
          ),
          // 3a. Sticky KPI — pinned above the scrollable body,
          //     overlapping the gradient header by `overlap` dp.
          //     Doesn't scroll, so the gradient mask layer below
          //     is never needed in this mode.
          if (sticky)
            Positioned(
              top: bodyTop,
              left: 0,
              right: 0,
              child: KeyedSubtree(
                key: _kpiKey,
                child: widget.kpiCard!,
              ),
            ),
          // 3b. Gradient mask — covers the overlap zone in
          //     scroll-with-body mode once the KPI has scrolled
          //     past. Skipped in sticky mode (KPI never scrolls).
          if (!sticky && _showMask && overlap > 0)
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
