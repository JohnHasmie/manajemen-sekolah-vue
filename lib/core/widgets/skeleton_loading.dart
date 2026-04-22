// Skeleton loading (shimmer) components for list views.
//
// Like a Vue `<SkeletonLoader>` component or the `vue-content-loading` package.
// In Laravel/Vue apps you might use a CSS skeleton loader while data loads;
// in Flutter we use the `shimmer` package for the same animated placeholder effect.
// These components replace `CircularProgressIndicator` for a better perceived
// performance experience (content-first loading pattern).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A single skeleton loading card that mimics a list item card layout.
///
/// Like a Vue `<SkeletonCard>` component shown with `v-if="isLoading"`.
/// Uses the `shimmer` package for an animated shine effect, similar to
/// Facebook/Instagram-style content placeholders.
///
/// Props:
/// - [infoTagCount] - number of placeholder tag rows (customizes skeleton shape)
/// - [showActions] - whether to show action button placeholders on the right
/// - [baseColor] / [highlightColor] - customizable shimmer colors
///
/// Used across management screens (student, teacher, etc.) for consistent loading UX.
class SkeletonListCard extends StatelessWidget {
  /// Number of info tag rows below the title
  final int infoTagCount;

  /// Whether to show action button placeholders on the right
  final bool showActions;

  /// Custom base color for shimmer
  final Color? baseColor;

  /// Custom highlight color for shimmer
  final Color? highlightColor;

  const SkeletonListCard({
    super.key,
    this.infoTagCount = 1,
    this.showActions = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Shimmer.fromColors(
        baseColor: baseColor ?? ColorUtils.shimmerBaseColor,
        highlightColor: highlightColor ?? ColorUtils.shimmerHighlightColor,
        child: Row(
          children: [
            // Avatar placeholder
            const CircleAvatar(radius: 22, backgroundColor: Colors.white),
            AppSpacing.h12,

            // Content placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name placeholder
                  Container(
                    width: 120,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  AppSpacing.v8,
                  // Info tags
                  ...List.generate(
                    infoTagCount,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index < infoTagCount - 1 ? 6 : 0,
                      ),
                      child: Row(
                        children: [
                          _buildTagPlaceholder(60),
                          const SizedBox(width: 6),
                          if (index == 0) _buildTagPlaceholder(50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.h8,

            // Right side placeholders
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status chip placeholder
                Container(
                  width: 52,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                if (showActions) ...[
                  AppSpacing.v8,
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagPlaceholder(double width) {
    return Container(
      width: width,
      height: 18,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    );
  }
}

/// A list of [SkeletonListCard] widgets used as a loading placeholder.
///
/// Drop-in replacement for `CircularProgressIndicator` in list views.
/// Like wrapping multiple `<SkeletonCard>` components in a `v-for` with
/// a fixed count. Use this as the body of your list screen while loading.
class SkeletonListLoading extends StatelessWidget {
  /// Number of skeleton cards to display
  final int itemCount;

  /// Number of info tag rows per card
  final int infoTagCount;

  /// Whether to show action button placeholders
  final bool showActions;

  /// Padding around the list
  final EdgeInsets padding;

  /// Custom base color for shimmer
  final Color? baseColor;

  /// Custom highlight color for shimmer
  final Color? highlightColor;

  const SkeletonListLoading({
    super.key,
    this.itemCount = 6,
    this.infoTagCount = 1,
    this.showActions = true,
    this.padding = const EdgeInsets.only(top: 8, bottom: 16),
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonListCard(
        infoTagCount: infoTagCount,
        showActions: showActions,
        baseColor: baseColor,
        highlightColor: highlightColor,
      ),
    );
  }
}
