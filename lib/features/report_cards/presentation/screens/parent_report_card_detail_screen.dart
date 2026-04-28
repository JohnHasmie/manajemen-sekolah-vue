import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/report_card_display_mixin.dart';

/// Read-only report card detail view for parents.
///
/// StatelessWidget -- no local state needed. All data comes via props.
/// Uses ReportCardDisplayMixin for card-building methods.
class ParentReportCardDetailScreen extends StatelessWidget {
  final Map<String, dynamic> reportCardData;
  final String studentName;
  final Map<String, dynamic> studentData;
  final String userRole;

  const ParentReportCardDetailScreen({
    super.key,
    required this.reportCardData,
    required this.studentName,
    required this.studentData,
    this.userRole = 'wali',
  });

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(userRole);
  }

  LinearGradient getCardGradient() => ColorUtils.brandGradient(userRole);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: getCardGradient(),
              boxShadow: [
                BoxShadow(
                  color: getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Raport: '
                        '$studentName',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Detail E-Raport Siswa',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ParentCardBuilder(
                    reportCardData: reportCardData,
                    studentName: studentName,
                    studentData: studentData,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => downloadPdf(context),
        backgroundColor: ColorUtils.corporateBlue600,
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text('Cetak PDF', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void downloadPdf(BuildContext context) async {
    SnackBarUtils.showInfo(context, 'Menyiapkan file PDF...');

    try {
      if (userRole == 'wali') {
        await ExcelReportCardService.exportCertificateRaportPdf(
          studentClassId: reportCardData['student_class_id'].toString(),
          academicYearId: reportCardData['academic_year_id'].toString(),
          semesterId: reportCardData['semester_id'].toString(),
          studentName: studentName,
          context: context,
        );
      } else {
        await ExcelReportCardService.exportSingleRaportPdf(
          studentClassId: reportCardData['student_class_id'].toString(),
          academicYearId: reportCardData['academic_year_id'].toString(),
          semesterId: reportCardData['semester_id'].toString(),
          studentName: studentName,
          context: context,
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }
}

class _ParentCardBuilder extends StatefulWidget {
  final Map<String, dynamic> reportCardData;
  final String studentName;
  final Map<String, dynamic> studentData;

  const _ParentCardBuilder({
    required this.reportCardData,
    required this.studentName,
    required this.studentData,
  });

  @override
  State<_ParentCardBuilder> createState() => _ParentCardBuilderState();
}

class _ParentCardBuilderState extends State<_ParentCardBuilder>
    with ReportCardDisplayMixin {
  @override
  Map<String, dynamic> get reportCardData => widget.reportCardData;
  @override
  String get studentName => widget.studentName;
  @override
  Map<String, dynamic> get studentData => widget.studentData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildInfoCard(),
        const SizedBox(height: AppSpacing.lg),
        buildSikapCard(),
        const SizedBox(height: AppSpacing.lg),
        buildGradesCard(),
        const SizedBox(height: AppSpacing.lg),
        buildExtracurricularCard(),
        const SizedBox(height: AppSpacing.lg),
        buildAchievementCard(),
        const SizedBox(height: AppSpacing.lg),
        buildAttendanceCard(),
        const SizedBox(height: AppSpacing.lg),
        buildNotesCard(),
        const SizedBox(height: AppSpacing.lg),
        buildDecisionCard(),
      ],
    );
  }
}
