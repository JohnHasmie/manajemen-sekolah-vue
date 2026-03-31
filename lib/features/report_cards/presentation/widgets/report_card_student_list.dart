// Scrollable student list for the teacher report card screen.
// Replaces _buildStudentList() from teacher_report_card_screen.dart.
// Like a Vue <StudentList> component that emits 'tap-student' and 'download-pdf'.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_detail_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_status_badge.dart';

/// Renders a [ListView] of students with their raport status badges.
///
/// All data arrives as constructor params (like Vue props). Navigation and PDF
/// download are surfaced via callbacks so the parent owns side-effects —
/// analogous to Vue's `$emit` pattern.
class ReportCardStudentList extends StatelessWidget {
  /// Flat list of student maps returned by [ApiReportCardService.getRaports].
  final List<dynamic> students;

  /// Currently selected class — used for the detail screen title.
  final Map<String, dynamic>? selectedClass;

  /// Fired when the user taps the PDF icon for a student.
  /// Parent handles permission checks + download logic.
  final void Function(Map<String, dynamic> student) onDownloadPdf;

  /// Fired after returning from [ReportCardDetailScreen] so the parent can
  /// trigger a fresh student reload — like Vue's `@close="reload"`.
  final VoidCallback onReturnFromDetail;

  const ReportCardStudentList({
    super.key,
    required this.students,
    required this.selectedClass,
    required this.onDownloadPdf,
    required this.onReturnFromDetail,
  });

  @override
  Widget build(BuildContext context) {
    // Empty state — mirrors Vue's v-if / v-else template pattern.
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tidak ada data siswa',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        // NOTE: 'has_raport' is a JSON key from the API (ApiReportCardService.getRaports);
        // the local variable is kept as hasReportCard.
        final bool hasReportCard = student['has_raport'] ?? false;
        final String status = student['raport_status'] ?? 'Belum ada';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            boxShadow: ColorUtils.corporateShadow(),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Navigate to detail, then tell parent to refresh — like
                // Vue's router.push(...).then(() => this.$emit('return'))
                AppNavigator.push(
                  context,
                  ReportCardDetailScreen(
                    studentClassId: student['student_class_id'].toString(),
                    studentName: student['student_name'] ?? 'Siswa',
                    className: selectedClass?['name'] ?? '',
                  ),
                ).then((_) => onReturnFromDetail());
              },
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: ColorUtils.slate50,
                      child: Text(
                        (student['student_name'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['student_name'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: ColorUtils.slate800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'NIS: ${student['student_number'] ?? '-'}',
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ReportCardStatusBadge(
                      hasReportCard: hasReportCard,
                      status: status,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (status.toLowerCase() == 'final' ||
                        status.toLowerCase() == 'published')
                      IconButton(
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                        tooltip: 'Cetak PDF',
                        // Delegate to parent — like Vue $emit('download-pdf', student)
                        onPressed: () => onDownloadPdf(student),
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.chevron_right, color: ColorUtils.slate400),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
