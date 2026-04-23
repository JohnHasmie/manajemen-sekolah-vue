import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin for build-related color and header construction logic.
mixin BuildHelperMixin {
  bool get showTeacherList;
  String? get selectedTeacherId;
  String? get selectedTeacherName;

  Color getPrimaryColor() => ColorUtils.getRoleColor('admin');

  LinearGradient getGradient() {
    final p = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [p, p.withValues(alpha: 0.8)],
    );
  }

  String buildHeaderTitle(LanguageProvider lp) {
    if (showTeacherList) {
      return lp.getTranslatedText({'en': 'Select Teacher', 'id': 'Pilih Guru'});
    }
    if (selectedTeacherId != null) {
      return 'RPP - $selectedTeacherName';
    }
    return lp.getTranslatedText({'en': 'Manage RPP', 'id': 'Kelola RPP'});
  }

  String? buildHeaderSubtitle(LanguageProvider lp) {
    if (showTeacherList) {
      return lp.getTranslatedText({
        'en': 'Select a teacher to view RPP',
        'id': 'Pilih guru untuk melihat RPP',
      });
    }
    if (selectedTeacherId == null) {
      return lp.getTranslatedText({
        'en': 'Manage lesson plans',
        'id': 'Kelola rencana pelaksanaan pembelajaran',
      });
    }
    return null;
  }
}
