import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Mixin for Excel and PDF export operations.
mixin TeacherReportCardExportMixin on ConsumerState<ReportCardScreen> {
  Future<void> exportToExcel() async {
    if (getSelectedClass() == null) return;

    setExporting(true);
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      if (academicYearId == null) {
        throw Exception('Tahun ajaran tidak valid.');
      }

      final semesterId = await resolveAcademicTerm();

      if (!mounted) return;
      await ExcelReportCardService.exportReportCardToExcel(
        classId: getSelectedClass()!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        className: getSelectedClass()!['name'] ?? 'Kelas',
        context: context,
      );
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setExporting(false);
      }
    }
  }

  Future<void> downloadStudentPdf(Map<String, dynamic> student) async {
    final status = student['raport_status'] ?? 'Belum ada';
    if (status.toLowerCase() != 'final' &&
        status.toLowerCase() != 'published') {
      SnackBarUtils.showInfo(
        context,
        'Raport belum final, tidak dapat dicetak.',
      );
      return;
    }

    final model = Student.fromJson(student);
    SnackBarUtils.showInfo(
      context,
      'Menyiapkan file PDF untuk ${model.name}...',
    );

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final semesterId = await resolveAcademicTerm();

      if (!mounted) return;
      await ExcelReportCardService.exportSingleRaportPdf(
        studentClassId: student['student_class_id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        studentName: model.name.isNotEmpty ? model.name : 'Unknown',
        context: context,
      );
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // Abstract methods
  Map<String, dynamic>? getSelectedClass();
  Future<String> resolveAcademicTerm();
  void setExporting(bool value);
}
