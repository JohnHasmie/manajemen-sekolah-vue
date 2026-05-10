/// Student row for attendance input — compact single-row layout:
///
///   `[name + NIS ── Hadir | Sakit | Izin | Alpa]`
///
/// Frame A from `_design/teacher_attendance_detail_mockup.html` —
/// full-word buttons at ≈40dp tall, thumb-friendly. The descriptive
/// two-row variant was retired together with the in-header density
/// toggle; this widget now ships a single canonical layout.
library;

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/mixins/attendance_helpers_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/mixins/compact_builder_mixin.dart';

/// Main attendance student item widget.
///
/// Composes UI builders through mixins:
/// - AttendanceHelpersMixin: Status color and text helpers
/// - CompactBuilderMixin: Single-row layout
class AttendanceStudentItem extends StatelessWidget
    with AttendanceHelpersMixin, CompactBuilderMixin {
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

  const AttendanceStudentItem({
    super.key,
    required this.student,
    required this.currentStatus,
    required this.onStatusChanged,
    required this.languageProvider,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return buildCompactLayout(context);
  }
}
