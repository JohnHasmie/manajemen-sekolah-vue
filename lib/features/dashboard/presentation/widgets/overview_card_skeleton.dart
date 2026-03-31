// Shimmer skeleton placeholder for an overview card in the "Today's Overview" grid.
// Shown while the dashboard stats are loading — matches the shape of OverviewCard.
// Like a Vue `<Skeleton>` component that mirrors a card in a 2-column grid layout.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder that mirrors the visual structure of [OverviewCard].
///
/// Used to populate the 2-column grid in the "Today's Overview" section while
/// real data is being fetched.  Matches the card's padding, border-radius, and
/// internal layout (icon row + two text lines + a footer line) so the loading
/// state has no visible layout shift.
///
/// Usage:
/// ```dart
/// GridView.count(
///   children: List.generate(4, (_) => const OverviewCardSkeleton()),
/// )
/// ```
class OverviewCardSkeleton extends StatelessWidget {
  const OverviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: ColorUtils.slate200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Placeholder for the icon
                _shimmerBox(width: 36, height: 36, borderRadius: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Placeholder for the numeric value
                      _shimmerBox(width: 40, height: 20, borderRadius: 4),
                      const SizedBox(height: AppSpacing.xs),
                      // Placeholder for the title
                      _shimmerBox(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Placeholder for the subtitle/footer line
            _shimmerBox(width: 100, height: 10, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  /// Small helper to build a white rounded rectangle that Shimmer will animate.
  Widget _shimmerBox({
    required double width,
    required double height,
    required double borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
