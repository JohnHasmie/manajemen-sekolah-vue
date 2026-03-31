// Inline edit-mode table for the Grade Book screen.
// Displays all students with score + description inputs for a single assessment.
// Like a Vue inline-editing data-table component driven by props and $emit callbacks.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Inline edit-mode table shown while a teacher edits grades for one assessment.
///
/// This is like a Vue `<InlineEditTable>` component. It owns no mutable state of
/// its own — all controllers/focus nodes are passed in from the parent so that
/// the parent can read final values when the "Finish" button is tapped.
///
/// Think of [onFinish] as `$emit('finish')` and [onSaveGrade] as
/// `$emit('save-grade', student, field, value)` in Vue terms.
///
/// Constructor params (like Vue props):
/// - [editGradeType]    — the grade type being edited (e.g. 'uh', 'uts')
/// - [editHeader]       — the assessment header: {id, date, title, is_temp}
/// - [filteredStudentList] — students currently visible after search filter
/// - [editControllers]  — TextEditingControllers keyed as "${studentId}_score"
///                         and "${studentId}_deskripsi"
/// - [editFocusNodes]   — FocusNodes with the same keys
/// - [isReadOnly]       — whether the academic year is locked (disables inputs)
/// - [primaryColor]     — role-based accent color from the parent screen
/// - [languageProvider] — i18n provider for translated labels
/// - [onSaveGrade]      — called when a field loses focus or is submitted;
///                         parent handles the actual API call
/// - [onFinish]         — called when "Finish" is tapped; parent saves all
///                         grades, reloads data, and exits edit mode
class GradeEditTableWidget extends StatelessWidget {
  final String editGradeType;
  final Map<String, dynamic> editHeader;
  final List<Student> filteredStudentList;
  final Map<String, TextEditingController> editControllers;
  final Map<String, FocusNode> editFocusNodes;
  final bool isReadOnly;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  /// Called when a single cell loses focus or is submitted.
  /// Signature: (student, field ('nilai'|'deskripsi'), value)
  final Future<void> Function(Student student, String field, String value)
  onSaveGrade;

  /// Called when the teacher taps "Finish". The parent is responsible for
  /// saving all controllers, reloading data, and clearing edit mode.
  final Future<void> Function() onFinish;

  const GradeEditTableWidget({
    super.key,
    required this.editGradeType,
    required this.editHeader,
    required this.filteredStudentList,
    required this.editControllers,
    required this.editFocusNodes,
    required this.isReadOnly,
    required this.primaryColor,
    required this.languageProvider,
    required this.onSaveGrade,
    required this.onFinish,
  });

  // ── Pure helpers (like private Vue methods with no side-effects) ─────────

  /// Converts a raw date string "YYYY-MM-DD" to display format "DD/MM/YYYY".
  String _formatDateDisplay(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  /// Returns the human-readable label for a grade type key.
  String _gradeTypeLabel(String type) {
    switch (type) {
      case 'uh':
        return languageProvider.getTranslatedText({
          'en': 'Daily/Quiz',
          'id': 'UH/Ulangan',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({
          'en': 'Final',
          'id': 'UAS',
        });
      case 'pts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm Exam',
          'id': 'PTS',
        });
      case 'pas':
        return languageProvider.getTranslatedText({
          'en': 'Final Exam',
          'id': 'PAS',
        });
      default:
        return type.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String date = editHeader['date'] ?? '';
    final String? title = editHeader['title'] as String?;
    final String displayTitle = (title != null && title.isNotEmpty)
        ? '$title (${_formatDateDisplay(date)})'
        : _formatDateDisplay(date);

    return Column(
      children: [
        // ── Edit mode banner ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: ColorUtils.warning600.withValues(alpha: 0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Mode',
                      style: TextStyle(
                        color: ColorUtils.warning600,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${_gradeTypeLabel(editGradeType)} - $displayTitle',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: ColorUtils.slate800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              ElevatedButton.icon(
                // "Finish" delegates all saving logic back to the parent via
                // [onFinish], keeping this widget free of API/setState calls.
                onPressed: onFinish,
                icon: Icon(Icons.check, size: 16),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Finish',
                    'id': 'Selesai',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable student rows ─────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                // Ensure minimum width of 600 on narrow screens
                width: MediaQuery.of(context).size.width > 600
                    ? MediaQuery.of(context).size.width
                    : 600,
                child: Column(
                  children: [
                    // ── Column header row ──────────────────────────────────
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: ColorUtils.corporateBlue600.withValues(
                          alpha: 0.05,
                        ),
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 150,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Name',
                                'id': 'Nama',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Grade',
                                'id': 'Nilai',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Description',
                                  'id': 'Deskripsi',
                                }),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── One row per student ────────────────────────────────
                    ...filteredStudentList.map((student) {
                      final scoreKey = '${student.id}_score';
                      final deskripsiKey = '${student.id}_deskripsi';

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: ColorUtils.slate200),
                          ),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            // Student name + number
                            Container(
                              width: 150,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: ColorUtils.slate900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    student.studentNumber,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ColorUtils.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Score input
                            Container(
                              width: 100,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: ColorUtils.slate200),
                                  right: BorderSide(color: ColorUtils.slate200),
                                ),
                              ),
                              child: TextFormField(
                                controller: editControllers[scoreKey],
                                focusNode: editFocusNodes[scoreKey],
                                enabled: !isReadOnly,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: ColorUtils.slate900),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '-',
                                  hintStyle: TextStyle(
                                    color: ColorUtils.slate400,
                                  ),
                                ),
                                onFieldSubmitted: (value) => onSaveGrade(
                                  student,
                                  'score',
                                  value,
                                ),
                              ),
                            ),

                            // Description input
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: TextFormField(
                                  controller: editControllers[deskripsiKey],
                                  focusNode: editFocusNodes[deskripsiKey],
                                  enabled: !isReadOnly,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: languageProvider.getTranslatedText(
                                      {
                                        'en': 'Add description...',
                                        'id': 'Tambah deskripsi...',
                                      },
                                    ),
                                    hintStyle: TextStyle(
                                      color: ColorUtils.slate400,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onFieldSubmitted: (value) => onSaveGrade(
                                    student,
                                    'deskripsi',
                                    value,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
