import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_result_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin for fetch and cache operations in recommendation result screen.
mixin ResultFetchMixin on ConsumerState<LearningRecommendationResultScreen> {
  /// Builds cache key for recommendations based on teacher, class, student.
  ///
  /// Returns unique key combining all identifiers for cache storage.
  /// Segments the cache by scope (`wali` vs `mengajar`) so switching
  /// between roles doesn't show the other scope's stale list.
  String buildRecommendationsCacheKey() {
    final teacherId = Teacher.fromJson(widget.teacher).id;
    final classId = widget.classData['id']?.toString() ?? '';
    final studentId = Student.fromJson(widget.student).id;
    final scopeTag = widget.isHomeroomView ? 'wali' : 'mengajar';
    return 'recommendation_result_${teacherId}_${classId}_${studentId}_$scopeTag';
  }

  /// Forces refresh by clearing cache and fetching fresh data.
  Future<void> forceRefresh() async {
    await LocalCacheService.invalidate(buildRecommendationsCacheKey());
    fetchRecommendations(useCache: false);
  }

  /// Fetches learning recommendations from API with cache-first strategy.
  ///
  /// Attempts to load from cache first, falls back to API if not cached.
  /// Handles rate limiting errors gracefully and maintains error state.
  Future<void> fetchRecommendations({bool useCache = true}) async {
    final cacheKey = buildRecommendationsCacheKey();

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          recommendations = cached;
          isLoading = false;
          errorMessage = '';
        });
        AppLogger.debug(
          'recommendation',
          'RecommendationResult: from cache (${cached.length})',
        );
        return;
      }
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      final teacherId = Teacher.fromJson(widget.teacher).id;
      final classId = widget.classData['id']?.toString() ?? '';
      final studentId = Student.fromJson(widget.student).id;

      AppLogger.debug(
        'recommendation',
        'Fetching recommendations: teacherId=$teacherId, '
            'classId=$classId, studentId=$studentId, '
            'isHomeroomView=${widget.isHomeroomView}',
      );

      // In wali kelas mode scope by `homeroom_class_id` so we aggregate
      // recs from ALL authoring teachers in that homeroom. In mengajar
      // mode scope by the current teacher so we only see their own
      // authored recs. The backend enforces teacher_id XOR
      // homeroom_class_id, and `getRecommendations` prefers the homeroom
      // scope when both are supplied — pass nulls for the unused side
      // to make the intent explicit.
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final response = await getIt<ApiRecommendationService>()
          .getRecommendations(
            teacherId: widget.isHomeroomView ? null : teacherId,
            homeroomClassId: widget.isHomeroomView ? classId : null,
            classId: classId,
            studentId: studentId,
            academicYearId: ayId,
          );

      if (response['success'] == true) {
        final data = response['data'];
        final List recs;
        if (data is List) {
          recs = data;
        } else if (data is Map && data['data'] is List) {
          recs = data['data'];
        } else {
          recs = [];
        }

        AppLogger.debug(
          'recommendation',
          'Recommendations count: ${recs.length}',
        );

        await LocalCacheService.save(cacheKey, recs);

        if (!mounted) return;
        setState(() {
          recommendations = recs;
          isLoading = false;
          errorMessage = '';
        });
      } else {
        if (!mounted) return;
        if (recommendations.isEmpty) {
          setState(() {
            errorMessage =
                response['message'] ?? 'Gagal mengambil rekomendasi.';
            isLoading = false;
          });
        }
      }
    } on RateLimitException catch (e) {
      if (mounted && recommendations.isEmpty) {
        setState(() {
          errorMessage = e.message;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && recommendations.isEmpty) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  /// Gets or sets loading state.
  bool get isLoading;
  set isLoading(bool value);

  /// Gets or sets error message.
  String get errorMessage;
  set errorMessage(String value);

  /// Gets or sets recommendations list.
  List<dynamic> get recommendations;
  set recommendations(List<dynamic> value);

  /// Sets state using setState.
  @override
  void setState(VoidCallback fn);
}
