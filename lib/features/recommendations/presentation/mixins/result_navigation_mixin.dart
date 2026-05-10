import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_edit_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_result_screen.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin for navigation and UI helper methods.
mixin ResultNavigationMixin
    on ConsumerState<LearningRecommendationResultScreen> {
  /// Gets recommendations list.
  List<dynamic> get recommendations;

  /// Builds cache key for recommendations.
  String buildRecommendationsCacheKey();

  /// Fetches recommendations with optional cache.
  Future<void> fetchRecommendations({bool useCache = true});

  /// Opens the edit form for a single recommendation. The screen
  /// edits one rec at a time (bulk edit was retired because the
  /// stacked Quill editors didn't fit in one viewport). Pass the
  /// rec map directly — typically wired from a per-card pencil.
  Future<void> navigateToEditRec(Map<String, dynamic> rec) async {
    final result = await LearningRecommendationEditScreen.show(
      context: context,
      teacher: widget.teacher,
      student: widget.student,
      recommendation: rec,
    );

    if (result == true) {
      await LocalCacheService.invalidate(buildRecommendationsCacheKey());
      fetchRecommendations(useCache: false);
    }
  }

  /// Header-level pencil shortcut: edit the first rec. Useful for
  /// the result-screen header "Edit" action when only one rec is
  /// visible. No-op when the list is empty.
  Future<void> navigateToEdit() async {
    if (recommendations.isEmpty) return;
    final first = recommendations.first;
    if (first is! Map) return;
    await navigateToEditRec(Map<String, dynamic>.from(first));
  }

  /// Gets primary color based on teacher role.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(Teacher.fromJson(widget.teacher).role);
  }
}
