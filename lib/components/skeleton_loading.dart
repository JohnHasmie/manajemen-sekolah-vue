import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable skeleton loading card that mimics a list item card layout.
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
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Shimmer.fromColors(
        baseColor: baseColor ?? ColorUtils.shimmerBaseColor,
        highlightColor: highlightColor ?? ColorUtils.shimmerHighlightColor,
        child: Row(
          children: [
            // Avatar placeholder
            CircleAvatar(radius: 22, backgroundColor: Colors.white),
            SizedBox(width: 12),

            // Content placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name placeholder
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: 8),
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
                          SizedBox(width: 6),
                          if (index == 0) _buildTagPlaceholder(50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),

            // Right side placeholders
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status chip placeholder
                Container(
                  width: 52,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                if (showActions) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      SizedBox(width: 6),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// A list of skeleton cards used as loading placeholder.
/// Drop-in replacement for CircularProgressIndicator in list views.
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
      physics: NeverScrollableScrollPhysics(),
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
