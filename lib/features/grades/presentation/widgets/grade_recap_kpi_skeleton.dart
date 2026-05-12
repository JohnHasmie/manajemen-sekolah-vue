// Skeleton placeholder for the 3-cell KPI overlap card on the rekap
// nilai detail dialog (Tuntas · Belum · Rata-rata).
//
// Mirrors the shape and dimensions of the live [_buildBrandKpiCard]
// in `teacher_grade_recap_screen.dart` so the swap is invisible at
// the moment the data resolves: the card outline, padding, and
// dividers stay anchored, only the inner value + label boxes fade
// from shimmer to real content.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:shimmer/shimmer.dart';

class GradeRecapKpiSkeleton extends StatelessWidget {
  const GradeRecapKpiSkeleton({super.key});

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

  Widget _cell() {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Value placeholder (matches fontSize: 22 height ≈ 22)
          _shimBox(40, 22, 6),
          const SizedBox(height: 6),
          // Label placeholder (matches uppercase fontSize: 9.5 height ≈ 10)
          _shimBox(54, 10, 4),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 28, color: ColorUtils.slate100);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [_cell(), _divider(), _cell(), _divider(), _cell()],
        ),
      ),
    );
  }
}
