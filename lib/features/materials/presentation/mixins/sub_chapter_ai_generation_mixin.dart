import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';

/// Mixin providing AI material generation and polling for sub-chapter screen.
mixin SubChapterAiGenerationMixin on ConsumerState<SubBabDetailPage> {
  /// AI-generated data — bridge from state
  Map<String, dynamic>? get aiGeneratedData;
  set aiGeneratedData(Map<String, dynamic>? value);

  /// Loading state for AI content — bridge from state
  bool get isLoadingAi;
  set isLoadingAi(bool value);

  /// Polling state — bridge from state
  bool get isPollingAi;
  set isPollingAi(bool value);

  /// Polling status message — bridge from state
  String get pollingStatus;
  set pollingStatus(String value);

  /// Polling error message — bridge from state
  String? get pollingError;
  set pollingError(String? value);

  /// Generate material from AI API with optional prompt and force flag.
  Future<void> generateMaterial({
    String prompt = '',
    bool force = false,
  }) async {
    setState(() {
      isLoadingAi = true;
      pollingError = null;
      if (force) aiGeneratedData = null; // Clear old data to show loading
    });

    // Clear local cache when force regenerating
    if (force) {
      final aiCacheKey = _buildAiCacheKey();
      await LocalCacheService.clearStartingWith(aiCacheKey);
    }

    try {
      final payload = <String, dynamic>{
        'teacher_id': widget.teacherId,
        'subject_id': widget.subjectId,
        'chapter_id': widget.chapter['id'].toString(),
        'sub_chapter_id': widget.subChapter['id'].toString(),
      };

      if (prompt.isNotEmpty) payload['prompt'] = prompt;
      if (force) payload['force'] = true;

      final response = await getIt<ApiSubjectService>().generateMaterialRaw(
        payload,
      );
      if (!mounted) return;

      final resultBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode == 202) {
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

        setState(() {
          isPollingAi = true;
          isLoadingAi = true;
          pollingStatus =
              'Sedang memproses materi... ini bisa memakan waktu hingga 1 menit.';
        });

        await _startPolling(jobId: jobId, pollUrl: pollUrl);
        return;
      }

      if (response.statusCode == 429) {
        final message =
            resultBody['message'] ??
            'Batas penggunaan AI harian telah tercapai.';
        if (mounted) {
          setState(() {
            isLoadingAi = false;
            pollingError = message;
          });
        }
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = resultBody['data'] ?? resultBody;
        await _applyResult(data);
        return;
      }

      throw Exception(
        resultBody['message'] ?? 'Gagal menghasilkan materi dari AI.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingAi = false;
        isPollingAi = false;
        pollingError = e.toString();
      });
    }
  }

  /// Poll an AI job until completion.
  Future<void> _startPolling({String? jobId, String? pollUrl}) async {
    final token = PreferencesService().getString('token');

    int attempts = 0;
    const maxAttempts = 60;

    while (attempts < maxAttempts) {
      if (!mounted) return;
      attempts++;

      try {
        final jobIdForPoll = jobId ?? pollUrl?.split('/').last ?? '';
        if (jobIdForPoll.isNotEmpty) {
          final response = await getIt<ApiSubjectService>().pollAiJob(
            jobIdForPoll,
            token ?? '',
          );

          if (!mounted) return;

          if (response.statusCode == 200) {
            final resultBody = response.data is Map<String, dynamic>
                ? response.data as Map<String, dynamic>
                : <String, dynamic>{};
            final jobData = resultBody['data'] ?? resultBody;
            final status = jobData['status'] ?? resultBody['status'];

            if (status == 'completed' || status == 'success') {
              final materialData =
                  jobData['result'] ??
                  jobData['data'] ??
                  resultBody['result'] ??
                  resultBody;
              if (materialData is Map<String, dynamic>) {
                await _applyResult(materialData);
              } else {
                AppLogger.error(
                  'material',
                  'Unexpected polling payload shape: ${materialData.runtimeType}',
                );
                await _applyResult(<String, dynamic>{});
              }
              return;
            } else if (status == 'failed' || status == 'error') {
              setState(() {
                isPollingAi = false;
                isLoadingAi = false;
                pollingError =
                    jobData['error_message'] ?? 'AI gagal memproses materi.';
              });
              return;
            }
          }
        }
      } catch (e) {
        AppLogger.error('material', e.toString());
      }

      await Future.delayed(const Duration(seconds: 4));
    }

    if (mounted) {
      setState(() {
        isPollingAi = false;
        isLoadingAi = false;
        pollingError = 'Proses memakan waktu terlalu lama. Silakan coba lagi.';
      });
    }
  }

  /// Apply AI result to state and save cache.
  ///
  /// The backend persists the generated material (+ quizzes + references)
  /// inside a DB transaction during generate. But Flutter previously only
  /// held the result in in-memory state: when the teacher left the screen
  /// and came back, `loadAiContent` had a local-cache miss and had to
  /// round-trip through `checkMaterialCache` + `getGeneratedMaterial/{id}`
  /// to re-hydrate. On slow networks or transient failures that made the
  /// just-generated material look "lost" — the symptom teachers reported
  /// as "it's not saved."
  ///
  /// We mirror the [SubChapterMaterialMixin.regenerateMaterialOnly] path
  /// by writing the polling result to [LocalCacheService] under the same
  /// `materi_ai` key `loadAiContent` reads from. That makes immediate
  /// re-open a cache hit and guarantees visible continuity with what the
  /// user just saw after pressing Generate. A success snackbar gives the
  /// teacher explicit confirmation that the content was saved.
  Future<void> _applyResult(Map<String, dynamic> data) async {
    if (!mounted) return;

    setState(() {
      aiGeneratedData = data;
      isLoadingAi = false;
      isPollingAi = false;
      pollingError = null;
    });

    // Persist to local cache so subsequent opens render instantly without
    // re-fetching. Failures here are non-fatal — the backend already has
    // the authoritative copy, so we just log and continue.
    //
    // LocalCacheService.save swallows JSON-encode errors internally. We
    // verify the save actually landed (#137) by reading back with the
    // same key so silent failures aren't invisible.
    try {
      final aiCacheKey = _buildAiCacheKey();
      AppLogger.debug(
        'material',
        '[#137] _applyResult saving key=$aiCacheKey '
            'keys=${data.keys.toList()} '
            'quizzes=${(data['quizzes'] as List?)?.length ?? 0} '
            'refs=${(data['references'] as List?)?.length ?? 0}',
      );
      await LocalCacheService.save(aiCacheKey, data);
      final verify = await LocalCacheService.load(
        aiCacheKey,
        ttl: const Duration(hours: 6),
      );
      AppLogger.debug(
        'material',
        '[#137] _applyResult save verify: '
            '${verify != null ? "OK" : "SAVE SILENTLY FAILED"}',
      );

      // Also write a sub-chapter-scoped pointer key that stores just the
      // material_id. This bypasses any teacher_id / chapter_id drift on
      // re-open: loadAiContent uses this to call getGeneratedMaterial({id})
      // directly before falling through to checkMaterialCache / list scan.
      // See sub_chapter_data_mixin.dart loadAiContent tier 1.5.
      final materialId = data['id']?.toString();
      if (materialId != null && materialId.isNotEmpty) {
        final pointerKey = _buildSubChapterPointerKey();
        await LocalCacheService.save(pointerKey, {
          'material_id': materialId,
          'saved_at': DateTime.now().millisecondsSinceEpoch,
        });
        AppLogger.debug(
          'material',
          '[#137] _applyResult saved pointer key=$pointerKey '
              'material_id=$materialId',
        );
      } else {
        AppLogger.error(
          'material',
          '[#137] _applyResult: payload missing id — no pointer saved',
        );
      }
    } catch (e) {
      AppLogger.error('material', '[#137] AI cache save after generate: $e');
    }

    // Cross-DB sync — kamiledu-ai has persisted the material, but the list
    // screen and dashboard counters read from core_api's material_progress
    // table (see MaterialProgressController::getTeacherSummary). Without
    // this POST the `is_generated` flag stays false, so classes keep
    // showing "0 AI" even after a successful generation + pull-to-refresh
    // and the sub-bab still offers "Generate" on re-entry. (#138)
    //
    // Failures here are non-fatal: the AI content itself is safely stored
    // in kamiledu-ai and in local cache, so the teacher's immediate
    // experience is unaffected. We just log and move on — next successful
    // generation or a manual reset on the progress row will reconcile.
    try {
      final classId = widget.classId;
      if (classId != null && classId.isNotEmpty) {
        await getIt<ApiSubjectService>().markMaterialGenerated({
          'teacher_id': widget.teacherId,
          'subject_id': widget.subjectId,
          'class_id': classId,
          'items': [
            {
              'bab_id': widget.chapter['id'],
              'sub_bab_id': widget.subChapter['id'],
            },
          ],
        });
        AppLogger.debug(
          'material',
          '[#138] markMaterialGenerated OK teacher=${widget.teacherId} '
              'subject=${widget.subjectId} class=$classId '
              'chapter=${widget.chapter['id']} sub=${widget.subChapter['id']}',
        );

        // Clear the teacher-summary caches so pull-to-refresh returns the
        // fresh `generated` counter. Scoped to the summary prefix — we
        // deliberately don't call CacheInvalidationService.onMaterialChanged()
        // because that would nuke the `materi_ai_*` and `materi_ai_ptr_*`
        // keys we just wrote, forcing an extra round-trip on re-open.
        await LocalCacheService.clearStartingWith('materi_summary_');
        await LocalCacheService.clearStartingWith('materi_progress_');
      } else {
        AppLogger.debug(
          'material',
          '[#138] markMaterialGenerated skipped: classId is null/empty',
        );
      }
    } catch (e) {
      AppLogger.error('material', '[#138] markMaterialGenerated failed: $e');
    }

    widget.onGenerated?.call();

    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        'Materi berhasil dibuat dan tersimpan.',
      );
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

  /// Sub-chapter-scoped pointer key. Stores the `material_id` of the
  /// latest generated material for this sub-chapter so the detail screen
  /// can re-hydrate by id even if the composite `materi_ai_{teacher}_
  /// {chapter}_{sub}` key changes between mounts (e.g. teacherProfileId
  /// lazy-loads after first render and produces a different cache key).
  String _buildSubChapterPointerKey() {
    return CacheKeyBuilder.custom(
      'materi_ai_ptr',
      widget.subChapter['id'].toString(),
    );
  }
}
