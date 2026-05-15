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
  Widget buildTermChips() => const SizedBox.shrink();
  Widget buildLessonHourChips() => const SizedBox.shrink();

  /// Scrollable content with period, day, class, and lesson chips.
  ///
  /// Order matches the hub's brand chip strip — Periode (Semester) ·
  /// Hari · Kelas · Jam — so the admin sees the same dimensions in the
  /// same sequence as the entry surface. Academic year sits in the
  /// global app shell picker (not here) — the header subtitle on the
  /// sheet surfaces the active year for context.
  Widget buildFilterContent(dynamic languageProvider, Color primaryColor) {
    return TeacherFilterContent(
      sections: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: languageProvider.getTranslatedText({
                'en': 'Period (Semester)',
                'id': 'Periode (Semester)',
              }),
              icon: Icons.event_note_rounded,
              primaryColor: primaryColor,
            ),
            buildTermChips(),
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
