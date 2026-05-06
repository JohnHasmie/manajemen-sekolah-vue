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

  /// True when the lesson plan being viewed is AI-generated.
  ///
  /// AI-generated RPPs live in the kamiledu-ai backend (separate
  /// database, separate URL); the core /rpp endpoint just mirrors
  /// the metadata. Editing must hit the AI backend's
  /// `PATCH /lesson-plans/{id}`, otherwise the core PATCH 200s but
  /// the AI-side content is never touched and the screen reloads
  /// the old values.
  bool _isAiGeneratedRpp() {
    bool truthy(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s.isNotEmpty && s != 'false' && s != '0' && s != 'null';
      }
      return v != null;
    }

    if (truthy(lessonPlanData['is_ai_generated'])) return true;
    if (truthy(lessonPlanData['ai_generated'])) return true;
    if (truthy(lessonPlanData['ai_model_used'])) return true;
    if (truthy(lessonPlanData['ai_tokens_used'])) return true;
    if (truthy(lessonPlanData['lesson_plan_ai_id'])) return true;
    return false;
  }

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

      // Forward the existing id so the service can PATCH instead of
      // POST. Without this, every "save edit" silently inserted a
      // new record while the original RPP stayed unchanged.
      final existingId = fallback(['id', 'rpp_id', 'lesson_plan_id']);

      // AI-generated RPPs live on the kamiledu-ai backend. Route
      // the edit to its PATCH endpoint instead of the core /rpp/{id}
      // PATCH, which would 200 happily without ever touching the
      // AI-side content. Field set matches RppFieldRegenLimit's
      // ALLOWED_FIELDS plus `title`.
      if (_isAiGeneratedRpp() && existingId.isNotEmpty) {
        final aiPayload = <String, dynamic>{
          'title': fallback(['title', 'judul']),
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
        };
        // Strip empty strings so the AI backend's optional-field
        // update only touches what was actually edited / present.
        aiPayload.removeWhere((_, v) => v is String && v.isEmpty);

        await getIt<ApiSubjectService>().updateLessonPlanFields(
          existingId,
          aiPayload,
        );
      } else {
        await getIt<ApiSubjectService>().saveRPP({
          if (existingId.isNotEmpty) 'id': existingId,
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
      }

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
