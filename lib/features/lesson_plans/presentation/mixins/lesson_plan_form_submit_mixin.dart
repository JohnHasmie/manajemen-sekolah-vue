import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';

/// Mixin handling form submission for lesson plan.
///
/// Manages file upload, lesson plan creation/update,
/// and post-submission UI updates.
mixin LessonPlanFormSubmitMixin on ConsumerState<LessonPlanFormDialog> {
  /// Submits the lesson plan form (create or update).
  ///
  /// Validates form, uploads file if provided, then saves
  /// lesson plan data. Handles both new and edit modes.
  Future<void> submitForm(
    GlobalKey<FormState> formKey,
    String? selectedSubjectId,
    String? selectedClassId,
    String? selectedTerm,
    String? selectedFileName,
    File? selectedFile,
    TextEditingController titleController,
    TextEditingController academicYearController,
    Function(bool) setIsUploading,
  ) async {
    if (!formKey.currentState!.validate()) return;

    setIsUploading(true);

    try {
      String? filePath;

      AppLogger.debug('lesson_plan', 'File selected: $selectedFile');
      AppLogger.debug('lesson_plan', 'File name: $selectedFileName');

      if (selectedFile != null) {
        try {
          AppLogger.debug('lesson_plan', 'Starting file upload...');
          final uploadResult = await LessonPlanService.uploadLessonPlanFile(
            selectedFile,
          );
          AppLogger.debug('lesson_plan', 'Upload result: $uploadResult');

          filePath = uploadResult['file_path'];
          AppLogger.info(
            'lesson_plan',
            'File uploaded successfully: $filePath',
          );
        } catch (uploadError) {
          AppLogger.error(
            'lesson_plan',
            'Error during file upload: $uploadError',
          );
          filePath = null;
        }
      } else {
        AppLogger.debug('lesson_plan', 'No file selected for upload');
      }

      AppLogger.debug('lesson_plan', 'Submitting RPP data:');
      AppLogger.debug('lesson_plan', '- Guru ID: ${widget.teacherId}');
      AppLogger.debug('lesson_plan', '- Mata Pelajaran ID: $selectedSubjectId');
      AppLogger.debug('lesson_plan', '- Kelas ID: $selectedClassId');
      AppLogger.debug('lesson_plan', '- Judul: ${titleController.text}');
      AppLogger.debug('lesson_plan', '- File Path: $filePath');

      // Priority: uploaded path > existing path > selected filename
      final existingFilePath =
          widget.lessonPlanData?['file_path']?.toString();
      final resolvedFilePath =
          filePath ?? existingFilePath ?? selectedFileName;

      AppLogger.debug(
        'lesson_plan',
        'Resolved file_path: $resolvedFilePath '
        '(upload=$filePath, existing=$existingFilePath, '
        'name=$selectedFileName)',
      );

      final lessonPlanData = {
        'subject_id': selectedSubjectId,
        'class_id': selectedClassId,
        'title': titleController.text,
        'semester': selectedTerm,
        'academic_year': academicYearController.text,
        if (resolvedFilePath != null &&
            resolvedFilePath.isNotEmpty)
          'file_path': resolvedFilePath,
      };

      if (widget.lessonPlanData != null) {
        await LessonPlanService.updateLessonPlan(
          widget.lessonPlanData!['id'],
          lessonPlanData,
        );
        AppLogger.info('lesson_plan', 'RPP updated successfully');
      } else {
        lessonPlanData['teacher_id'] = widget.teacherId;
        await LessonPlanService.createLessonPlan(lessonPlanData);
        AppLogger.info('lesson_plan', 'RPP created successfully');
      }

      if (!mounted) return;
      AppNavigator.pop(context);
      widget.onSaved();

      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showInfo(
        context,
        widget.lessonPlanData != null
            ? languageProvider.getTranslatedText({
                'en': 'RPP updated successfully',
                'id': 'RPP berhasil diupdate',
              })
            : languageProvider.getTranslatedText({
                'en': 'RPP created successfully',
                'id': 'RPP berhasil dibuat',
              }),
      );
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error creating RPP: $e');
      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showInfo(
        context,
        '${languageProvider.getTranslatedText({'en': 'Error', 'id': 'Terjadi Kesalahan'})}: $e',
      );
    } finally {
      setIsUploading(false);
    }
  }
}
