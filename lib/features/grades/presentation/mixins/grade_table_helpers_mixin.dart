import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_table_widget.dart';

mixin GradeTableHelpersMixin on State<GradeTableWidget> {
  /// Converts grade type to short label (UH, Tgs, UTS, UAS, PTS, PAS)
  String short(String type) {
    const m = {
      'uh': 'UH',
      'tugas': 'Tgs',
      'uts': 'UTS',
      'uas': 'UAS',
      'pts': 'PTS',
      'pas': 'PAS',
    };
    return m[type] ?? type.toUpperCase();
  }

  /// Returns color based on score threshold
  Color scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  /// Formats numeric value for display
  String fmt(dynamic v) {
    if (v == null) return '';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
  }

  /// Generates unique key for a cell
  String cellKey(Student s, String type, int idx) => '${s.id}__${type}__$idx';
}
