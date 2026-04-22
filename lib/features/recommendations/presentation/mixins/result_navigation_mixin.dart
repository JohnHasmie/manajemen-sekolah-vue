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

  /// Opens the edit form as a bottom sheet stacked on top of the result
  /// sheet. On successful save, invalidates cached recommendations and
  /// re-fetches so the updated rows show immediately.
  Future<void> navigateToEdit() async {
    final result = await LearningRecommendationEditScreen.show(
      context: context,
      teacher: widget.teacher,
      student: widget.student,
      recommendations: recommendations,
    );

    if (result == true) {
      await LocalCacheService.invalidate(buildRecommendationsCacheKey());
      fetchRecommendations(useCache: false);
    }
  }

  /// Gets primary color based on teacher role.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(Teacher.fromJson(widget.teacher).role);
  }
}
