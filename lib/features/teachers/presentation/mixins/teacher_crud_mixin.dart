import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/teachers/exports/teacher_export_service.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/teacher_detail_screen.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_form_dialog.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/admin_teacher_management_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

mixin TeacherCrudMixin on ConsumerState<TeacherAdminScreen> {
  // Abstract bridge to state
  List<dynamic> get teachers;
  set teachers(List<dynamic> v);

  List<dynamic> get subjects;
  List<dynamic> get classes;

  String? get selectedClassId;
  String? get selectedHomeroomFilter;
  String? get selectedGender;
  String? get selectedEmploymentStatus;
  String? get selectedTeachingClassId;
  bool get showAllTeachers;
  String? get searchText;

  Future<void> loadData({bool resetPage = true, bool useCache = true});

  Future<void> exportToExcel() async {
    try {
      if (!mounted) return;
      SnackBarUtils.showInfo(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Preparing export...',
          'id': 'Menyiapkan export...',
        }),
      );

      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final effectiveAcademicYearId = showAllTeachers ? null : selectedYearId;

      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: 1,
        limit: 10000,
        classId: selectedClassId,
        gender: null,
        academicYearId: effectiveAcademicYearId,
        search: (searchText?.trim().isEmpty ?? true)
            ? null
            : searchText?.trim(),
      );

      if (!mounted) return;

      final allTeachers = response['data'] ?? [];

      await ExcelTeacherService.exportTeachersToExcel(
        teachers: allTeachers,
        context: context,
      );
    } catch (e) {
      AppLogger.error('teacher', 'Export teachers error: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Failed to export: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': 'Gagal export: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    }
  }

  Future<void> importFromExcel() async {
    final languageProvider = ref.read(languageRiverpod);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        AppLogger.debug(
          'teacher',
          'Import teachers - picked file: ${pickedFile.path}, size: ${await pickedFile.length()} bytes',
        );

        try {
          final response = await getIt<ApiTeacherService>()
              .importTeachersFromExcel(pickedFile);
          AppLogger.debug('teacher', 'Import response: $response');

          if (response['errors'] != null &&
              response['errors'] is List &&
              (response['errors'] as List).isNotEmpty) {
            final errors = (response['errors'] as List).take(10).join('\n');
            if (!mounted) return;
            SnackBarUtils.showWarning(
              context,
              'Import finished with errors:\n$errors',
            );
          } else if (response['error'] != null) {
            if (!mounted) return;
            SnackBarUtils.showError(
              context,
              'Import failed: ${response['error']}',
            );
          } else {
            if (!mounted) return;
            SnackBarUtils.showSuccess(
              context,
              languageProvider.getTranslatedText({
                'en': 'Import completed',
                'id': 'Import selesai',
              }),
            );
          }

          await loadData();
        } catch (apiError) {
          AppLogger.error('teacher', 'Error calling import API: $apiError');
          if (!mounted) return;
          SnackBarUtils.showError(
            context,
            languageProvider.getTranslatedText({
              'en':
                  'Failed to import file: ${ErrorUtils.getFriendlyMessage(apiError)}',
              'id':
                  'Gagal import file: ${ErrorUtils.getFriendlyMessage(apiError)}',
            }),
          );
        }
      }
    } catch (e) {
      AppLogger.error('teacher', 'Import from Excel picker/process error: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Failed to import file: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': 'Gagal import file: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    }
  }

  Future<void> downloadTemplate() async {
    await ExcelTeacherService.downloadTemplate(context);
  }

  void openTeacherFormDialog({Map<String, dynamic>? teacher}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TeacherFormDialog(
        teacher: teacher,
        subjects: subjects,
        classes: classes,
        onSaved: loadData,
      ),
    );
  }

  Future<void> deleteTeacher(Map<String, dynamic> teacher) async {
    final languageProvider = ref.read(languageRiverpod);
    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: languageProvider.getTranslatedText({
        'en': 'Delete Teacher',
        'id': 'Hapus Guru',
      }),
      message: languageProvider.getTranslatedText({
        'en': 'Are you sure you want to delete this teacher?',
        'id': 'Apakah Anda yakin ingin menghapus guru ini?',
      }),
      confirmText: languageProvider.getTranslatedText({
        'en': 'Delete',
        'id': 'Hapus',
      }),
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        final teacherId = Teacher.fromJson(teacher).id;
        if (teacherId.isNotEmpty) {
          await getIt<ApiTeacherService>().deleteTeacher(teacherId);
          if (mounted) {
            SnackBarUtils.showSuccess(
              context,
              ref.read(languageRiverpod).getTranslatedText({
                'en': 'Teacher successfully deleted',
                'id': 'Guru berhasil dihapus',
              }),
            );
          }
          loadData();
        }
      } catch (error) {
        AppLogger.error('teacher', 'Delete teacher error: $error');
        if (mounted) {
          SnackBarUtils.showError(
            context,
            '${ref.read(languageRiverpod).getTranslatedText({'en': 'Failed to delete teacher: ', 'id': 'Gagal menghapus guru: '})}${ErrorUtils.getFriendlyMessage(error)}',
          );
        }
      }
    }
  }

  void navigateToDetail(Map<String, dynamic> teacher) {
    AppNavigator.push(context, TeacherDetailScreen(teacher: teacher));
  }
}
