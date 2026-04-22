import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for building the progress indicator section.
mixin ProgressBarMixin {
  /// Abstract getter for build context (provided by State).
  BuildContext get context;

  /// Build the progress bar showing completion percentage.
  Widget buildProgressBar(int total, int filled) {
    final progressColor = ColorUtils.getRoleColor('guru');
    final percentage = total > 0 ? (filled * 100 / total).round() : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 11,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 11,
                  color: progressColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: total > 0 ? filled / total : 0,
                backgroundColor: ColorUtils.slate100,
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
