// Shimmer skeleton placeholder for a quick-action button in the horizontal scroll row.
// Shown while dashboard data loads — matches the size/shape of QuickActionButton.
// Like a Vue `<Skeleton>` scoped to one action-button column in the quick-access strip.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder that mirrors the visual structure of [QuickActionButton].
///
/// Rendered inside the horizontal [ListView] in the "Quick Access" section
/// while the real action buttons are not yet available.  Matches the button's
/// column layout: a rounded rectangle for the icon box and a short bar for
/// the label underneath.
///
/// Usage:
/// ```dart
/// ListView.separated(
///   itemCount: 4,
///   itemBuilder: (_, __) => const QuickActionSkeleton(),
/// )
/// ```
class QuickActionSkeleton extends StatelessWidget {
  const QuickActionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Placeholder for the icon box
          Container(
            width: 65,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 6),
          // Placeholder for the label
          Container(
            width: 50,
            height: 11,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
