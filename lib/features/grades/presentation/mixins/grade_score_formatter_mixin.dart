import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin providing score formatting and color utilities.
/// Extracted to reduce the main state class size.
mixin GradeScoreFormatterMixin {
  /// Returns color based on score: green (>=80), yellow (>=60), red (<60).
  Color scoreColor(double score) {
    if (score >= 80) return ColorUtils.success600;
    if (score >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  /// Returns abbreviated type label (e.g., 'UH' for 'uh').
  String shortTypeLabel(String type) {
    const labels = {
      'uh': 'UH',
      'tugas': 'Tgs',
      'uts': 'UTS',
      'uas': 'UAS',
      'pts': 'PTS',
      'pas': 'PAS',
    };
    return labels[type] ?? type.toUpperCase();
  }

  /// Formats a score for display (int if whole, 1 decimal if fractional).
  String formatScore(dynamic score) {
    if (score == null) return '-';
    final d = (score is num)
        ? score.toDouble()
        : double.tryParse(score.toString()) ?? 0;
    return d == d.truncateToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(1);
  }
}
