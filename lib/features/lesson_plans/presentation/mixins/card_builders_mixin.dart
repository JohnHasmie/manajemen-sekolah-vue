import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/status_badge.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

mixin CardBuildersMixin on State<LessonPlanAdminDetailPage> {
  late Map<String, dynamic> lessonPlan;

  LessonPlan get _lp => LessonPlan.fromJson(lessonPlan);

  Widget buildStatusCard() {
    final model = _lp;
    final statusColor = getStatusColor(model.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.title.isNotEmpty ? model.title : '-',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(height: 10),
          buildStatusBadge(statusColor),
        ],
      ),
    );
  }

  Widget buildStatusBadge(Color statusColor) {
    return StatusBadge(
      label: getStatusLabelDetail(_lp.status),
      color: statusColor,
      fontSize: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    );
  }

  Widget buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildInfoTitle(),
          const SizedBox(height: AppSpacing.md),
          buildInfoItems(),
        ],
      ),
    );
  }

  Widget buildInfoTitle() {
    return Text(
      'Informasi RPP',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: ColorUtils.slate600,
      ),
    );
  }

  Widget buildInfoItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildTeacherItem(),
        buildSubjectItem(),
        buildClassItem(),
        buildAcademicYearItem(),
        buildSemesterItem(),
        buildCreatedDateItem(),
        buildNotesIfPresent(),
        if (_lp.hasAdminNotes) buildAdminNoteSection(),
      ],
    );
  }

  Widget buildTeacherItem() {
    return buildDetailItem('Guru Pengajar', _lp.teacherName ?? '-');
  }

  Widget buildSubjectItem() {
    return buildDetailItem('Mata Pelajaran', _lp.subjectName ?? '-');
  }

  Widget buildClassItem() {
    return buildDetailItem('Kelas', _lp.className ?? '-');
  }

  Widget buildAcademicYearItem() {
    return buildDetailItem('Tahun Ajaran', _lp.academicYear ?? '-');
  }

  Widget buildSemesterItem() {
    return buildDetailItem('Semester', _lp.semester ?? '-');
  }

  Widget buildCreatedDateItem() {
    return buildDetailItem('Tanggal Dibuat', _lp.createdAtDate);
  }

  Widget buildNotesIfPresent() {
    final model = _lp;
    if (model.hasNotes) {
      return buildDetailItem('Catatan', model.notes!);
    }
    return const SizedBox.shrink();
  }

  Widget buildAdminNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Catatan Admin',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: ColorUtils.slate600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _lp.adminNotes ?? '',
          style: TextStyle(
            fontSize: 14,
            color: ColorUtils.slate600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  BoxDecoration buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      border: Border.all(color: ColorUtils.slate200),
      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
    );
  }

  // Abstract methods from other mixins
  Widget buildDetailItem(String label, String value);
  String getStatusLabelDetail(String? status);
  Color getStatusColor(String status);
}
