import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin for UI formatting, colors, and text utilities.
mixin AnnouncementUiMixin on ConsumerState<AdminAnnouncementScreen> {
  /// Returns the primary color for admin role.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Returns a gradient for announcement cards.
  LinearGradient getCardGradient() {
    final primaryColor = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  /// Formats a date string to dd/MM/yyyy HH:mm format.
  String formatDate(String? dateString) {
    if (dateString == null) return '-';
    final date = AppDateUtils.parseApiDate(dateString);
    if (date == null) return dateString;

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  /// Returns localized target audience text.
  String getTargetText(
    Map<String, dynamic> announcementData,
    LanguageProvider languageProvider,
  ) {
    final roleTarget = announcementData['role_target'] ?? 'all';
    final classNama = announcementData['class_name'];

    if (roleTarget == 'all' && classNama == null) {
      return languageProvider.getTranslatedText({
        'en': 'All Users',
        'id': 'Semua Pengguna',
      });
    } else if (classNama != null) {
      return '$classNama (${roleTarget.toUpperCase()})';
    } else {
      return roleTarget.toUpperCase();
    }
  }
}
