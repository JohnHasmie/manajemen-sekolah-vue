import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';

/// Mixin for status mapping and display in AdminAttendanceDetailPage
mixin admin_detail_status_mixin on ConsumerState<AdminAttendanceDetailPage> {
  String mapStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'present';
      case 'terlambat':
        return 'late';
      case 'izin':
        return 'excused';
      case 'sakit':
        return 'sick';
      case 'alpha':
      case 'absent':
        return 'absent';
      default:
        return 'present';
    }
  }

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

  String getStatusText(String status, LanguageProvider languageProvider) {
    final normalized = status.toLowerCase();
    final textMap = _getStatusTextMap();
    final texts = textMap[normalized];
    if (texts == null) {
      return languageProvider.getTranslatedText({
        'en': 'Unknown',
        'id': 'Tidak Diketahui',
      });
    }
    return languageProvider.getTranslatedText(texts);
  }

  Map<String, Map<String, String>> _getStatusTextMap() {
    return {
      'hadir': {'en': 'Present', 'id': 'Hadir'},
      'present': {'en': 'Present', 'id': 'Hadir'},
      'izin': {'en': 'Permission', 'id': 'Izin'},
      'excused': {'en': 'Permission', 'id': 'Izin'},
      'permission': {'en': 'Permission', 'id': 'Izin'},
      'sakit': {'en': 'Sick', 'id': 'Sakit'},
      'sick': {'en': 'Sick', 'id': 'Sakit'},
      'alpha': {'en': 'Absent', 'id': 'Alpha'},
      'absent': {'en': 'Absent', 'id': 'Alpha'},
      'terlambat': {'en': 'Late', 'id': 'Terlambat'},
      'late': {'en': 'Late', 'id': 'Terlambat'},
    };
  }
}
