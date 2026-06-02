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
  /// Backend rename (rename guide §4) — assessments.type now uses
  /// canonical English values. Legacy Indonesian aliases stay here so
  /// older payloads still render with the right short label.
  String shortTypeLabel(String type) {
    const labels = {
      'uh': 'UH',
      'daily_test': 'UH',
      'tugas': 'Tgs',
      'assignment': 'Tgs',
      'uts': 'UTS',
      'midterm': 'UTS',
      'uas': 'UAS',
      'final_exam': 'UAS',
      'pts': 'PTS',
      'pas': 'PAS',
      'kuis': 'Kuis',
      'quiz': 'Kuis',
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
