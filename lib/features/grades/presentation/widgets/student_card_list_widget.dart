import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Matches a v4/v7 UUID anywhere in a string. Used to detect and strip raw
/// UUIDs that some legacy seeded data accidentally stored inside assessment
/// titles (e.g. "UH - 019d9a76-337f-72f6-a298-74df9906ee3a"). Those titles
/// both look like garbage to teachers and blow past the row width.
final _uuidRegex = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

/// Returns a display-safe assessment title.
///
/// Strips any embedded UUID and collapses leftover separators ("- ", " -"),
/// so "UH - 019d9a76-..." becomes "UH" and "Judul Asli - <uuid>" becomes
/// "Judul Asli". If the title collapses to an empty string (e.g. the title
/// was *just* a UUID), returns empty — callers fall back to the type label.
String _sanitizeTitle(String rawTitle) {
  final stripped = rawTitle.replaceAll(_uuidRegex, '').trim();
  // Drop trailing/leading " - " that's left behind after stripping.
  return stripped
      .replaceAll(RegExp(r'^[\s\-–—]+'), '')
      .replaceAll(RegExp(r'[\s\-–—]+$'), '')
      .trim();
}

/// Displays student list as expandable cards (mobile-friendly grade view).
/// Extracted from GradeBookPageState to reduce its size.
class StudentCardListWidget extends StatelessWidget {
  final List<Student> filteredStudentList;
  final List<Map<String, dynamic>> gradeList;
  final Set<String> expandedStudents;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final bool canEdit;
  final bool isReadOnly;
  final Function(Student, Map<String, dynamic>) onStudentGradeTap;
  final Function(String) onStudentToggled;
  final Color Function(double) scoreColor;
  final String Function(String) shortTypeLabel;
  final String Function(dynamic) formatScore;
  final String Function(String, LanguageProvider) getGradeTypeLabel;
  final Map<String, List<Map<String, dynamic>>> assessmentHeaders;

