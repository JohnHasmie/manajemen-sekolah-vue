import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/config/ai_config.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_detail_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_data_mixin.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';

/// Handles saving edited RPP fields back to the AI backend via PATCH.
///
/// The AI backend already auto-saves the full RPP on generation.
/// This mixin handles PATCH updates for user edits (title, content fields).
/// It does NOT save to the core backend — RPP lives in the AI database.
mixin LessonPlanAiResultSaveMixin
    on State<LessonPlanAiResultScreen>, LessonPlanAiResultDataMixin {
  // State field
  bool _isSaving = false;

  // Getters and setters for protected access
  bool get isSaving => _isSaving;
  set isSaving(bool value) => _isSaving = value;

  /// The AI-backend ID of the generated lesson plan.
  /// Set after generation completes (direct or polled).
  String? _lessonPlanAiId;

  String? get lessonPlanAiId => _lessonPlanAiId;
  set lessonPlanAiId(String? value) => _lessonPlanAiId = value;

  /// Saves edited fields to the AI backend via PATCH.
  Future<void> saveLessonPlan() async {
    if (titleController.text.isEmpty) {
      SnackBarUtils.showWarning(context, 'Judul RPP wajib diisi.');
      return;
    }

    // If no AI ID, this was likely a direct-mode entry without backend save
    if (_lessonPlanAiId == null) {
      _handleNoIdSave();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = _buildUpdatePayload();
      AppLogger.debug('lesson_plan', 'PATCH RPP $_lessonPlanAiId: $payload');

      final token = PreferencesService().getString('token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        validateStatus: (_) => true,
      ));

      final response = await dio.patch(
        '${AiConfig.baseUrl}/lesson-plans/$_lessonPlanAiId',
        data: payload,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        SnackBarUtils.showSuccess(context, 'RPP berhasil disimpan.');
      } else {
        final msg = response.data?['message'] ?? 'Gagal menyimpan RPP';
        SnackBarUtils.showError(context, msg);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Save error: $e');
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Quick save without AI ID — just navigate back.
  void _handleNoIdSave() {
    AppLogger.warning(
      'lesson_plan',
      'No AI lesson plan ID available, navigating back',
    );
    SnackBarUtils.showSuccess(context, 'RPP berhasil disimpan.');
    AppNavigator.pop(context);
  }

  Map<String, dynamic> _buildUpdatePayload() {
    return {
      'title': titleController.text,
      'core_competence':
          coreCompetencyController.document.toPlainText().trim(),
      'basic_competence':
          basicCompetencyController.document.toPlainText().trim(),
      'learning_objective':
          objectivesController.document.toPlainText().trim(),
      'learning_activities':
          coreActivityController.document.toPlainText().trim(),
      'assessment': assessmentController.document.toPlainText().trim(),
    };
  }

  /// Called after generation completes — hands off to the RPP detail sheet.
  ///
  /// [lessonPlanData] contains the mapped lesson plan data from AI response.
  /// Both screens are now flat-flow bottom sheets (#145 pattern), so we
  /// pop the current AI-result sheet and present [RPPDetailPage] as a
  /// sheet over the same underlying list screen — the user never leaves
  /// the list, the transition is sheet → sheet.
  void handleGenerationComplete({Map<String, dynamic>? lessonPlanData}) {
    if (!mounted) return;

    // Trigger list refresh so the RPP appears when user returns.
    widget.onSaved();

    SnackBarUtils.showSuccess(context, 'RPP berhasil di-generate AI.');

    if (lessonPlanData != null) {
      // Ensure teacher_id is always present for save operations.
      final data = Map<String, dynamic>.from(lessonPlanData);
      if (data['teacher_id'] == null && data['guru_id'] == null) {
        data['teacher_id'] = widget.teacherId;
      }

      // Capture the parent (list) context BEFORE popping this sheet,
      // then schedule the detail sheet on the next frame so this sheet
      // is fully disposed first (avoids _dependents.isEmpty assertion).
      final parentContext = Navigator.of(context, rootNavigator: true).context;
      AppNavigator.pop(context);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        RPPDetailPage.show(
          context: parentContext,
          lessonPlanData: data,
          isNew: true,
        );
      });
    } else {
      // Fallback: no data — just dismiss the AI-result sheet.
      AppNavigator.pop(context);
    }
  }
}
