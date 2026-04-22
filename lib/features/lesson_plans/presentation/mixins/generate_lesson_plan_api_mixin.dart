import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/config/ai_config.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/generate_lesson_plan_form_dialog.dart';

mixin GenerateLessonPlanApiMixin
    on ConsumerState<GenerateLessonPlanFormDialog> {
  /// Calls AI API to generate lesson plan
  Future<void> callAiGenerationApi(
    Map<String, dynamic> requestBody,
    String? token,
  ) async {
    AppLogger.debug('lesson_plan', '🌐 Sending POST request to KamillLabs...');
    AppLogger.debug('lesson_plan', 'Payload: ${json.encode(requestBody)}');

    final aiDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        validateStatus: (_) => true,
      ),
    );

    final response = await aiDio.post(
      '${AiConfig.baseUrl}/lesson-plans/generate',
      data: requestBody,
    );

    AppLogger.debug(
      'lesson_plan',
      '📥 Response Status: ${response.statusCode}',
    );

    final resultBody = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};

    await _handleApiResponse(response, resultBody, token);
  }

  Future<void> _handleApiResponse(
    Response response,
    Map<String, dynamic> resultBody,
    String? token,
  ) async {
    if (response.statusCode == 202) {
      await _handleAsyncResponse(resultBody, token);
      return;
    }

    if (response.statusCode == 429) {
      _handleRateLimitError(resultBody);
      return;
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      AppLogger.error('lesson_plan', 'API Error Body: ${response.data}');
      final message = resultBody['message'] ?? 'Gagal generate RPP';
      throw Exception(message);
    }

    final lessonPlanResponse = resultBody['data'] ?? resultBody;
    await processAndNavigate(lessonPlanResponse);
  }

  Future<void> _handleAsyncResponse(
    Map<String, dynamic> resultBody,
    String? token,
  ) async {
    AppLogger.debug('lesson_plan', 'Full 202 Response: $resultBody');

    final pollUrl =
        (resultBody['poll_url'] ??
                resultBody['polling_url'] ??
                resultBody['status_url'])
            as String?;
    final jobId =
        (resultBody['job_id'] ??
                resultBody['jobId'] ??
                resultBody['id'] ??
                resultBody['data']?['id'] ??
                resultBody['data']?['job_id'])
            as String?;

    AppLogger.debug(
      'lesson_plan',
      '⏳ Job Queued: $jobId | Polling at: $pollUrl',
    );

    final pollingMetadata = await buildPollingMetadata();

    if (!mounted) return;

    // Capture values before popping the bottom sheet
    final parentContext = Navigator.of(context, rootNavigator: true).context;
    final tId = widget.teacherId;
    final onSavedCb = widget.onSaved;

    // Pop the bottom sheet first to avoid _dependents.isEmpty assertion
    Navigator.of(context).pop();

    // Present the result sheet after the generate-form sheet is fully
    // disposed. Flat-flow: sheet → sheet handoff over the list screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LessonPlanAiResultScreen.show(
        context: parentContext,
        teacherId: tId,
        onSaved: onSavedCb,
        pollUrl: pollUrl,
        jobId: jobId,
        token: token,
        pollingMetadata: pollingMetadata,
      );
    });
  }

  void _handleRateLimitError(Map<String, dynamic> resultBody) {
    AppLogger.warning('lesson_plan', 'Rate limit reached');
    final message =
        resultBody['message'] ??
        'Batas pembuatan RPP AI harian/bulanan telah tercapai.';
    if (mounted) {
      AppAlertDialog.show(
        context: context,
        title: 'Batas Tercapai',
        message: message,
        icon: Icons.timer_off_rounded,
        confirmText: 'Mengerti',
        showCancel: false,
      );
    }
  }

  // Abstract methods for implementation
  Future<void> processAndNavigate(dynamic lessonPlanResponse);
  Future<Map<String, dynamic>> buildPollingMetadata();
}
