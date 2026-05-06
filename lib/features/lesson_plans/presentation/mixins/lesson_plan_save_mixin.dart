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
  /// AI-generated RPPs live in the shared `lesson_plans` table but
  /// own their own update endpoint on the kamiledu-ai backend
  /// (`PATCH /lesson-plans/{id}`). The core API's `/rpp/{id}` also
  /// 200s mass-assignment writes against that same row, but it
  /// doesn't run the AI backend's editability gate or the
  /// regen-limit accounting, so saves there look like they
  /// succeed yet leave the screen reloading the old values until
  /// some side-effect on the AI side flushes them. Routing
  /// AI-flagged rows through the AI backend keeps the two
  /// pipelines consistent.
  ///
  /// Detection is intentionally inclusive: any of the AI bookkeeping
  /// fields, the chapter/sub-chapter pointers (only AI generation
  /// fills these), or a non-empty content field (AI's RppFieldRegenLimit
  /// content) is enough to flip the route. Manually-created RPPs
  /// have all of these null/blank.
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

    // Explicit AI bookkeeping flags
    const flagKeys = [
      'is_ai_generated',
      'ai_generated',
      'ai_model_used',
      'ai_tokens_used',
      'lesson_plan_ai_id',
      'chapter_id',
      'sub_chapter_id',
    ];
    for (final k in flagKeys) {
      if (truthy(lessonPlanData[k])) return true;
    }

    // Content-bearing fields. Only AI-generated RPPs have these
    // pre-filled at the moment; manually-created RPPs leave them
    // empty. If any of them carry content, route to the AI backend
    // so its regen-limits and editability gates stay authoritative.
    const contentKeys = [
      'core_competence',
      'basic_competence',
      'indicator',
      'learning_objective',
      'main_material',
      'learning_method',
      'media_tools',
      'learning_source',
      'learning_activities',
      'assessment',
    ];
    for (final k in contentKeys) {
      final v = lessonPlanData[k];
      if (v is String && v.trim().isNotEmpty) return true;
    }

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
