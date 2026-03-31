// A single shimmer placeholder card for one RPP section.
// Like a Vue <SkeletonBlock> — takes a title string and height,
// renders a labelled shimmer box. Used inside the polling skeleton body.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:shimmer/shimmer.dart';

/// Renders a section heading and a shimmer placeholder box beneath it.
///
/// [title] is the section label (e.g. "A. Kompetensi Inti (KI)").
/// [height] controls how tall the shimmer placeholder is.
class LessonPlanSkeletonSection extends StatelessWidget {
  final String title;
  final double height;

  const LessonPlanSkeletonSection({
    super.key,
    required this.title,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ColorUtils.slate800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Shimmer.fromColors(
          baseColor: ColorUtils.shimmerBaseColor,
          highlightColor: ColorUtils.shimmerHighlightColor,
          child: Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
