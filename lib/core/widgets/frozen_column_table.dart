// Shared frozen-column table scaffold.
//
// Renders a table with a sticky "frozen" left block (one OR more columns)
// and a horizontally scrollable right side. Used by any feature that needs
// spreadsheet-style layout: grade recap, finance report, raport (report
// card) overview, grade input overview, etc.
//
// The widget is intentionally generic — it doesn't know about grades,
// students, months, or classes. Callers supply cells via builder callbacks.
//
// Three header variants are supported:
//   • Primary header only (grades, raport)
//   • Primary + secondary header (finance: month groups above payment types)
//
// Both sides use a symmetric column API: `leftColumns` mirrors
// `rightColumns`. Callers that only need one frozen column pass a single-
// element list.
//
// `headerBackgroundColor`, when non-null, paints the primary header row on
// BOTH the frozen left and scrollable right sides — so callers don't need
// to wrap their header widgets in a color container. Pass null (default)
// when the caller wants to paint its own per-header backgrounds (e.g.
// finance, which has different colors on the month-group vs. payment-type
// rows).
//
// Row-level tap (`onRowTap`) wraps each cell in an InkWell on both sides,
// so tapping anywhere in a row triggers the same callback.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Specification for one column (left-frozen OR right-scrollable).
class FrozenTableColumn {
  /// Column width in pixels. All columns must have an explicit width so the
  /// header row, secondary header, and every data row stay aligned.
  final double width;

  /// Header cell for this column. Rendered inside the primary header row.
  final Widget header;

  /// Builds the cell for this column at the given [rowIndex].
  /// The cell should size itself to [width] (the scaffold does not clip).
  final Widget Function(int rowIndex) cellBuilder;

  const FrozenTableColumn({
    required this.width,
    required this.header,
    required this.cellBuilder,
  });
}

/// Horizontally scrollable table with one or more frozen left columns.
///
/// See the file-level doc comment for the overall design.
class FrozenColumnTable extends StatefulWidget {
  // ── Data ──
  final int rowCount;

  // ── Left (frozen) columns ──

  /// One or more frozen columns rendered on the left. When the list has
  /// multiple entries they are rendered side-by-side inside the frozen
  /// block and each scrolls with the block as a unit (i.e. they don't move
  /// when the right side scrolls horizontally). Widths are independent.
  final List<FrozenTableColumn> leftColumns;

  /// Optional row rendered ABOVE the primary left-header row, spanning the
  /// full frozen-block width. Used in conjunction with
  /// [rightSecondaryHeader] when the scrollable side has a two-level header
  /// (e.g. finance's month groups). Leave null (default) for a single-row
  /// header.
  final Widget? leftSecondaryHeader;

  // ── Right (scrollable) columns ──
  final List<FrozenTableColumn> rightColumns;

  /// Optional row rendered ABOVE the primary right-header row. Must be a
  /// Row of fixed-width children whose widths sum to the same total as the
  /// [rightColumns] below. Scrolls together with the rest of the right side.
  final Widget? rightSecondaryHeader;

  // ── Layout ──
  final double headerHeight;
  final double rowHeight;

  /// Height of the optional secondary header row. Only used when
  /// [leftSecondaryHeader] and [rightSecondaryHeader] are non-null.
  final double secondaryHeaderHeight;

  // ── Styling ──

  /// Background color painted across the primary header row on BOTH sides.
  /// Leave null when the caller wants to paint its own per-header
  /// backgrounds (e.g. finance's mixed slate + blue headers).
  final Color? headerBackgroundColor;

  /// Reserved for future use by default header builders. Currently unused
  /// by the scaffold itself — callers can read it for styling context.
  final Color? primaryColor;

  /// Per-row decoration override. If null, alternates white / slate50 with
  /// a bottom border. Return null from the builder to skip decoration for a
  /// specific row.
  final BoxDecoration? Function(int rowIndex)? rowDecorationBuilder;

  /// Optional shadow on the frozen block's right edge. Adds a visual cue
  /// that the block is sticky. Defaults to a soft black shadow.
  final bool showLeftColumnShadow;

  // ── Interaction ──

  /// Row-level tap handler. When non-null, each cell on both sides is
  /// wrapped in an InkWell that fires this callback. Null = read-only.
  final void Function(int rowIndex)? onRowTap;

  /// External controller for the right-side horizontal scroll. Useful when
  /// multiple tables need to scroll in sync. Defaults to an internal one.
  final ScrollController? horizontalController;

  const FrozenColumnTable({
    super.key,
    required this.rowCount,
    required this.leftColumns,
    required this.rightColumns,
    this.leftSecondaryHeader,
    this.rightSecondaryHeader,
    this.headerHeight = 52,
    this.rowHeight = 44,
    this.secondaryHeaderHeight = 30,
    this.headerBackgroundColor,
    this.primaryColor,
    this.rowDecorationBuilder,
    this.showLeftColumnShadow = true,
    this.onRowTap,
    this.horizontalController,
  })  : assert(
          leftColumns.length > 0,
          'leftColumns must contain at least one column.',
        ),
        assert(
          (leftSecondaryHeader == null) == (rightSecondaryHeader == null),
          'leftSecondaryHeader and rightSecondaryHeader must both be null '
          'or both non-null.',
        );

