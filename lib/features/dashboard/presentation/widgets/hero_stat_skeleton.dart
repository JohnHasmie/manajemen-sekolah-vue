// Shimmer skeleton placeholder for a single stat cell in the hero banner.
// Shown while dashboard stats are loading — matches the size/shape of HeroStatCell.
// Like a Vue `<Skeleton>` component scoped to one hero-stat column.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder that mirrors the visual structure of [HeroStatCell].
///
/// Rendered in place of real stats while the dashboard is fetching data from
/// the API.  Uses white-on-white shimmer so it blends into the hero gradient
/// background (the hero banner itself is a coloured gradient, so standard
/// grey shimmer would look wrong here).
///
/// Drop-in inside an [Expanded] just like [HeroStatCell]:
/// ```dart
/// Expanded(child: HeroStatSkeleton())
/// ```
class HeroStatSkeleton extends StatelessWidget {
  const HeroStatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      // White-tinted shimmer so it blends with the hero gradient background
      baseColor: Colors.white.withValues(alpha: 0.15),
      highlightColor: Colors.white.withValues(alpha: 0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Placeholder for the icon box
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
          ),
          const SizedBox(height: 6),
          // Placeholder for the numeric value
          Container(
            width: 28,
            height: 17,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 4),
          // Placeholder for the label
          Container(
            width: 36,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }
}
