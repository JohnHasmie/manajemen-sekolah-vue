import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_state_mixin.dart';

/// Provides status-related utilities (normalization, colors, icons,
/// translations).
mixin ParentAttendanceStatusMixin
    on ConsumerState<ParentAttendanceScreen>, ParentAttendanceStateMixin {
  String normalizeStatus(dynamic rawStatus) {
    final String status = (rawStatus ?? 'alpha').toString().toLowerCase();

    // Map English/Mixed to standard keys
    if (status == 'present') return 'hadir';
    if (status == 'permission') return 'izin';
    if (status == 'excused') return 'izin';
    if (status == 'sick') return 'sakit';
    if (status == 'late') return 'terlambat';
    if (status == 'absent') return 'alpha';

    // Map lowercase Indonesian
    if (status == 'hadir') return 'hadir';
    if (status == 'izin') return 'izin';
    if (status == 'sakit') return 'sakit';
    if (status == 'terlambat') return 'terlambat';
    if (status == 'alpha') return 'alpha';
    if (status == 'alpa') return 'alpha';

    // Check if it's a known key
    if (monthlySummary.containsKey(status)) return status;

    return 'alpha'; // Default fallback
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'izin':
        return ColorUtils.info600;
      case 'sakit':
        return ColorUtils.warning600;
      case 'alpha':
        return ColorUtils.error600;
      case 'terlambat':
        // Wali brand azure — keeps the "terlambat" pill inside the parent
        // palette instead of borrowing the legacy corporate-blue swatch.
        return ColorUtils.brandAzure;
      default:
        return ColorUtils.success600;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'hadir':
        return Icons.check_circle_outline;
      case 'terlambat':
        return Icons.watch_later_outlined;
      case 'izin':
        return Icons.assignment_turned_in_outlined;
      case 'sakit':
        return Icons.local_hospital_outlined;
      case 'alpha':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String getTranslatedStatus(String? status) {
    if (status == null) return '-';
    final String s = status.trim();
    if (s.toLowerCase() == 'hadir') {
      return AppLocalizations.present.tr;
    }
    if (s.toLowerCase() == 'telat' || s.toLowerCase() == 'terlambat') {
      return AppLocalizations.late.tr;
    }
    if (s.toLowerCase() == 'izin') {
      return AppLocalizations.permission.tr;
    }
    if (s.toLowerCase() == 'sakit') {
      return AppLocalizations.sick.tr;
    }
    if (s.toLowerCase() == 'alpha') {
      return AppLocalizations.alpha.tr;
    }
    return status;
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('wali');
  }

  /// Card gradient — returns the canonical wali brand gradient so any
  /// consumer wired in later gets the brand-aligned two-stop azure rather
  /// than the previous single-color alpha fade.
  LinearGradient getCardGradient() => ColorUtils.brandGradient('wali');
}
