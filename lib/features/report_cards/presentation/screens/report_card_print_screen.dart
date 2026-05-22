import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:manajemensekolah/features/report_cards/presentation/mixins/report_card_print_layout_mixin.dart';

/// Print preview for a student's report card.
///
/// StatelessWidget -- like a Vue presentational component with only props.
/// Uses ReportCardPrintLayoutMixin for layout-building methods.
class ReportCardPrintScreen extends StatelessWidget {
  final Map<String, dynamic> reportCardData;
  final String studentName;
  final String className;

  const ReportCardPrintScreen({
    super.key,
    required this.reportCardData,
    required this.studentName,
    required this.className,
  });

  /// Generates and downloads the official Blade-rendered PDF
  /// (`raport.single` template) via the backend export endpoint.
  /// This is the same template the parent-side download uses, so the
  /// teacher and parent share one source of truth for the printed
  /// raport including KI 3 + KI 4 columns and the B.1 Deskripsi
  /// Capaian section.
  Future<void> _downloadPdf(BuildContext context) async {
    final studentClassId = (reportCardData['student_class_id'] ?? '')
        .toString();
    final academicYearId = (reportCardData['academic_year_id'] ?? '')
        .toString();
    final semesterId = (reportCardData['semester_id'] ?? '').toString();

    if (studentClassId.isEmpty ||
        academicYearId.isEmpty ||
        semesterId.isEmpty) {
      SnackBarUtils.showError(
        context,
        'Data raport belum lengkap untuk dicetak. Coba muat ulang halaman.',
      );
      return;
    }

    SnackBarUtils.showInfo(context, 'Menyiapkan file PDF...');
    try {
      await ExcelReportCardService.exportSingleRaportPdf(
        studentClassId: studentClassId,
        academicYearId: academicYearId,
        semesterId: semesterId,
        studentName: studentName,
        context: context,
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.getRoleColor('guru'),
                  ColorUtils.getRoleColor('guru').withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.3),
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
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview Raport',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$studentName - $className',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _downloadPdf(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Icon(
                      Icons.print,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  boxShadow: [...ColorUtils.corporateShadow()],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _PrintLayoutBuilder(
                    reportCardData: reportCardData,
                    studentName: studentName,
                    className: className,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintLayoutBuilder extends StatefulWidget {
  final Map<String, dynamic> reportCardData;
  final String studentName;
  final String className;

  const _PrintLayoutBuilder({
    required this.reportCardData,
    required this.studentName,
    required this.className,
  });

  @override
  State<_PrintLayoutBuilder> createState() => _PrintLayoutBuilderState();
}

class _PrintLayoutBuilderState extends State<_PrintLayoutBuilder>
    with ReportCardPrintLayoutMixin {
  @override
  Map<String, dynamic> get reportCardData => widget.reportCardData;
  @override
  String get studentName => widget.studentName;
  @override
  String get className => widget.className;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildHeader(),
        const SizedBox(height: AppSpacing.xxl),
        buildSikapSection(),
        const SizedBox(height: AppSpacing.lg),
        buildGradeSection(),
        const SizedBox(height: AppSpacing.lg),
        buildEkstraSection(),
        const SizedBox(height: AppSpacing.lg),
        buildPrestasiSection(),
        const SizedBox(height: AppSpacing.lg),
        buildInfoSection(),
        const SizedBox(height: AppSpacing.xxxl),
        buildSignatures(),
      ],
    );
  }
}
