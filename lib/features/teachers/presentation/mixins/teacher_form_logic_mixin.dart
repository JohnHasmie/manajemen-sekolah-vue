import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_form_dialog.dart';

/// Handles business logic for teacher form operations
mixin TeacherFormLogicMixin on ConsumerState<TeacherFormDialog> {
  // These fields are declared and initialized in TeacherFormInitMixin.
  // Do NOT redeclare them here — `late` re-declarations shadow the
  // initialized values and cause LateInitializationError at runtime.
  abstract TextEditingController nameController;
  abstract TextEditingController emailController;
  abstract TextEditingController nipController;
  abstract String? selectedGender;
  abstract String? selectedWaliKelasId;
  abstract String? selectedStatus;
  abstract List<String> selectedSubjectIds;
  abstract List<String> selectedClassIds;
  abstract bool isChangeUserMode;
  abstract bool isSaving;

  final ApiTeacherService _teacherService = getIt<ApiTeacherService>();

  Future<void> saveTeacher() async {
    final languageProvider = ref.read(languageRiverpod);
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty || selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Name, email, and gender are required',
              'id': 'Nama, email, dan jenis kelamin wajib diisi',
            }),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final data = {
        'name': name,
        'email': email,
        'employee_number': nipController.text.isNotEmpty
            ? nipController.text
            : null,
        'gender': selectedGender,
        'homeroom_class_id': selectedWaliKelasId,
        'employment_status': selectedStatus,
        'subject_ids': selectedSubjectIds,
        'class_ids': selectedClassIds,
        'academic_year_id': selectedYearId,
        if (widget.teacher != null && isChangeUserMode)
          'use_another_user': true,
      };

      if (widget.teacher == null) {
        await _teacherService.addTeacher(data);
        if (mounted) {
          SnackBarUtils.showInfo(
            context,
            languageProvider.getTranslatedText({
              'en':
                  'Teacher added successfully. Default password: '
                  'password123',
              'id':
                  'Guru berhasil ditambahkan. Password default: '
                  'password123',
            }),
          );
        }
      } else {
        await _teacherService.updateTeacher(
          widget.teacher!['id'].toString(),
          data,
        );
        if (mounted) {
          SnackBarUtils.showInfo(
            context,
            languageProvider.getTranslatedText({
              'en': 'Teacher updated successfully',
              'id': 'Guru berhasil diupdate',
            }),
          );
        }
      }

      if (mounted) {
        widget.onSaved();
        AppNavigator.pop(context);
      }
    } catch (error) {
      AppLogger.error('teacher', 'Save/Update teacher error: $error');
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${languageProvider.getTranslatedText({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }
}
