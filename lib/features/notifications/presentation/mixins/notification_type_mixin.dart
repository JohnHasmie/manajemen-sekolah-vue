import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for notification type-based styling and icons.
mixin NotificationTypeMixin {
  Color getColor(String type) {
    switch (type) {
      case 'bill':
      case 'tagihan':
        return ColorUtils.success600;
      case 'announcement':
      case 'pengumuman':
        return ColorUtils.corporateBlue600;
      case 'class_activity':
      case 'activity':
        return ColorUtils.warning600;
      case 'reminder_teaching':
        return ColorUtils.violet700;
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return const Color(0xFF0D9488);
      default:
        return ColorUtils.slate500;
    }
  }

  IconData getIcon(String type) {
    switch (type) {
      case 'bill':
      case 'tagihan':
        return Icons.receipt_long_rounded;
      case 'announcement':
      case 'pengumuman':
        return Icons.campaign_rounded;
      case 'class_activity':
      case 'activity':
        return Icons.assignment_rounded;
      case 'reminder_teaching':
        return Icons.class_rounded;
      case 'grade':
      case 'nilai':
      case 'exam_score':
        return Icons.grade_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
