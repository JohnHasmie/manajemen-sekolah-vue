// Bottom sheet shown when an admin taps a schedule row.
//
// Why this exists
// ---------------
// `admin_schedule_management_screen.dart` was inlining a 100-line
// `_showScheduleDetail` method that built the EntityDetailSheet sections
// and meta strings from a raw schedule Map. None of that touches the
// screen's state — it only needs the AdminScheduleController (for the
// formatters) plus two callbacks (Edit / Delete) and the read-only flag
// from the AY provider.
//
// Pulling this out drops ~100 lines from the screen file and keeps
// the schedule formatting helpers in one place.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_entity_detail_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';

/// Show the read/edit/delete detail sheet for a single schedule row.
///
/// `dayList` carries the canonical list of days the screen has loaded
/// (used for label resolution); `onEdit` and `onDelete` are the screen's
/// Add/Edit-sheet opener and Delete-confirmation handlers, respectively.
void showAdminScheduleDetailSheet({
  required BuildContext context,
  required Map<String, dynamic> schedule,
  required AdminScheduleController controller,
  required LanguageProvider lang,
  required List<dynamic> dayList,
  required bool isReadOnly,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final subject = (schedule['subject_name'] ?? 'No Subject').toString();
  final teacher = (schedule['teacher_name'] ?? '-').toString();
  final className = (schedule['class_name'] ?? '-').toString();
  final dayLabel = controller.formatScheduleDays(
    schedule,
    dayList,
    lang.currentLanguage,
  );
  final timeLabel = controller.formatTime(schedule);
  final lessonHour =
      (schedule['jam_pelajaran'] ?? schedule['lesson_hour'] ?? '-').toString();
  final semester = (schedule['semester'] ?? '-').toString();
  final academicYear =
      (schedule['academic_year'] ?? schedule['academic_year_name'] ?? '-')
          .toString();

  showAdminEntityDetailSheet(
    context,
    kicker: lang.getTranslatedText(const {
      'en': 'TEACHING SESSION',
      'id': 'SESI MENGAJAR',
    }),
    title: subject,
    meta: '$dayLabel · $timeLabel',
    initials: subject,
    status: EntityStatus(
      label: '$academicYear · Sem $semester',
      color: ColorUtils.getRoleColor('admin'),
    ),
    sections: [
      EntityDetailSection(
        label: lang.getTranslatedText(const {'en': 'When', 'id': 'Waktu'}),
        rows: [
          EntityDetailRow(
            label: lang.getTranslatedText(const {'en': 'Day', 'id': 'Hari'}),
            value: dayLabel,
          ),
          EntityDetailRow(
            label: lang.getTranslatedText(const {'en': 'Time', 'id': 'Jam'}),
            value: timeLabel,
          ),
          EntityDetailRow(
            label: lang.getTranslatedText(const {
              'en': 'Lesson hour',
              'id': 'Jam pelajaran',
            }),
            value: lessonHour,
          ),
        ],
      ),
      EntityDetailSection(
        label: lang.getTranslatedText(const {
          'en': 'Assignment',
          'id': 'Penugasan',
        }),
        rows: [
          EntityDetailRow(
            label: lang.getTranslatedText(const {
              'en': 'Subject',
              'id': 'Mapel',
            }),
            value: subject,
          ),
          EntityDetailRow(
            label: lang.getTranslatedText(const {
              'en': 'Teacher',
              'id': 'Guru',
            }),
            value: teacher,
          ),
          EntityDetailRow(
            label: lang.getTranslatedText(const {'en': 'Class', 'id': 'Kelas'}),
            value: className,
          ),
        ],
      ),
    ],
    onEdit: onEdit,
    onDelete: onDelete,
    isReadOnly: isReadOnly,
  );
}
