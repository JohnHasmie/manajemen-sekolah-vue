// Extracted from teacher_attendance_screen.dart (_buildInputMode, form section).
// Like a Vue `<AttendanceInputForm>` component -- the card at the top of the
// "Add Attendance" tab that lets the teacher pick date, lesson hour, class,
// and subject, plus toggle an inline student search and quick-fill buttons.
//
// Stateless: all mutable values are passed down as props and every user
// interaction fires a callback so the parent (AttendancePage) keeps the
// single source of truth.  In Laravel terms this is a Blade partial.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// The top form card in the attendance input tab.
///
/// Parameters (like Vue props / emits):
/// - [selectedDate]           -- currently selected attendance date
/// - [selectedLessonHourId]   -- id of the selected lesson hour, or null
/// - [lessonHours]            -- all available lesson hour objects
/// - [selectedClassId]        -- id of the selected class, or null
/// - [classList]              -- all classes the teacher is assigned to
/// - [selectedSubjectId]      -- id of the selected subject, or null
/// - [subjectTeacher]         -- subjects available for the selected class
/// - [showSearch]             -- whether the inline student-search field is visible
/// - [searchController]       -- TextEditingController for the student-search field
/// - [primaryColor]           -- role-based accent colour
/// - [languageProvider]       -- for translating UI strings
/// - [onDatePicked]           -- called with the new date after the date picker closes
/// - [onLessonHourChanged]    -- called when lesson-hour dropdown changes
/// - [onClassChanged]         -- called when class dropdown changes
/// - [onSubjectChanged]       -- called when subject dropdown changes
/// - [onSearchChanged]        -- called on every keystroke in the student search field
/// - [onSearchClosed]         -- called when the X button in the search field is tapped
/// - [onSearchToggled]        -- called when the search icon button is tapped to open search
/// - [onQuickActionsPressed]  -- called when the bulk-fill (checklist) button is tapped
class AttendanceInputForm extends StatelessWidget {
  final DateTime selectedDate;
  final String? selectedLessonHourId;
  final List<dynamic> lessonHours;
  final String? selectedClassId;
  final List<dynamic> classList;
  final String? selectedSubjectId;
  final List<dynamic> subjectTeacher;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  final void Function(DateTime picked) onDatePicked;
  final void Function(String? value) onLessonHourChanged;
  final void Function(String? value) onClassChanged;
  final void Function(String? value) onSubjectChanged;
  final VoidCallback onQuickActionsPressed;

  final bool embedded;
  final String? initialClassName;
  final String? initialSubjectName;
  final int? initialLessonHourNumber;

  const AttendanceInputForm({
    super.key,
    required this.selectedDate,
    required this.selectedLessonHourId,
    required this.lessonHours,
    required this.selectedClassId,
    required this.classList,
    required this.selectedSubjectId,
    required this.subjectTeacher,
    required this.primaryColor,
    required this.languageProvider,
    required this.onDatePicked,
    required this.onLessonHourChanged,
    required this.onClassChanged,
    required this.onSubjectChanged,
    required this.onQuickActionsPressed,
    this.embedded = false,
    this.initialClassName,
    this.initialSubjectName,
    this.initialLessonHourNumber,
  });

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      final dateStr = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(selectedDate);

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Column(
          children: [
            // Info row
            Row(
              children: [
                // Subject + class
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.menu_book_rounded, size: 16, color: primaryColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              initialSubjectName ?? '-',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate800),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Kelas: ${initialClassName ?? '-'} · Jam ke-${initialLessonHourNumber ?? '-'}',
                              style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Date
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: ColorUtils.slate500),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: ColorUtils.slate600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Date picker + Lesson Hour dropdown ──────────────────
          Row(
            children: [
              // Date picker trigger
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) onDatePicked(picked);
                  },
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate50,
                      border: Border.all(color: ColorUtils.slate200),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            DateFormat('EEE, dd MMM yyyy', 'id_ID')
                                .format(selectedDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: ColorUtils.slate800,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Lesson Hour dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    border: Border.all(color: ColorUtils.slate200),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLessonHourId,
                      isExpanded: true,
                      hint: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Hour',
                          'id': 'Jam',
                        }),
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: ColorUtils.slate600,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorUtils.slate800,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Select Hour',
                              'id': 'Pilih Jam',
                            }),
                            style:
                                TextStyle(color: ColorUtils.slate500),
                          ),
                        ),
                        ...lessonHours.map(
                          (lh) => DropdownMenuItem<String>(
                            value: lh['id']?.toString(),
                            child: Text(
                              '${lh['name']} (${lh['start_time']} - ${lh['end_time']})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onLessonHourChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Row 2: Class dropdown + Subject dropdown ────────────────────
          Row(
            children: [
              // Class dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    border: Border.all(color: ColorUtils.slate200),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedClassId,
                      isExpanded: true,
                      hint: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Class',
                          'id': 'Kelas',
                        }),
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: ColorUtils.slate600,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorUtils.slate800,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Select Class',
                              'id': 'Pilih Kelas',
                            }),
                            style:
                                TextStyle(color: ColorUtils.slate500),
                          ),
                        ),
                        ...classList.map(
                          (classItem) => DropdownMenuItem<String>(
                            value: classItem['id'],
                            child: Text(classItem['name'] ?? ''),
                          ),
                        ),
                      ],
                      onChanged: onClassChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Subject dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    border: Border.all(color: ColorUtils.slate200),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSubjectId,
                      isExpanded: true,
                      hint: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Subject',
                          'id': 'Mapel',
                        }),
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: ColorUtils.slate600,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorUtils.slate800,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Select Subject',
                              'id': 'Pilih Mapel',
                            }),
                            style:
                                TextStyle(color: ColorUtils.slate500),
                          ),
                        ),
                        ...subjectTeacher.map(
                          (mp) => DropdownMenuItem<String>(
                            value: mp['id'],
                            child: Text(
                              mp['nama'] ??
                                  mp['name'] ??
                                  mp['mata_pelajaran_nama'] ??
                                  'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onSubjectChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Warning when the selected class has no assigned subjects
          if (subjectTeacher.isEmpty && selectedClassId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'No subjects assigned for this class.',
                  'id': 'Tidak ada mata pelajaran untuk kelas ini.',
                }),
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),

          const SizedBox(height: AppSpacing.md),

          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
