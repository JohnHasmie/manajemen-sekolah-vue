import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';

/// Mixin for status color and label handling in lesson plan screens.
mixin LessonPlanStatusMixin on State<LessonPlanScreen> {
  /// Gets the color for a lesson plan status.
  /// Handles all casing variants: backend may return lowercase (`approved`),
  /// title-case (`Approved`), or Indonesian (`Disetujui`).
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
        return ColorUtils.success600;
      case 'menunggu':
      case 'pending':
        return ColorUtils.warning600;
      case 'ditolak':
      case 'rejected':
        return ColorUtils.error600;
      case 'draft':
        return ColorUtils.info600;
      default:
        return ColorUtils.slate400;
    }
  }

  /// Gets the localized label for a lesson plan status.
  String getStatusLabel(String? status) {
    if (status == null || status.isEmpty) return '-';
    switch (status.toLowerCase()) {
      case 'approved':
      case 'disetujui':
        return 'Disetujui';
      case 'pending':
      case 'menunggu':
        return 'Menunggu';
      case 'draft':
        return 'Draft';
      case 'rejected':
      case 'ditolak':
        return 'Ditolak';
      default:
        return status;
    }
  }

  /// Gets the primary color for the screen.
  Color getPrimaryColor() => ColorUtils.getRoleColor('guru');

  /// Gets the card gradient for the screen header.
  LinearGradient getCardGradient() {
    final primaryColor = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }
}
