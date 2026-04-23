import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';

/// Mixin providing material regeneration for sub-chapter detail screen.
mixin SubChapterMaterialMixin on ConsumerState<SubBabDetailPage> {
  /// AI-generated data — bridge from state
  Map<String, dynamic>? get aiGeneratedData;
  set aiGeneratedData(Map<String, dynamic>? value);

  /// Regenerating material state — bridge from state
  bool get isRegeneratingMateri;
  set isRegeneratingMateri(bool value);

  /// Generate material (fallback) — should call AI generation mixin method
  Future<void> generateMaterialFallback({bool force = false}) async {
    // This is implemented in AI generation mixin; here for reference
  }

  /// Regenerate material content only (not quiz/ref).
  Future<void> regenerateMaterialOnly() async {
    final materialId = aiGeneratedData?['id']?.toString();
    if (materialId == null) {
      await generateMaterialFallback(force: true);
      return;
    }

    // Only set materi-loading, keep _aiGeneratedData so quiz+ref tabs stay visible
    setState(() => isRegeneratingMateri = true);
    final aiCacheKey = CacheKeyBuilder.custom(
      'materi_ai',
      '${widget.teacherId}_${widget.chapter['id']}',
      widget.subChapter['id'].toString(),
    );
    await LocalCacheService.clearStartingWith(aiCacheKey);

    try {
      final result = await getIt<ApiSubjectService>().regenerateMaterialContent(
        materialId,
      );
      if (!mounted) return;

      final data = result is Map ? (result['data'] ?? result) : null;
      if (data != null && data is Map<String, dynamic>) {
        setState(() {
          aiGeneratedData = data;
          isRegeneratingMateri = false;
        });
        await LocalCacheService.save(aiCacheKey, data);
      } else {
        setState(() => isRegeneratingMateri = false);
        await loadAiContent();
      }
    } catch (e) {
      AppLogger.error('material', 'Regenerate material error: $e');
      if (mounted) {
        setState(() => isRegeneratingMateri = false);
        // If 404/422, material doesn't exist on this server — do full regeneration
        if (e.toString().contains('404') || e.toString().contains('422')) {
          await generateMaterialFallback(force: true);
          return;
        }
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// Load AI content — abstract bridge resolved by `SubChapterDataMixin`.
  ///
  /// DO NOT give this method a body. A concrete stub here silently
  /// overrides the real `SubChapterDataMixin.loadAiContent` through
  /// Dart's mixin linearization (this mixin is applied after the data
  /// mixin in `SubBabDetailPageState`'s `with` clause, so whatever is
  /// most derived wins). An empty body therefore swallows every
  /// `initState()` call to `loadAiContent()` and leaves `aiGeneratedData`
  /// null forever — teachers see "Belum Ada Konten" on every re-open
  /// even though cache, pointer, and check-cache tiers would have hit.
  /// Leaving this abstract forces Dart to look up the concrete method
  /// on the composite class, which finds the data mixin's real one.
  /// (#139)
  Future<void> loadAiContent();
}
