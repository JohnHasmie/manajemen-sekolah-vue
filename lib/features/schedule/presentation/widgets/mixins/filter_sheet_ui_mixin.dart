// Mixin to build UI sections for the schedule filter sheet.
// Provides header, content layout, and footer widgets.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

/// Mixin providing UI builder methods for schedule filter sheet layout.
mixin FilterSheetUiMixin {
  // Required from State.
  BuildContext get context;
  // Stub for callback access - derived classes override.
  void onResetSelections() {}

  // Stubs for chip builders - derived classes mix in chip builder mixin.
  Widget buildDayChips(dynamic languageProvider) => const SizedBox.shrink();
  Widget buildClassChips() => const SizedBox.shrink();
  Widget buildTeacherChips(dynamic languageProvider) => const SizedBox.shrink();
  Widget buildSubjectChips(dynamic languageProvider) => const SizedBox.shrink();
  Widget buildTermChips() => const SizedBox.shrink();
  Widget buildLessonHourChips() => const SizedBox.shrink();

  /// Scrollable content with teacher, subject, day, class, and lesson-hour
  /// chips.
  ///
  /// Academic year + semester sit in the global app shell picker — not
  /// here — so this sheet only edits the five dimensions the admin
  /// can override per-table-view: guru, mapel, hari, kelas, jam
  /// pelajaran. Guru + Mapel were added in Fix-1a so admin can scope
  /// per-teacher / per-subject listings (e.g. before printing).
  Widget buildFilterContent(dynamic languageProvider, Color primaryColor) {
    return TeacherFilterContent(
      sections: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Teacher',
                'id': 'Guru',
              }),
              icon: Icons.person_outline_rounded,
              primaryColor: primaryColor,
            ),
            buildTeacherChips(languageProvider),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Subject',
                'id': 'Mata Pelajaran',
              }),
              icon: Icons.menu_book_outlined,
              primaryColor: primaryColor,
            ),
            buildSubjectChips(languageProvider),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Day',
                'id': 'Hari',
              }),
              icon: Icons.calendar_today_rounded,
              primaryColor: primaryColor,
            ),
            buildDayChips(languageProvider),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Class',
                'id': 'Kelas',
              }),
              icon: Icons.class_outlined,
              primaryColor: primaryColor,
            ),
            buildClassChips(),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Lesson Hour',
                'id': 'Jam Pelajaran',
              }),
              icon: Icons.schedule_rounded,
              primaryColor: primaryColor,
            ),
            buildLessonHourChips(),
          ],
        ),
      ],
    );
  }
}
