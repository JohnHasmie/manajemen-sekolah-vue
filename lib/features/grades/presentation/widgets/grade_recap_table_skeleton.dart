// Skeleton placeholder shaped like the rekap table.
//
// Why this exists
// ---------------
// While the modal-style entry into [GradeRecapPage] finishes its
// open animation and the recap API responds, we want the user to
// see a structurally honest preview of the table — header row,
// student rows, score columns — instead of a generic list shimmer
// or (worse) a flash of the "Tidak Ada Siswa" empty state.
//
// The widget is fully self-contained: only the per-cell value
// boxes shimmer; the table border, header background, row
// dividers and zebra stripes are painted normally so the layout
// stays anchored.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:shimmer/shimmer.dart';

class GradeRecapTableSkeleton extends StatelessWidget {
  /// Tints the header band; matches the active role's brand colour
  /// so the skeleton reads as a teacher / parent recap rather than
  /// a neutral placeholder.
  final Color primaryColor;

  const GradeRecapTableSkeleton({super.key, required this.primaryColor});

  /// Wraps a single placeholder box in Shimmer so the structure
  /// (table borders, dividers, header bg) remains painted normally
  /// and only the value-sized boxes shimmer.
  Widget _shimBox(double w, double h, [double r = 4]) {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
        ),
      ),
    );
  }

  /// Same as [_shimBox] but height-only — used inside flex children
  /// where the width is dictated by the parent constraint.
  Widget _shimBar(double h, [double r = 4]) {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      period: const Duration(milliseconds: 1200),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
        ),
      ),
    );
  }

  Widget _shimCircle(double size) {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Render a fixed number of rows directly via a non-Expanded Column.
    // This widget is mounted inside `BrandPageLayout`'s outer ListView,
    // which gives unbounded vertical space — `Expanded` would silently
    // fail in that environment and render nothing.
    const rowCount = 12; // enough to fill a typical phone viewport

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ColorUtils.slate200),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row — taller, mimics the actual sticky header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
              ),
              child: Row(
                children: [
                  // Left: "Siswa" label area (fills via flex; no width)
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _shimBar(12),
                    ),
                  ),
                  // Score column headers — equal-width, narrow placeholder
                  for (int i = 0; i < 4; i++)
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _shimBar(12),
                      ),
                    ),
                ],
              ),
            ),

            // Filled rows — alternating zebra, plain Column children
            // (NOT a nested scrollable so it works inside ListView).
            for (int i = 0; i < rowCount; i++)
              _row(isLast: i == rowCount - 1, zebra: i.isOdd),
          ],
        ),
      ),
    );
  }

  Widget _row({bool isLast = false, bool zebra = false}) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: zebra ? ColorUtils.slate50 : Colors.white,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: [
          // Left: number + name (flex 3, fills via Expanded)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  _shimBox(10, 12),
                  const SizedBox(width: 8),
                  Expanded(child: _shimBar(14)),
                ],
              ),
            ),
          ),
          // Score cells — equal-width columns matching the header
          for (int i = 0; i < 4; i++)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: _shimBar(16, 5)),
                    const SizedBox(width: 4),
                    _shimCircle(8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
