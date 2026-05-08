// Small leaf widgets for the recommendation student-list screen.
//
// Why this exists
// ---------------
// `recommendation_student_screen.dart` was inlining two presentational
// helpers — the per-stat tile in the summary bar and the status filter
// chip. Both are stateless and driven by primitives + a single onTap,
// so they pull cleanly into a co-located widgets file.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// One column of the summary bar (icon + value + caption). Used three
/// times across the screen — Total siswa, Belum selesai, Sudah selesai.
class RecommendationSummaryStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const RecommendationSummaryStatItem({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip for status filtering on the recommendation list. Tap
/// flips active state via [onTap]; active state inverts the colours.
class RecommendationFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const RecommendationFilterChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: Border.all(color: isActive ? color : ColorUtils.slate200),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : ColorUtils.slate500,
            ),
          ),
        ),
      ),
    );
  }
}