  const StudentCardListWidget({
    super.key,
    required this.filteredStudentList,
    required this.gradeList,
    required this.expandedStudents,
    required this.primaryColor,
    required this.languageProvider,
    required this.canEdit,
    required this.isReadOnly,
    required this.onStudentGradeTap,
    required this.onStudentToggled,
    required this.scoreColor,
    required this.shortTypeLabel,
    required this.formatScore,
    required this.getGradeTypeLabel,
    required this.assessmentHeaders,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      itemCount: filteredStudentList.length,
      itemBuilder: (context, index) {
        final student = filteredStudentList[index];
        final isExpanded = expandedStudents.contains(student.id);

        // Gather all grades for this student
        final studentGrades = gradeList.where((g) {
          final gStudentId =
              (g['siswa_id'] ?? g['student_id'] ?? g['student_class_id'])
                  ?.toString();
          return gStudentId == student.id ||
              gStudentId == student.studentClassId;
        }).toList();

        // Calculate average
        final scores = studentGrades
            .map((g) => g['score'])
            .whereType<num>()
            .toList();
        final avg = scores.isNotEmpty
            ? scores.reduce((a, b) => a + b) / scores.length
            : null;

        // Group by type for expanded view
        final byType = <String, List<Map<String, dynamic>>>{};
        for (final g in studentGrades) {
          final type = (g['jenis'] ?? g['type'] ?? '').toString();
          byType.putIfAbsent(type, () => []).add(g);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpanded
                  ? primaryColor.withValues(alpha: 0.2)
                  : ColorUtils.slate100,
            ),
          ),
          child: Column(
            children: [
              // Student header — always visible
              InkWell(
                onTap: () => onStudentToggled(student.id),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      // Index
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ColorUtils.slate100,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ColorUtils.slate800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (student.studentNumber.isNotEmpty)
                              Text(
                                student.studentNumber,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ColorUtils.slate400,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Average score
                      if (avg != null) ...[
                        Text(
                          avg.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scoreColor(avg.toDouble()),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: ColorUtils.slate400,
                      ),
                    ],
                  ),
                ),
              ),

              // Grade chips (collapsed preview)
              if (!isExpanded && studentGrades.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(52, 0, 14, 10),
                  child: SizedBox(
                    height: 26,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: studentGrades.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (_, i) {
                        final g = studentGrades[i];
                        final score = g['score'];
                        final type = shortTypeLabel(
                          (g['jenis'] ?? g['type'] ?? '').toString(),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: score != null
                                ? scoreColor(
                                    (score as num).toDouble(),
                                  ).withValues(alpha: 0.08)
                                : ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: score != null
                                  ? scoreColor(
                                      score.toDouble(),
                                    ).withValues(alpha: 0.2)
                                  : ColorUtils.slate200,
                            ),
                          ),
                          child: Text(
                            score != null
                                ? '$type ${formatScore(score)}'
                                : '$type -',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: score != null
                                  ? scoreColor(score.toDouble())
                                  : ColorUtils.slate400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Expanded: full breakdown by type
              if (isExpanded) ...[
                Divider(height: 1, color: ColorUtils.slate100),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...byType.entries.map((entry) {
                        final typeLabel = getGradeTypeLabel(
                          entry.key,
                          languageProvider,
                        );
                        final grades = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 4),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            ...grades.map((g) {
                              final score = g['score'];
                              final rawTitle = g['title']?.toString() ?? '';
                              // Strip embedded UUIDs from legacy bad-data
                              // titles like "UH - 019d9a76-..." so the row
                              // reads as "UH" instead of a scary hex blob.
                              final cleanTitle = _sanitizeTitle(rawTitle);
                              final displayTitle = cleanTitle.isNotEmpty
                                  ? cleanTitle
                                  : typeLabel;
                              final date =
                                  g['tanggal']?.toString().split('T').first ??
                                  '';
                              final dateFormatted = date.length >= 10
                                  ? '${date.substring(8, 10)}/${date.substring(5, 7)}'
                                  : date;

                              return InkWell(
                                onTap: () {
                                  final assessmentId = g['assessment_id']
                                      ?.toString();
                                  final type = (g['jenis'] ?? g['type'] ?? '')
                                      .toString();
                                  final headers = assessmentHeaders[type] ?? [];
                                  final matchedHeader = headers.firstWhere(
                                    (h) => h['id']?.toString() == assessmentId,
                                    orElse: () => <String, dynamic>{
                                      'id': assessmentId,
                                      'date': date,
                                      // Keep the ORIGINAL (unsanitized) title
                                      // in the header payload so any dialog
                                      // that needs the raw value still has
                                      // it — display-layer sanitization is
                                      // done just above.
                                      'title': rawTitle,
                                    },
                                  );
                                  // Always attach `type` to the header. The
                                  // grade book's assessmentHeaders map is
                                  // keyed BY type, so individual header rows
                                  // never carry the type themselves — but
                                  // downstream (grade_book_screen →
                                  // openInputForm) reads `h['type']` to
                                  // decide which grade type to open for
                                  // edit. Without this, tapping a UTS row
                                  // would silently open as "uh" (the
                                  // fallback), skip the existing-grade
                                  // lookup, and POST a brand-new UH row
                                  // instead of updating the UTS — which is
                                  // why the score on screen never changed.
                                  final header = {
                                    ...matchedHeader,
                                    'type': type,
                                  };
                                  onStudentGradeTap(student, header);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      // Wrap title+date in Expanded so long
                                      // strings get ellipsized instead of
                                      // overflowing the row width. Before
                                      // this, the inner Row had children
                                      // with intrinsic widths that summed
                                      // past the parent, producing the
                                      // yellow-and-black "OVERFLOWED BY N
                                      // PIXELS" warning.
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayTitle,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: ColorUtils.slate700,
                                                ),
                                              ),
                                            ),
                                            if (dateFormatted.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '($dateFormatted)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: ColorUtils.slate400,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        score != null
                                            ? formatScore(score)
                                            : '-',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: score != null
                                              ? scoreColor(
                                                  (score as num).toDouble(),
                                                )
                                              : ColorUtils.slate400,
                                        ),
                                      ),
                                      if (canEdit && !isReadOnly) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 12,
                                          color: ColorUtils.slate300,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                      if (studentGrades.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'No grades yet',
                              'id': 'Belum ada nilai',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
