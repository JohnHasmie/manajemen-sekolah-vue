/// Student row for attendance input with two display modes:
/// - compact:     single row  [name + NIS ── Hadir | Telat | Sakit | Izin | Alpa]
///                Frame A from `_design/teacher_attendance_detail_mockup.html` —
///                full-word buttons at ≈40dp tall · thumb-friendly.
/// - descriptive: two rows    [# avatar name ── badge]
///                            [Hadir] [Terlambat] [Sakit] [Izin] [Alpha]
library;

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/mixins/attendance_helpers_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/mixins/compact_builder_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/mixins/descriptive_builder_mixin.dart';

/// Main attendance student item widget.
///
/// Composes UI builders through mixins:
/// - AttendanceHelpersMixin: Status color and text helpers
/// - CompactBuilderMixin: Single-row layout
/// - DescriptiveBuilderMixin: Two-row layout with avatar
class AttendanceStudentItem extends StatelessWidget
    with AttendanceHelpersMixin, CompactBuilderMixin, DescriptiveBuilderMixin {
  @override
  final Student student;
  @override
  final String currentStatus;
  @override
  final void Function(String studentId, String status) onStatusChanged;
  @override
  final LanguageProvider languageProvider;
  @override
  final int index;
  final bool compactMode;

  const AttendanceStudentItem({
    super.key,
    required this.student,
    required this.currentStatus,
    required this.onStatusChanged,
    required this.languageProvider,
    this.index = 0,
    this.compactMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return compactMode ? buildCompactLayout(context) : buildDescriptiveLayout();
  }
}
