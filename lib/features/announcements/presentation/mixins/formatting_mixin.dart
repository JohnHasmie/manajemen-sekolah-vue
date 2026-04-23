import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for formatting and color utilities.
mixin FormattingMixin on ConsumerState<ParentAnnouncementScreen> {
  String get userRole;

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(userRole);
  }

  LinearGradient getCardGradient() {
    final primaryColor = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  String formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String getTargetText(
    Map<String, dynamic> announcementData,
    LanguageProvider languageProvider,
  ) {
    final roleTarget = (announcementData['role_target'] ?? 'all')
        .toString()
        .toLowerCase()
        .trim();
    final className = announcementData['kelas_nama'];

    if ((roleTarget == 'all' || roleTarget == 'semua' || roleTarget == '') &&
        className == null) {
      return languageProvider.getTranslatedText({
        'en': 'All Users',
        'id': 'Semua Pengguna',
      });
    } else if (className != null) {
      return '$className (${roleTarget.toUpperCase()})';
    } else {
      return roleTarget.toUpperCase();
    }
  }
}
