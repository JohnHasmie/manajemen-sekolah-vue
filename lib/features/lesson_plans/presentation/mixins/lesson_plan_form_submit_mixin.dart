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
      String? uploadedFileName;

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
          // The upload endpoint returns the original filename ("Tugas
          // Trigonometri.pdf") alongside the opaque storage path. Keep
          // it so we can persist + display it later without falling
          // back to the random storage name.
          uploadedFileName = uploadResult['file_name']?.toString();
          AppLogger.info(
            'lesson_plan',
            'File uploaded successfully: $filePath '
                '(name=$uploadedFileName)',
          );

          // Sanity check: backend should return a relative
          // path like "rpp_files/xxx.pdf". Anything else
          // (full URL, bare filename) means the upload was
          // misrouted — refuse to save it.
          if (filePath == null ||
              filePath.isEmpty ||
              !filePath.startsWith('rpp_files/')) {
            throw Exception('Upload mengembalikan path tidak valid: $filePath');
          }
        } catch (uploadError) {
          AppLogger.error(
            'lesson_plan',
            'Error during file upload: $uploadError',
          );
          if (mounted) {
            setIsUploading(false);
            SnackBarUtils.showError(
              context,
              'Gagal mengunggah file. Periksa koneksi '
              'lalu coba lagi.',
            );
          }
          return; // BLOCK save — don't persist invalid file_path
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

      // Use uploaded path if a new file was attached;
      // otherwise keep the existing record's file_path
      // unchanged. NEVER fall back to the bare local
      // filename — that's not a real storage path.
      final existingFilePath = widget.lessonPlanData?['file_path']?.toString();
      final existingFileName = widget.lessonPlanData?['file_name']?.toString();
      final resolvedFilePath = filePath ?? existingFilePath;
      // When a new file was uploaded, keep its original filename;
      // otherwise carry the existing name forward so the update
      // payload doesn't blank it out via array_filter on the server.
      final resolvedFileName = uploadedFileName ?? existingFileName;

      AppLogger.debug(
        'lesson_plan',
        'Resolved file_path: $resolvedFilePath '
            '(upload=$filePath, existing=$existingFilePath) '
            'file_name=$resolvedFileName',
      );

      // Backend rename (rename guide §4): lesson_plans.semester canonical
      // values are `odd` / `even` (was `Ganjil` / `Genap`).
      final rawTerm = (selectedTerm ?? '').toString().toLowerCase();
      final canonicalTerm = switch (rawTerm) {
        'ganjil' || 'gasal' || 'odd' => 'odd',
        'genap' || 'even' => 'even',
        _ => rawTerm,
      };
      final lessonPlanData = {
        'subject_id': selectedSubjectId,
        'class_id': selectedClassId,
        'title': titleController.text,
        'semester': canonicalTerm,
        'academic_year': academicYearController.text,
        if (resolvedFilePath != null && resolvedFilePath.isNotEmpty)
          'file_path': resolvedFilePath,
        if (resolvedFileName != null && resolvedFileName.isNotEmpty)
          'file_name': resolvedFileName,
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
      final errorWord = languageProvider.getTranslatedText({
        'en': 'Error',
        'id': 'Terjadi Kesalahan',
      });
      SnackBarUtils.showInfo(context, '$errorWord: $e');
    } finally {
      setIsUploading(false);
    }
  }
}
