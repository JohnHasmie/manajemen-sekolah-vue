import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_detail_screen.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

/// Mixin for AI-powered field regeneration in lesson plans.
/// Handles single field regen, batch regeneration, polling, and limit checks.
mixin LessonPlanAiRegenerationMixin on State<RPPDetailPage> {
  // Abstract getters/setters for state fields
  Map<String, dynamic> get lessonPlanData;
  set lessonPlanData(Map<String, dynamic> v);

  Map<String, dynamic> get regenLimits;
  set regenLimits(Map<String, dynamic> v);

  bool get isLoadingLimits;
  set isLoadingLimits(bool v);

  String? get regeneratingField;
  set regeneratingField(String? v);

  String? get editedContent;
  set editedContent(String v);

  bool get isMounted;

  List<Map<String, String>> get lessonPlanFields;
  Color get primaryColor;

  String? get lessonPlanId;

  String getFieldValue(String key, String altKey);
  Map<String, dynamic>? getFieldRegenInfo(String fieldKey);
  String formatLessonPlanContent();
  Future<void> loadRegenLimits();

  // Regenerate single field
  Future<void> regenerateField(
    String fieldKey,
    String fieldLabel,
    String additionalText,
  ) async {
    final planId = lessonPlanId;
    AppLogger.debug(
      'lesson_plan',
      'Regen field: $fieldKey, lessonPlanId: $planId',
    );
    if (planId == null) return;

    setState(() => regeneratingField = fieldKey);

    try {
      final response = await getIt<ApiSubjectService>().regenLessonPlanFieldRaw(
        planId,
        fieldKey,
        additionalText: additionalText.isNotEmpty ? additionalText : null,
      );

      if (!isMounted) return;

      // Check if response is HTML (server error)
      if (response.data is String) {
        final bodyStr = (response.data as String).trimLeft();
        if (bodyStr.startsWith('<!DOCTYPE') || bodyStr.startsWith('<html')) {
          AppLogger.error(
            'lesson_plan',
            'Got HTML response (status ${response.statusCode})',
          );
          setState(() => regeneratingField = null);
          SnackBarUtils.showError(
            context,
            'Server AI sedang tidak tersedia (${response.statusCode}). Coba lagi nanti.',
          );
          return;
        }
      }

      final body = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 429) {
        _showLimitReachedDialog(body['message'] ?? fieldLabel);
        setState(() => regeneratingField = null);
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = body['data'] ?? body;
        if (data[fieldKey] != null) {
          setState(() {
            lessonPlanData[fieldKey] = data[fieldKey];
            editedContent = formatLessonPlanContent();
            regeneratingField = null;
          });
          await loadRegenLimits();
          SnackBarUtils.showInfo(
            context,
            '$fieldLabel ${AppLocalizations.fieldRegeneratedSuccessfully.tr}',
          );
        } else {
          _updateLessonPlanDataFromResponse(data);
          setState(() => regeneratingField = null);
          await loadRegenLimits();
          SnackBarUtils.showInfo(
            context,
            '$fieldLabel ${AppLocalizations.fieldRegeneratedSuccessfully.tr}',
          );
        }
      } else if (response.statusCode == 202) {
        final jobId =
            (body['job_id'] ?? body['data']?['id'] ?? body['data']?['job_id'])
                ?.toString();
        final pollUrl = (body['poll_url'] ?? body['polling_url'])?.toString();
        if (jobId != null) {
          await _pollRegenJob(jobId, pollUrl, fieldKey, fieldLabel);
        } else {
          setState(() => regeneratingField = null);
          SnackBarUtils.showError(
            context,
            AppLocalizations.failedToGetJobId.tr,
          );
        }
      } else {
        setState(() => regeneratingField = null);
        final msg =
            body['message'] ??
            '${AppLocalizations.failedToGenerate.tr}: $fieldLabel';
        SnackBarUtils.showError(context, msg);
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (isMounted) {
        setState(() => regeneratingField = null);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // Regenerate all fields
  Future<void> regenerateAllFields(String additionalText) async {
    final planId = lessonPlanId;
    if (planId == null) return;

    setState(() => regeneratingField = 'all');

    int successCount = 0;
    int failCount = 0;

    for (final field in lessonPlanFields) {
      final fieldKey = field['key']!;
      final fieldValue = getFieldValue(fieldKey, field['altKey'] ?? '');
      if (fieldValue.isEmpty) continue;

      final regenInfo = getFieldRegenInfo(fieldKey);
      final remaining = regenInfo?['remaining'] ?? 2;
      if (remaining <= 0) {
        failCount++;
        continue;
      }

      try {
        final response = await getIt<ApiSubjectService>()
            .regenLessonPlanFieldRaw(
              planId,
              fieldKey,
              additionalText: additionalText.isNotEmpty ? additionalText : null,
            );

        if (!isMounted) return;

        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = body['data'] ?? body;
          if (data[fieldKey] != null) {
            lessonPlanData[fieldKey] = data[fieldKey];
          } else {
            _updateLessonPlanDataFromResponse(data);
          }
          successCount++;
        } else if (response.statusCode == 202) {
          final jobId = (body['job_id'] ?? body['data']?['id'])?.toString();
          if (jobId != null) {
            await _pollRegenJobSync(jobId, fieldKey);
            successCount++;
          } else {
            failCount++;
          }
        } else {
          failCount++;
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
        failCount++;
      }
    }

    if (isMounted) {
      setState(() {
        editedContent = formatLessonPlanContent();
        regeneratingField = null;
      });
      await loadRegenLimits();

      String msg =
          '$successCount field ${AppLocalizations.fieldRegeneratedSuccessfully.tr}';
      if (failCount > 0) {
        msg += ', $failCount ${AppLocalizations.failedExceededLimit.tr}';
      }
      SnackBarUtils.showInfo(context, msg);
    }
  }

  // Poll regeneration job
  Future<void> _pollRegenJob(
    String jobId,
    String? pollUrl,
    String fieldKey,
    String fieldLabel,
  ) async {
    final prefs = PreferencesService();
    final token = prefs.getString('token') ?? '';

    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!isMounted) return;

      try {
        final response = await getIt<ApiSubjectService>().pollAiJob(
          jobId,
          token,
        );
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = body['data'] ?? body;
        final status = jobData['status'] ?? body['status'];

        if (status == 'completed' || status == 'success') {
          final result =
              jobData['result'] ?? jobData['data'] ?? body['result'] ?? body;
          if (result[fieldKey] != null) {
            setState(() {
              lessonPlanData[fieldKey] = result[fieldKey];
              editedContent = formatLessonPlanContent();
              regeneratingField = null;
            });
          } else {
            _updateLessonPlanDataFromResponse(result);
            setState(() => regeneratingField = null);
          }
          await loadRegenLimits();
          if (isMounted) {
            SnackBarUtils.showInfo(
              context,
              '$fieldLabel ${AppLocalizations.fieldRegeneratedSuccessfully.tr}',
            );
          }
          return;
        } else if (status == 'failed' || status == 'error') {
          final errMsg = jobData['error_message'] ?? 'Regenerasi gagal';
          setState(() => regeneratingField = null);
          if (isMounted) {
            SnackBarUtils.showError(context, errMsg);
          }
          return;
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
      }
    }

    // Timeout
    if (isMounted) {
      setState(() => regeneratingField = null);
      SnackBarUtils.showError(context, 'Regenerasi $fieldLabel timeout');
    }
  }

  // Synchronous job polling for batch operations
  Future<void> _pollRegenJobSync(String jobId, String fieldKey) async {
    final prefs = PreferencesService();
    final token = prefs.getString('token') ?? '';

    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!isMounted) return;

      try {
        final response = await getIt<ApiSubjectService>().pollAiJob(
          jobId,
          token,
        );
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobData = body['data'] ?? body;
        final status = jobData['status'] ?? body['status'];

        if (status == 'completed' || status == 'success') {
          final result =
              jobData['result'] ?? jobData['data'] ?? body['result'] ?? body;
          if (result[fieldKey] != null) {
            lessonPlanData[fieldKey] = result[fieldKey];
          } else {
            _updateLessonPlanDataFromResponse(result);
          }
          return;
        } else if (status == 'failed' || status == 'error') {
          return;
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
      }
    }
  }

  void _updateLessonPlanDataFromResponse(Map<String, dynamic> data) {
    for (final field in lessonPlanFields) {
      final key = field['key']!;
      if (data.containsKey(key) && data[key] != null) {
        lessonPlanData[key] = data[key];
      }
    }
    setState(() => editedContent = formatLessonPlanContent());
  }

  void _showLimitReachedDialog(String fieldLabel) {
    AppAlertDialog.show(
      context: context,
      title: 'Batas Tercapai',
      message:
          'Batas regenerasi untuk "$fieldLabel" telah tercapai (maksimal 2 kali per field).',
      icon: Icons.timer_off_rounded,
      confirmText: 'Mengerti',
      showCancel: false,
    );
  }
}
