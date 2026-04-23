import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';

/// Mixin providing data loading (content, AI) for sub-chapter detail screen.
mixin SubChapterDataMixin on ConsumerState<SubBabDetailPage> {
  /// Content material items list — bridge from state
  List<dynamic> get contentList;
  set contentList(List<dynamic> value);

  /// AI-generated data — bridge from state
  Map<String, dynamic>? get aiGeneratedData;
  set aiGeneratedData(Map<String, dynamic>? value);

  /// Loading state for content — bridge from state
  bool get isLoading;
  set isLoading(bool value);

  /// Loading state for AI content — bridge from state
  bool get isLoadingAi;
  set isLoadingAi(bool value);

  /// Load content materials from cache or API.
  Future<void> loadContent() async {
    final contentCacheKey = CacheKeyBuilder.custom(
      'materi_content',
      widget.subChapter['id'].toString(),
    );

    // Try cache — return early if hit
    try {
      final cached = await LocalCacheService.load(
        contentCacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && cached is List && mounted) {
        setState(() {
          contentList = List<dynamic>.from(cached);
          isLoading = false;
        });
        AppLogger.debug(
          'material',
          'ContentMateri ${widget.subChapter['id']}: from cache',
        );
        return;
      }
    } catch (e) {
      AppLogger.error('material', 'Content cache load error: $e');
    }

    // No cache — fetch from API
    if (mounted) setState(() => isLoading = true);

    try {
      final contentMaterial = await getIt<ApiSubjectService>()
          .getContentMaterials(
            subChapterId: widget.subChapter['id'].toString(),
          );
      if (!mounted) return;

      setState(() {
        contentList = contentMaterial;
        isLoading = false;
      });

      await LocalCacheService.save(contentCacheKey, contentMaterial);
    } catch (e) {
      AppLogger.error('material', 'Error loading content materi: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  /// Load AI-generated content from cache or API.
  ///
  /// Instrumented with `[#137]` debug tags so repro logs can be grepped
  /// from the simulator output. Each tier logs whether it hit, missed,
  /// or errored, and the API fallback logs the backend's shape. This is
  /// the workflow:
  ///
  ///   1. Local SharedPreferences cache (6 h TTL, composite key) —
  ///      instant hit.
  ///   1.5 Sub-chapter pointer cache — stores just the `material_id`
  ///      under a sub-chapter-scoped key written by `_applyResult`.
  ///      Bypasses composite-key drift (e.g. teacherProfileId lazy load)
  ///      by fetching the material by id directly.
  ///   2. `checkMaterialCache` → if `cached=true`, follow up with
  ///      `getGeneratedMaterial(material_id)` for full payload.
  ///   3. `listGeneratedMaterials` fallback — scan for matching
  ///      `sub_chapter_id` and pull by id.
  Future<void> loadAiContent() async {
    final subChapterId = widget.subChapter['id'].toString();
    final chapterId = widget.chapter['id'].toString();
    final aiCacheKey = CacheKeyBuilder.custom(
      'materi_ai',
      '${widget.teacherId}_$chapterId',
      subChapterId,
    );

    AppLogger.debug(
      'material',
      '[#137] loadAiContent START key=$aiCacheKey '
      'teacher=${widget.teacherId} chapter=$chapterId sub=$subChapterId',
    );

    // Try local cache — return early if hit
    try {
      final cached = await LocalCacheService.load(
        aiCacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && cached is Map && mounted) {
        final map = Map<String, dynamic>.from(cached);
        setState(() {
          aiGeneratedData = map;
          isLoadingAi = false;
        });
        AppLogger.debug(
          'material',
          '[#137] cache HIT keys=${map.keys.toList()} '
          'quizzes=${(map['quizzes'] as List?)?.length ?? 0} '
          'refs=${(map['references'] as List?)?.length ?? 0}',
        );
        return;
      }
      AppLogger.debug('material', '[#137] cache MISS (null or not Map)');
    } catch (e) {
      AppLogger.error('material', '[#137] cache load threw: $e');
    }

    // No cache — fetch from API
    if (mounted) setState(() => isLoadingAi = true);

    try {
      Map<String, dynamic>? aiData;

      // Tier 1.5 — sub-chapter pointer cache. Written by _applyResult on
      // successful generate; stores just the material_id. Lets us skip
      // both checkMaterialCache (which requires matching teacher_id +
      // chapter_id server-side) and the list-scan fallback when the only
      // thing that drifted is the composite cache key.
      try {
        final pointerKey = CacheKeyBuilder.custom(
          'materi_ai_ptr',
          subChapterId,
        );
        final pointer = await LocalCacheService.load(
          pointerKey,
          ttl: const Duration(hours: 6),
        );
        if (pointer is Map && pointer['material_id'] != null) {
          final pointerMaterialId = pointer['material_id'].toString();
          AppLogger.debug(
            'material',
            '[#137] pointer cache HIT material_id=$pointerMaterialId',
          );
          final materialResult = await getIt<ApiSubjectService>()
              .getGeneratedMaterial(pointerMaterialId);
          if (!mounted) return;
          final data = materialResult is Map
              ? (materialResult['data'] ?? materialResult)
              : null;
          if (data != null && data is Map<String, dynamic>) {
            aiData = data;
            AppLogger.debug(
              'material',
              '[#137] pointer fetch OK keys=${data.keys.toList()}',
            );
            // Rehydrate the composite cache so subsequent re-opens are
            // instant hits through tier 1.
            await LocalCacheService.save(aiCacheKey, data);
          } else {
            AppLogger.error(
              'material',
              '[#137] pointer fetch returned unexpected shape: '
              '${materialResult.runtimeType}',
            );
          }
        } else {
          AppLogger.debug('material', '[#137] pointer cache MISS');
        }
      } catch (pointerError) {
        AppLogger.error(
          'material',
          '[#137] pointer tier threw: $pointerError',
        );
      }

      // Tier 2 — server-side cache check by teacher+chapter+sub.
      if (aiData != null) {
        if (!mounted) return;
        setState(() {
          aiGeneratedData = aiData;
          isLoadingAi = false;
        });
        return;
      }

      try {
        final cacheResult = await getIt<ApiSubjectService>().checkMaterialCache(
          teacherId: widget.teacherId,
          chapterId: chapterId,
          subChapterId: subChapterId,
        );
        if (!mounted) return;

        AppLogger.debug(
          'material',
          '[#137] checkMaterialCache response=$cacheResult',
        );

        if (cacheResult != null) {
          final cacheData = cacheResult is Map && cacheResult['data'] is Map
              ? cacheResult['data']
              : cacheResult;

          final isCached = cacheData['cached'] == true;
          final materialId = (cacheData['material_id'] ?? cacheData['id'])
              ?.toString();

          AppLogger.debug(
            'material',
            '[#137] checkMaterialCache parsed cached=$isCached '
            'material_id=$materialId',
          );

          if (isCached && materialId != null) {
            final materialResult = await getIt<ApiSubjectService>()
                .getGeneratedMaterial(materialId);
            if (!mounted) return;

            final data = materialResult is Map
                ? (materialResult['data'] ?? materialResult)
                : null;
            if (data != null && data is Map<String, dynamic>) {
              aiData = data;
              AppLogger.debug(
                'material',
                '[#137] getGeneratedMaterial OK keys=${data.keys.toList()}',
              );
            } else {
              AppLogger.error(
                'material',
                '[#137] getGeneratedMaterial returned unexpected shape: '
                '${materialResult.runtimeType}',
              );
            }
          }
        }
      } catch (cacheError) {
        AppLogger.error(
          'material',
          '[#137] checkMaterialCache failed: $cacheError — list fallback',
        );
      }

      // Fallback: use list endpoint if check-cache failed
      if (aiData == null && mounted) {
        try {
          final listResult = await getIt<ApiSubjectService>()
              .listGeneratedMaterials(
                teacherId: widget.teacherId,
                chapterId: chapterId,
              );
          if (!mounted) return;

          final items = listResult is Map
              ? (listResult['data'] is List ? listResult['data'] : null)
              : (listResult is List ? listResult : null);

          AppLogger.debug(
            'material',
            '[#137] listGeneratedMaterials items=${items?.length ?? 0}',
          );

          if (items != null && items.isNotEmpty) {
            Map<String, dynamic>? match;

            for (final item in items) {
              if (item is Map<String, dynamic>) {
                final itemSubChapter =
                    (item['sub_chapter_id'] ?? item['sub_bab_id'])?.toString();
                if (itemSubChapter == subChapterId) {
                  match = item;
                  break;
                }
              }
            }

            if (match != null) {
              final materialId = match['id']?.toString();
              AppLogger.debug(
                'material',
                '[#137] list fallback matched material_id=$materialId',
              );
              if (materialId != null) {
                final materialResult = await getIt<ApiSubjectService>()
                    .getGeneratedMaterial(materialId);
                if (!mounted) return;

                final data = materialResult is Map
                    ? (materialResult['data'] ?? materialResult)
                    : null;
                if (data != null && data is Map<String, dynamic>) {
                  aiData = data;
                }
              }
            } else {
              AppLogger.debug(
                'material',
                '[#137] list fallback: no item matched sub=$subChapterId',
              );
            }
          }
        } catch (listError) {
          AppLogger.error(
            'material',
            '[#137] list fallback threw: $listError',
          );
        }
      }

      // Tier 4 — teacher-agnostic check-cache. When every tier above
      // missed, ask the backend "is there ANY generated material for
      // (chapter_id, sub_chapter_id)?" without pinning to teacher_id.
      //
      // This is the escape hatch for the re-open bug (#139). The
      // symptom: teacher generates material, closes the sheet, re-opens
      // and sees "Belum Ada Konten" with a Generate button — even
      // though `material_progress.is_generated=true`. Root cause is that
      // `widget.teacherId` resolves to a different UUID on re-mount
      // because `teacherProfileId` lazy-loads from Riverpod and the
      // pre-load fallback (`Teacher.fromJson(widget.teacher).id`) is a
      // different value. Every teacher-scoped lookup (tier 2, tier 3)
      // misses on the drifted id even though the row exists in the DB.
      //
      // The backend endpoint now accepts check-cache without teacher_id
      // as long as sub_chapter_id is supplied. It returns the most
      // recent material for that sub-chapter, which for a single-teacher
      // school is always the right one and for multi-teacher schools is
      // a reasonable "this sub-chapter already has content, here it is"
      // response.
      if (aiData == null && mounted) {
        try {
          final cacheResult = await getIt<ApiSubjectService>()
              .checkMaterialCache(
                // teacherId omitted — teacher-agnostic fallback
                chapterId: chapterId,
                subChapterId: subChapterId,
              );
          if (!mounted) return;

          AppLogger.debug(
            'material',
            '[#139] teacher-agnostic checkMaterialCache response=$cacheResult',
          );

          if (cacheResult != null) {
            final cacheData = cacheResult is Map && cacheResult['data'] is Map
                ? cacheResult['data']
                : cacheResult;

            final isCached = cacheData['cached'] == true;
            final materialId = (cacheData['material_id'] ?? cacheData['id'])
                ?.toString();

            if (isCached && materialId != null && materialId.isNotEmpty) {
              final materialResult = await getIt<ApiSubjectService>()
                  .getGeneratedMaterial(materialId);
              if (!mounted) return;

              final data = materialResult is Map
                  ? (materialResult['data'] ?? materialResult)
                  : null;
              if (data != null && data is Map<String, dynamic>) {
                aiData = data;
                AppLogger.debug(
                  'material',
                  '[#139] teacher-agnostic lookup HIT material_id=$materialId '
                  'keys=${data.keys.toList()}',
                );
                // Rehydrate the sub-chapter pointer cache so subsequent
                // re-opens short-circuit at tier 1.5 instead of round-
                // tripping to the server again.
                final pointerKey = CacheKeyBuilder.custom(
                  'materi_ai_ptr',
                  subChapterId,
                );
                await LocalCacheService.save(pointerKey, {
                  'material_id': materialId,
                  'saved_at': DateTime.now().millisecondsSinceEpoch,
                });
              }
            } else {
              AppLogger.debug(
                'material',
                '[#139] teacher-agnostic lookup MISS cached=$isCached '
                'material_id=$materialId',
              );

              // Self-heal: if the teacher-agnostic lookup confirms the
              // AI row genuinely doesn't exist, but core_api's
              // `material_progress.is_generated=true` is feeding the
              // main-screen counter a lie, reset that flag. This is the
              // recovery path for a DB desync — e.g. kamiledu-ai got
              // migrate:fresh'd but core_api kept its flags, or a past
              // generate job set the flag before the kamiledu-ai row was
              // actually persisted. Without this, teachers see
              // "2 AI" on the class list but every sub-bab shows
              // "Belum Ada Konten" forever. (#139)
              //
              // Narrowly scoped to the one (chapter, sub_chapter) the
              // user just re-opened — we don't sweep the teacher's
              // other counters. Failures non-fatal; next re-open
              // retries.
              final classId = widget.classId;
              if (classId != null && classId.isNotEmpty) {
                try {
                  await getIt<ApiSubjectService>().resetMaterialGenerated({
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
                  await LocalCacheService.clearStartingWith(
                    'materi_summary_',
                  );
                  await LocalCacheService.clearStartingWith(
                    'materi_progress_',
                  );
                  AppLogger.debug(
                    'material',
                    '[#139] self-heal reset is_generated for stale flag '
                    'teacher=${widget.teacherId} class=$classId '
                    'chapter=${widget.chapter['id']} '
                    'sub=${widget.subChapter['id']}',
                  );
                } catch (healError) {
                  AppLogger.error(
                    'material',
                    '[#139] self-heal reset threw: $healError',
                  );
                }
              }
            }
          }
        } catch (agnosticError) {
          AppLogger.error(
            'material',
            '[#139] teacher-agnostic lookup threw: $agnosticError',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        aiGeneratedData = aiData;
        isLoadingAi = false;
      });

      AppLogger.debug(
        'material',
        '[#137] loadAiContent END aiData=${aiData != null ? "hit" : "NULL"}',
      );

      if (aiData != null) {
        await LocalCacheService.save(aiCacheKey, aiData);
        // Verify save landed — helps catch silent JSON-encode failures.
        final roundTrip = await LocalCacheService.load(
          aiCacheKey,
          ttl: const Duration(hours: 6),
        );
        AppLogger.debug(
          'material',
          '[#137] post-save verify: ${roundTrip != null ? "OK" : "MISSING"}',
        );
      }
    } catch (e) {
      AppLogger.error('material', '[#137] Error loading AI content: $e');
      if (!mounted) return;
      setState(() => isLoadingAi = false);
    }
  }
}
