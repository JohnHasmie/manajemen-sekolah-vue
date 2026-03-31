// RPP metadata header card. Extracted from lesson_plan_detail_screen.dart.
// Shows the RPP title and key metadata rows (subject, class, semester, etc.).
// Like a `<RppHeaderCard>` Vue component — purely display, no interaction.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Displays the RPP title and a metadata table (mata pelajaran, kelas, etc.).
///
/// Constructor params:
/// - [lessonPlanData] — the raw RPP map; this widget reads display fields only
/// - [primaryColor]   — brand colour for the title text and card shadow
class LessonPlanHeaderInfoCard extends StatelessWidget {
  final Map<String, dynamic> lessonPlanData;
  final Color primaryColor;

  const LessonPlanHeaderInfoCard({
    super.key,
    required this.lessonPlanData,
    required this.primaryColor,
  });

  /// Helper that returns the first non-empty value found in [keys].
  /// Like Laravel's `$rpp->title ?? $rpp->judul ?? ''`.
  String _getField(List<String> keys, {String defaultValue = ''}) {
    for (final key in keys) {
      final value = lessonPlanData[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final title = _getField(['judul', 'title'], defaultValue: 'RPP');
    final subjectName = _getField(['mata_pelajaran_nama', 'subject_name']);
    final className = _getField(['kelas_nama', 'class_name']);
    final semester = _getField(['semester']);
    final academicYear = _getField(['tahun_ajaran', 'academic_year']);
    final teacherName = _getField(['guru_nama', 'teacher_name']);
    final status = _getField(['status']);

    final infoItems = <MapEntry<String, String>>[
      if (subjectName.isNotEmpty) MapEntry('Mata Pelajaran', subjectName),
      if (className.isNotEmpty) MapEntry('Kelas', className),
      if (semester.isNotEmpty) MapEntry('Semester', semester),
      if (academicYear.isNotEmpty) MapEntry('Tahun Ajaran', academicYear),
      if (teacherName.isNotEmpty) MapEntry('Guru', teacherName),
      if (status.isNotEmpty) MapEntry('Status', status),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RENCANA PELAKSANAAN PEMBELAJARAN (RPP)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate800,
              ),
            ),
            if (infoItems.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ...infoItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          item.key,
                          style: TextStyle(
                            fontSize: 13,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ),
                      Text(
                        ': ',
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.value,
                          style: TextStyle(
                            fontSize: 13,
                            color: ColorUtils.slate700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
