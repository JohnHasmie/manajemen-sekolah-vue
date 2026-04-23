import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/report_cards/data/report_card_service.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_detail_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Mixin for admin actions: export, publish, and details.
mixin AdminReportCardActionsMixin on ConsumerState<AdminReportCardScreen> {
  Future<void> exportToExcel() async {
    if (selectedClass == null) return;

    setState(() => isExporting = true);
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      if (academicYearId == null) {
        throw Exception('Tahun ajaran tidak valid.');
      }
      if (!mounted) return;

      await ExcelReportCardService.exportReportCardToExcel(
        classId: selectedClass!['id'].toString(),
        academicYearId: academicYearId,
        semesterId: semesterId,
        className: selectedClass!['name'] ?? 'Kelas',
        context: context,
      );
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Future<void> publishReportCards() async {
    if (selectedClass == null) return;

    final confirm = await AppAlertDialog.show(
      context: context,
      title: 'Kirim Rapor',
      message: 'Apakah Anda yakin ingin mengirim rapor kepada wali murid?',
      confirmText: 'Ya, Kirim',
      cancelText: 'Batal',
      confirmColor: ColorUtils.corporateBlue600,
      showCancel: true,
    );

    if (confirm != true) return;

    setState(() => isPublishing = true);
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      await dioClient.post(
        '/raports/publish',
        data: {
          'class_id': selectedClass!['id'],
          'academic_year_id': academicYearId,
          'semester_id': semesterId,
        },
      );

      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          'Raport berhasil dipublikasi dan dikirim ke wali murid!',
        );
        loadStudents(useCache: false);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  Future<void> viewReportCardDetail(Map<String, dynamic> student) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

      Map<String, dynamic>? detail = await getIt<ApiReportCardService>()
          .getRaportDetail(
            studentClassId: student['student_class_id'].toString(),
            academicYearId: academicYearId,
            semesterId: semesterId,
          );

      if (detail == null) {
        final initialData = await getIt<ApiReportCardService>().getInitialData(
          studentClassId: student['student_class_id'].toString(),
          academicYearId: academicYearId,
          semesterId: semesterId,
        );

        if (initialData != null) {
          final att = initialData['attendance'] ?? {};

          detail = {
            'student_class_id': student['student_class_id'],
            'academic_year_id': academicYearId,
            'semester_id': semesterId,
            'status': 'draft',
            'sick': att['sick'] ?? 0,
            'permit': att['permit'] ?? 0,
            'absent': att['absent'] ?? 0,
            'spiritual_predicate': null,
            'spiritual_description': null,
            'social_predicate': null,
            'social_description': null,
            'notes': null,
            'promotion_decision': null,
            'raport_subjects':
                (initialData['grades'] as List?)?.map((g) {
                  return {
                    'subject_id': g['subject_id'],
                    'knowledge_score': g['knowledge_score']?.toString(),
                    'knowledge_predicate': g['knowledge_predicate'],
                    'knowledge_description': g['knowledge_description'],
                    'skill_score': null,
                    'skill_predicate': null,
                    'skill_description': null,
                    'subject': {
                      'id': g['subject_id'],
                      'name': g['subject_name'],
                    },
                  };
                }).toList() ??
                [],
            'extracurriculars': [],
            'achievements': [],
          };
        }
      }

      if (!mounted) return;
      AppNavigator.pop(context);

      if (detail != null) {
        final model = Student.fromJson(student);
        AppNavigator.push(
          context,
          ParentReportCardDetailScreen(
            reportCardData: detail,
            studentName: model.name.isNotEmpty ? model.name : 'Unknown',
            userRole: 'admin',
            studentData: {
              'nis': model.studentNumber.isNotEmpty
                  ? model.studentNumber
                  : '-',
              'nisn': '-',
            },
          ),
        );
      } else {
        throw Exception('Data raport tidak ditemukan.');
      }
    } catch (e) {
      if (mounted) {
        AppNavigator.pop(context);
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> downloadStudentPdf(Map<String, dynamic> student) async {
    final status = student['raport_status'] ?? 'draft';
    if (status == 'draft') {
      SnackBarUtils.showInfo(context, 'Raport Draft belum bisa dicetak.');
      return;
    }

    final model = Student.fromJson(student);
    SnackBarUtils.showInfo(
      context,
      'Menyiapkan PDF untuk ${model.name}...',
    );

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString() ?? '';

      final dateBasedSemester = await getIt<ApiScheduleService>()
          .getDateBasedSemester();
      String semesterId = '1';
      if (dateBasedSemester.containsKey('semester') &&
          dateBasedSemester['semester'].toString().toLowerCase() == 'genap') {
        semesterId = '2';
      }

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

  // Abstract properties
  Map<String, dynamic>? get selectedClass;
  set selectedClass(Map<String, dynamic>? value);

  List<dynamic> get students;

  bool get isExporting;
  set isExporting(bool value);

  bool get isPublishing;
  set isPublishing(bool value);

  Future<void> loadStudents({bool useCache = true});
}
