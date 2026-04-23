import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';

/// Mixin for status-related helpers in teacher attendance detail.
mixin TeacherAttendanceDetailStatusMixin
    on ConsumerState<TeacherAttendanceDetailPage> {
  /// Get student's attendance status from state
  String getStudentStatus(String studentId, TeacherAttendanceState state) {
    return state.editedStatus[studentId] ?? 'absent';
  }

  /// Get icon for attendance status
  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return Icons.check_circle_rounded;
      case 'terlambat':
      case 'late':
        return Icons.access_time_filled_rounded;
      case 'sakit':
      case 'sick':
        return Icons.medication_rounded;
      case 'izin':
      case 'excused':
      case 'permission':
        return Icons.assignment_turned_in_rounded;
      case 'alpha':
      case 'absent':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  /// Get color for attendance status
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return ColorUtils.success600;
      case 'izin':
      case 'excused':
      case 'permission':
        return ColorUtils.info600;
      case 'sakit':
      case 'sick':
        return ColorUtils.warning600;
      case 'alpha':
      case 'absent':
        return ColorUtils.error600;
      case 'terlambat':
      case 'late':
        return ColorUtils.violet700;
      default:
        return ColorUtils.slate400;
    }
  }

  /// Get localized text for status
  String getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'sakit':
      case 'sick':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'izin':
      case 'excused':
      case 'permission':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'alpha':
      case 'absent':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      case 'terlambat':
      case 'late':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }

  /// Get primary color for teacher role
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }
}
