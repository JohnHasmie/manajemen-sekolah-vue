import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';

/// Mixin providing quiz management for sub-chapter detail screen.
mixin SubChapterQuizMixin on ConsumerState<SubBabDetailPage> {
  /// AI-generated data — bridge from state
  Map<String, dynamic>? get aiGeneratedData;
  set aiGeneratedData(Map<String, dynamic>? value);

  /// Adding quiz state — bridge from state
  bool get isAddingQuiz;
  set isAddingQuiz(bool value);

  /// Add more quiz questions.
  Future<void> addMoreQuiz() async {
    final materialId = aiGeneratedData?['id']?.toString();
    if (materialId == null) return;

    setState(() => isAddingQuiz = true);

    try {
      final response = await getIt<ApiSubjectService>().regenerateQuizRaw(
        materialId,
      );
      if (!mounted) return;

      if (response.statusCode == 202) {
        // Async — poll for result
        final body = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final jobId = (body['job_id'] ?? body['data']?['job_id'])?.toString();
        if (jobId != null) {
          await _pollAndReload(
            materialId,
            jobId,
            onDone: () {
              if (mounted) setState(() => isAddingQuiz = false);
            },
          );
          return;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _reloadMaterialFromApi(materialId);
        if (mounted) {
          setState(() => isAddingQuiz = false);
          SnackBarUtils.showSuccess(context, kMatQuizAddedSuccessfully.tr);
        }
        return;
      }

      final msg =
          (response.data is Map ? response.data['message'] : null) ??
          'Gagal menambah kuis';
      throw Exception(msg);
    } catch (e) {
      AppLogger.error('material', 'Add quiz error: $e');
      if (mounted) {
        setState(() => isAddingQuiz = false);
        SnackBarUtils.showError(
          context,
          e.toString().contains('404')
              ? 'Materi perlu di-generate ulang terlebih dahulu'
              : ErrorUtils.getFriendlyMessage(e),
        );
      }
    }
  }

  /// Poll AI job until complete, then reload material.
  Future<void> _pollAndReload(
    String materialId,
    String jobId, {
    VoidCallback? onDone,
  }) async {
    final token = PreferencesService().getString('token');
    int attempts = 0;

    while (attempts < 60 && mounted) {
      attempts++;
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      try {
        final pollResponse = await getIt<ApiSubjectService>().pollAiJob(
          jobId,
          token ?? '',
        );

        if (pollResponse.statusCode == 200) {
          final body = pollResponse.data is Map<String, dynamic>
              ? pollResponse.data as Map<String, dynamic>
              : <String, dynamic>{};
          final jobData = body['data'] ?? body;
          final status = jobData['status'] ?? body['status'];

          if (status == 'completed' || status == 'success') {
            await _reloadMaterialFromApi(materialId);
            onDone?.call();
            return;
          } else if (status == 'failed' || status == 'error') {
            if (mounted) {
              SnackBarUtils.showError(
                context,
                jobData['error_message']?.toString() ?? 'Gagal memproses',
              );
            }
            onDone?.call();
            return;
          }
        }
      } catch (_) {}
    }

    onDone?.call();
  }

  /// Reload material from API and cache.
  Future<void> _reloadMaterialFromApi(String materialId) async {
    final aiCacheKey = _buildAiCacheKey();
    await LocalCacheService.clearStartingWith(aiCacheKey);

    final result = await getIt<ApiSubjectService>().getGeneratedMaterial(
      materialId,
      classId: widget.classId,
    );
    if (!mounted) return;

    final data = result is Map ? (result['data'] ?? result) : null;
    if (data != null && data is Map<String, dynamic>) {
      setState(() => aiGeneratedData = data);
      await LocalCacheService.save(aiCacheKey, data);
    }
  }

  /// Build cache key for AI data.
  String _buildAiCacheKey() {
    final aiCacheKey = CacheKeyBuilder.custom(
      'materi_ai',
      '${widget.teacherId}_${widget.chapter['id']}',
      widget.subChapter['id'].toString(),
    );
    return aiCacheKey;
  }
}