  @override
  State<FrozenColumnTable> createState() => _FrozenColumnTableState();
}

class _FrozenColumnTableState extends State<FrozenColumnTable> {
  ScrollController? _ownedController;

  ScrollController get _horizontalController =>
      widget.horizontalController ?? (_ownedController ??= ScrollController());

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  bool get _hasSecondaryHeader => widget.leftSecondaryHeader != null;

  double get _leftTotalWidth =>
      widget.leftColumns.fold<double>(0, (acc, c) => acc + c.width);

  double get _rightTotalWidth =>
      widget.rightColumns.fold<double>(0, (acc, c) => acc + c.width);

  BoxDecoration _defaultRowDecoration(int rowIndex) {
    return BoxDecoration(
      color: rowIndex.isEven ? Colors.white : ColorUtils.slate50,
      border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
    );
  }

  /// Wraps a cell in an InkWell when `onRowTap` is set. We intentionally
  /// apply this per-cell (not per-row) because the left and right sides
  /// live in separate widget subtrees — wrapping each cell keeps ripple
  /// feedback localized and avoids fighting the horizontal scroll view's
  /// gesture arena.
  Widget _wrapTappable(int rowIndex, Widget child) {
    if (widget.onRowTap == null) return child;
    return InkWell(
      onTap: () => widget.onRowTap!(rowIndex),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeftBlock(),
        Expanded(child: _buildRightScrollable()),
      ],
    );
  }

  Widget _buildLeftBlock() {
    final totalWidth = _leftTotalWidth;
    return Container(
      width: totalWidth,
      decoration: widget.showLeftColumnShadow
          ? BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(2, 0),
                ),
              ],
            )
          : const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          if (_hasSecondaryHeader)
            SizedBox(
              height: widget.secondaryHeaderHeight,
              width: totalWidth,
              child: widget.leftSecondaryHeader!,
            ),
          SizedBox(
            height: widget.headerHeight,
            width: totalWidth,
            child: Container(
              color: widget.headerBackgroundColor,
              child: Row(
                children: [
                  for (final col in widget.leftColumns)
                    SizedBox(width: col.width, child: col.header),
                ],
              ),
            ),
          ),
          for (int i = 0; i < widget.rowCount; i++)
            Container(
              height: widget.rowHeight,
              width: totalWidth,
              decoration:
                  widget.rowDecorationBuilder?.call(i) ??
                      _defaultRowDecoration(i),
              child: Row(
                children: [
                  for (final col in widget.leftColumns)
                    SizedBox(
                      width: col.width,
                      child: _wrapTappable(i, col.cellBuilder(i)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightScrollable() {
    final rightWidth = _rightTotalWidth;
    final headerStripHeight = widget.headerHeight +
        (_hasSecondaryHeader ? widget.secondaryHeaderHeight : 0);

    final scrollable = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalController,
      child: SizedBox(
        width: rightWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasSecondaryHeader)
              SizedBox(
                height: widget.secondaryHeaderHeight,
                width: rightWidth,
                child: widget.rightSecondaryHeader!,
              ),
            SizedBox(
              height: widget.headerHeight,
              width: rightWidth,
              child: Container(
                color: widget.headerBackgroundColor,
                child: Row(
                  children: [
                    for (final col in widget.rightColumns)
                      SizedBox(width: col.width, child: col.header),
                  ],
                ),
              ),
            ),
            for (int i = 0; i < widget.rowCount; i++)
              Container(
                height: widget.rowHeight,
                width: rightWidth,
                decoration: widget.rowDecorationBuilder?.call(i) ??
                    _defaultRowDecoration(i),
                child: Row(
                  children: [
                    for (final col in widget.rightColumns)
                      SizedBox(
                        width: col.width,
                        child: _wrapTappable(i, col.cellBuilder(i)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    // When the right-side content is narrower than the available viewport
    // (few columns, like the Nilai overview), the horizontal scroll view
    // leaves an empty region on the right. Without this strip,
    // `headerBackgroundColor` would cut off at the end of the last column —
    // leaving a visible white gap in the header. The stack paints a full-
    // width header-colored rectangle *behind* the scroll view so the tint
    // visually extends across the entire header area.
    if (widget.headerBackgroundColor == null) {
      return scrollable;
    }

    // The Stack below has ONLY Positioned children, so it CANNOT size itself
    // intrinsically. When this widget is placed inside a vertical
    // SingleChildScrollView (as grade input, grade recap, raport, and finance
    // all do), it receives unbounded height from the Row > Expanded chain and
    // RenderStack._computeSize trips its "Stack cannot determine its own
    // size" assertion, which surfaces as a hard crash on the Kelola Nilai
    // screen. Because we already know the table's intrinsic height
    // (header strip + rowHeight × rowCount), wrap the Stack in an explicit
    // SizedBox to give it bounded constraints.
    final totalHeight = headerStripHeight + widget.rowHeight * widget.rowCount;
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: headerStripHeight,
            child: ColoredBox(color: widget.headerBackgroundColor!),
          ),
          Positioned.fill(child: scrollable),
        ],
      ),
    );
  }
}
