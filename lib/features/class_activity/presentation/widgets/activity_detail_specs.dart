// Visual spec lookups shared by the teacher activity-detail widgets.
//
// Extracted verbatim from `_TeacherActivityDetailScreenState` so the
// type pill, the KPI strip, and the Daftar Siswa rows all resolve their
// colors/labels/icons from one place. Behavior is identical — these are
// the same `switch` tables that previously lived inline on the State.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Icon + tint + foreground + label for an activity type chip
/// (Tugas / Ujian / Catatan / Aktivitas).
class ActivityTypeSpec {
  final IconData icon;
  final Color tint;
  final Color fg;
  final String label;
  const ActivityTypeSpec({
    required this.icon,
    required this.tint,
    required this.fg,
    required this.label,
  });
}

/// Visual spec for a submission status pill (Sudah / Belum / Telat / Izin)
/// in the Daftar Siswa preview rows.
class ActivityStatusSpec {
  final String label;
  final Color tint;
  final Color fg;
  const ActivityStatusSpec({
    required this.label,
    required this.tint,
    required this.fg,
  });
}

/// Resolve the [ActivityTypeSpec] for a lower-cased activity `type`.
ActivityTypeSpec activityTypeSpec(String type) {
  switch (type) {
    case 'tugas':
    case 'assignment':
      return ActivityTypeSpec(
        icon: Icons.assignment_turned_in_rounded,
        tint: const Color(0xFFDBEAFE),
        fg: ColorUtils.info600,
        label: kClaActTypeAssignment.tr,
      );
    case 'ujian':
    case 'exam':
    case 'kuis':
    case 'quiz':
      return ActivityTypeSpec(
        icon: Icons.science_rounded,
        tint: const Color(0xFFFEF3C7),
        fg: ColorUtils.warning600,
        label: kClaActTypeExam.tr,
      );
    case 'catatan':
    case 'note':
      return ActivityTypeSpec(
        icon: Icons.sticky_note_2_rounded,
        tint: ColorUtils.slate100,
        fg: ColorUtils.slate600,
        label: kClaActTypeNote.tr,
      );
    case 'aktivitas':
    case 'activity':
    default:
      return ActivityTypeSpec(
        icon: Icons.groups_2_rounded,
        tint: const Color(0xFFEDE9FE),
        fg: ColorUtils.violet700,
        label: kClaActTypeActivity.tr,
      );
  }
}

/// Resolve the [ActivityStatusSpec] for a submission `status` string.
ActivityStatusSpec activityStatusSpec(String s) {
  switch (s) {
    case 'submitted':
      return ActivityStatusSpec(
        label: kClaActStatusSubmitted.tr,
        tint: ColorUtils.success600.withValues(alpha: 0.12),
        fg: ColorUtils.success600,
      );
    case 'late':
      return ActivityStatusSpec(
        label: kClaActStatusLate.tr,
        tint: ColorUtils.warning600.withValues(alpha: 0.14),
        fg: ColorUtils.warning600,
      );
    case 'excused':
      return ActivityStatusSpec(
        label: kClaActStatusExcused.tr,
        tint: ColorUtils.info600.withValues(alpha: 0.12),
        fg: ColorUtils.info600,
      );
    case 'pending':
    default:
      return ActivityStatusSpec(
        label: kClaActStatusPending.tr,
        tint: ColorUtils.slate100,
        fg: ColorUtils.slate700,
      );
  }
}
