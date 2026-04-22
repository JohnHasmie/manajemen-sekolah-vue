import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_table_widget.dart';

/// Column definition for grade table columns.
class ColDef {
  final String type;
  final int index;
  final Map<String, dynamic> header;
  final bool isPlaceholder;
  const ColDef({
    required this.type,
    required this.index,
    required this.header,
    this.isPlaceholder = false,
  });
}

mixin GradeTableLogicMixin on State<GradeTableWidget> {
  static const double cellW = 54;
  static const double nameW = 120;

  /// Retrieves grade record matching student, type, and header criteria
  Map<String, dynamic>? getGrade(
    Student student,
    String type,
    Map<String, dynamic> header,
  ) {
    try {
      final sid = student.id.toString();
      final scid = student.studentClassId?.toString();
      final result = widget.gradeList.firstWhere((g) {
        final gSid = g['siswa_id']?.toString();
        final gScid = g['student_class_id']?.toString();
        bool match = gSid == sid;
        if (!match && (scid != null || gScid != null)) {
          match = gScid == scid || gSid == scid;
        }
        if (!match) return false;
        final hId = header['id']?.toString();
        final aId = g['assessment_id']?.toString();
        if (hId != null && aId != null) {
          if (hId != aId) return false;
        } else if (hId != null || aId != null) {
          return false;
        }
        return (g['jenis']?.toString().toLowerCase() == type.toLowerCase()) &&
            (g['tanggal']?.toString().split('T')[0] == header['date']) &&
            ((g['title'] ?? '').toString().trim() ==
                (header['title'] ?? '').toString().trim());
      }, orElse: () => <String, dynamic>{});
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  /// Builds list of column definitions for available width
  List<ColDef> buildColumns(double availableWidth) {
    final cols = <ColDef>[];

    for (final type in widget.filteredGradeTypeList) {
      final headers = widget.assessmentHeaders[type] ?? [];
      for (int i = 0; i < headers.length; i++) {
        cols.add(
          ColDef(
            type: type,
            index: i,
            header: headers[i],
            isPlaceholder: false,
          ),
        );
      }
    }

    for (final type in widget.filteredGradeTypeList) {
      final headers = widget.assessmentHeaders[type] ?? [];
      if (headers.isEmpty) {
        cols.add(
          ColDef(type: type, index: 0, header: const {}, isPlaceholder: true),
        );
      }
    }

    final usedWidth = cols.length * cellW;
    final remaining = availableWidth - usedWidth;
    if (remaining > cellW) {
      final extraCols = (remaining / cellW).floor();
      for (int i = 0; i < extraCols; i++) {
        cols.add(
          ColDef(type: '', index: i, header: const {}, isPlaceholder: true),
        );
      }
    }

    return cols;
  }
}
