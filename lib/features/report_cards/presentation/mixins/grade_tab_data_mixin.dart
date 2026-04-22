import 'package:flutter/material.dart';

/// Mixin for report card grade tab data processing and calculations.
mixin GradeTabDataMixin {
  /// Check if a subject has a non-empty score.
  bool hasScore(Map<String, dynamic> subject) {
    final score = subject['knowledge_score']?.toString() ?? '';
    return score.isNotEmpty && score != '0';
  }

  /// Parse dynamic value to double, returning null if invalid or zero.
  double? parseNum(dynamic value) {
    if (value == null) return null;
    final d = double.tryParse(value.toString());
    return (d == null || d == 0) ? null : d;
  }

  /// Apply recap suggestion by auto-filling knowledge score.
  void applyRecapSuggestion(
    int index,
    List<Map<String, dynamic>> subjects,
    void Function(int, String, String) onSubjectChanged,
    VoidCallback onMarkUnsaved,
    VoidCallback setStateCallback,
  ) {
    final subject = subjects[index];
    final recapFinal = parseNum(subject['recap_final_score']);
    if (recapFinal != null) {
      final scoreStr = recapFinal == recapFinal.roundToDouble()
          ? recapFinal.toInt().toString()
          : recapFinal.toStringAsFixed(1);
      onSubjectChanged(index, 'knowledge_score', scoreStr);
      onMarkUnsaved();
      setStateCallback();
    }
  }
}
