import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';

/// Mixin for UI building methods in GradeRecapPage.
mixin GradeRecapUiMixin {
  // Abstract getters for state fields
  Map<String, dynamic>? get selectedClass;
  Map<String, dynamic>? get selectedSubject;
  int get currentStep;
  Color getPrimaryColor();
  void handleBackButton();

  Widget buildMainHeader(LanguageProvider lp) {
    return TeacherPageHeader(
      title: lp.getTranslatedText({
        'en': 'Grade Recap',
        'id': 'Rekapitulasi Nilai',
      }),
      subtitle: getHeaderSubtitle(lp),
      primaryColor: getPrimaryColor(),
      onBackPressed: handleBackButton,
    );
  }

  Widget buildDialogHeader(LanguageProvider lp) {
    return TeacherPageHeader(
      title: selectedSubject?['nama'] ?? selectedSubject?['name'] ?? 'Subject',
      subtitle: selectedClass?['nama'] ?? selectedClass?['name'] ?? 'Class',
      primaryColor: getPrimaryColor(),
      onBackPressed: handleBackButton,
      // Modal-style entry → dismiss affordance, not "navigate back".
      backIcon: Icons.close_rounded,
    );
  }

  String getHeaderSubtitle(LanguageProvider lp) {
    if (currentStep == 0) {
      return lp.getTranslatedText({'en': 'Select class', 'id': 'Pilih kelas'});
    } else if (currentStep == 1) {
      return lp.getTranslatedText({
        'en': 'Select subject',
        'id': 'Pilih mata pelajaran',
      });
    }
    return selectedSubject?['nama'] ?? selectedSubject?['name'] ?? '';
  }

  Widget buildRecapSearchBar(LanguageProvider lp) {
    return const SizedBox.shrink();
  }

  Widget buildRecapBody(LanguageProvider lp) {
    if (currentStep == 0) {
      return const SizedBox.shrink();
    }
    if (currentStep == 1) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }
}
