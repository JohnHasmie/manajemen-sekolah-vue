import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';

/// Mixin for onboarding tour functionality in
/// [LearningRecommendationClassScreen].
mixin TourMixin on ConsumerState<LearningRecommendationClassScreen> {
  /// Check and show tour if conditions are met.
  Future<void> checkAndShowTour() async {
    final tourCacheKey = CacheKeyBuilder.tourStatus(
      'recommendation_class_screen',
      'guru',
    );
    try {
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showTour();
          });
        }
      }
    } catch (e) {
      AppLogger.error('recommendation', e);
    }
  }

  void showTour() {
    final List<TargetFocus> targets = createTourTargets();
    if (targets.isEmpty) return;
    _showTutorialOverlay(targets);
  }

  void _showTutorialOverlay(List<TargetFocus> targets) {
    final languageProvider = ref.read(languageRiverpod);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      alignSkip: Alignment.topRight,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: _completeTour,
      onSkip: _skipTour,
    ).show(context: context);
  }

  void _completeTour() {
    getIt<ApiTourService>().completeTour(
      name: 'learning_recommendation_class_tour',
      role: 'guru',
      platform: 'mobile',
    );
    _saveTourStatus();
  }

  bool _skipTour() {
    getIt<ApiTourService>().completeTour(
      name: 'learning_recommendation_class_tour',
      role: 'guru',
      platform: 'mobile',
    );
    _saveTourStatus();
    return true;
  }

  void _saveTourStatus() {
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('recommendation_class_screen', 'guru'),
      {'should_show': false},
    );
  }

  List<TargetFocus> createTourTargets() {
    final targets = <TargetFocus>[];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: 'ClassList',
        keyTarget: classListKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildTourContent(languageProvider),
          ),
        ],
      ),
    );

    return targets;
  }

  Widget _buildTourContent(dynamic languageProvider) {
    return Material(
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
            _buildTourTitle(languageProvider),
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: _buildTourDescription(languageProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourTitle(dynamic languageProvider) {
    return Text(
      languageProvider.getTranslatedText({
        'en': 'Class List',
        'id': 'Daftar Kelas',
      }),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 20.0,
      ),
    );
  }

  Widget _buildTourDescription(dynamic languageProvider) {
    return Text(
      languageProvider.getTranslatedText({
        'en':
            'Choose one of your classes to see student learning '
            'recommendations.',
        'id':
            'Pilih salah satu kelas Anda untuk melihat '
            'rekomendasi belajar siswa.',
      }),
      style: const TextStyle(color: Colors.white, fontSize: 14.0),
    );
  }

  /// Get the class list key (defined in main state).
  GlobalKey get classListKey;
}
