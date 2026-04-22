import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_result_screen.dart';

/// Mixin for tour-related functionality in recommendation result.
mixin ResultTourMixin on ConsumerState<LearningRecommendationResultScreen> {
  /// Checks if tour should be shown and displays it if needed.
  ///
  /// Loads tour status from cache and shows tour if flag is set.
  /// Called after recommendations are loaded successfully.
  Future<void> checkAndShowTour() async {
    final tourCacheKey = CacheKeyBuilder.tourStatus(
      'recommendation_result_screen',
      'guru',
    );
    try {
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('recommendation', e);
    }
  }

  /// Displays the tutorial coach mark with predefined targets.
  ///
  /// Shows interactive highlights for recommendation list and edit button.
  /// Handles completion and skip callbacks to mark tour as seen.
  void showTour() {
    final List<TargetFocus> targets = createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);
    final String skipText = languageProvider.getTranslatedText({
      'en': 'SKIP',
      'id': 'LEWATI',
    });

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: skipText,
      alignSkip: Alignment.topRight,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: _handleTourComplete,
      onSkip: _handleTourSkipped,
    ).show(context: context);
  }

  void _handleTourComplete() {
    getIt<ApiTourService>().completeTour(
      name: 'learning_recommendation_result_tour',
      role: 'guru',
      platform: 'mobile',
    );
    _markTourAsShown();
  }

  bool _handleTourSkipped() {
    getIt<ApiTourService>().completeTour(
      name: 'learning_recommendation_result_tour',
      role: 'guru',
      platform: 'mobile',
    );
    _markTourAsShown();
    return true;
  }

  void _markTourAsShown() {
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('recommendation_result_screen', 'guru'),
      {'should_show': false},
    );
  }

  /// Creates tour target focuses for key UI elements.
  ///
  /// Returns list of targets for recommendation list and edit button
  /// with localized content.
  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: 'RecommendationList',
        keyTarget: recommendationListKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Learning Recommendations',
                        'id': 'Rekomendasi Belajar',
                      }),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en':
                              'These are AI-generated recommendations '
                              'tailored to the student\'s performance.',
                          'id':
                              'Ini adalah rekomendasi berbasis AI yang '
                              'disesuaikan dengan performa siswa.',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: 'EditButton',
        keyTarget: editButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Edit Results',
                        'id': 'Ubah Hasil',
                      }),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en':
                              'Tap here to manually adjust or regenerate '
                              'the recommendations.',
                          'id':
                              'Ketuk di sini untuk menyesuaikan secara '
                              'manual atau membuat ulang rekomendasi.',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  /// Global key for recommendation list (used by tour).
  GlobalKey get recommendationListKey;

  /// Global key for edit button (used by tour).
  GlobalKey get editButtonKey;
}
