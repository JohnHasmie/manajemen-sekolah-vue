import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_detail_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

/// Mixin for saving lesson plan data to the API.
mixin LessonPlanSaveMixin on State<RPPDetailPage> {
  Map<String, dynamic> get lessonPlanData;
  bool get isMounted;
  bool get isSavingState;
  set isSavingState(bool value);

  /// Called after save succeeds. Override to exit edit mode, etc.
  void onSaveSuccess() {}

  Future<void> saveLessonPlan() async {
    setState(() => isSavingState = true);
    try {
      String fallback(List<String> keys) {
        for (final k in keys) {
          if (lessonPlanData.containsKey(k) && lessonPlanData[k] != null) {
            return lessonPlanData[k].toString();
          }
        }
        return '';
      }

      await getIt<ApiSubjectService>().saveRPP({
        'teacher_id': fallback(['teacher_id', 'guru_id']),
        'subject_id': fallback(['subject_id', 'mata_pelajaran_id']),
        'class_id': fallback(['class_id']),
        'title': fallback(['title', 'judul']),
        'semester': fallback(['semester']),
        'academic_year': fallback(['academic_year', 'tahun_ajaran']),
        'core_competence': fallback([
          'core_competence',
          'kompetensi_inti',
          'coreCompetency',
          'ki',
        ]),
        'basic_competence': fallback([
          'basic_competence',
          'kompetensi_dasar',
          'basicCompetency',
          'kd',
        ]),
        'indicator': fallback(['indicator', 'indikator']),
        'learning_objective': fallback([
          'learning_objective',
          'tujuan_pembelajaran',
          'learning_objectives',
        ]),
        'main_material': fallback(['main_material']),
        'learning_method': fallback(['learning_method']),
        'media_tools': fallback(['media_tools']),
        'learning_source': fallback(['learning_source']),
        'learning_activities': fallback([
          'learning_activities',
          'kegiatan_inti',
          'core_activities',
        ]),
        'assessment': fallback(['assessment', 'penilaian']),
        'status': fallback(['status']),
      });

      if (isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Lesson plan saved successfully',
                'id': 'RPP berhasil disimpan',
              }),
            ),
          ),
        );
        onSaveSuccess();
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (isMounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (isMounted) {
        setState(() => isSavingState = false);
      }
    }
  }
}
