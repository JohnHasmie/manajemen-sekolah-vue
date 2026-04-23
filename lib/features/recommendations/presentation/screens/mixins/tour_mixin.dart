import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin for tour/tutorial functionality.
mixin TourMixin {
  WidgetRef get ref;
  BuildContext get context;
  GlobalKey get studentListKey;

  Future<void> checkAndShowTour() async {
    final tourCacheKey = CacheKeyBuilder.tourStatus(
      'recommendation_student_screen',
      'guru',
    );
    try {
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showTour();
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
      onFinish: () {
        _completeTour();
      },
      onSkip: () {
        _completeTour();
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: 'StudentList',
        keyTarget: studentListKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildTourContent(),
          ),
        ],
      ),
    );

    return targets;
  }

  Widget _buildTourContent() {
    final languageProvider = ref.read(languageRiverpod);

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
            _buildTourDescription(languageProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildTourTitle(dynamic languageProvider) {
    return Text(
      languageProvider.getTranslatedText({
        'en': 'Student List',
        'id': 'Daftar Siswa',
      }),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 20.0,
      ),
    );
  }

  Widget _buildTourDescription(dynamic languageProvider) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Text(
        languageProvider.getTranslatedText({
          'en':
              'Choose a student to view their '
              'AI-generated learning recommendations.',
          'id':
              'Pilih siswa untuk melihat rekomendasi '
              'belajar berbasis AI.',
        }),
        style: const TextStyle(color: Colors.white, fontSize: 14.0),
      ),
    );
  }

  void _completeTour() {
    getIt<ApiTourService>().completeTour(
      name: 'learning_recommendation_student_tour',
      role: 'guru',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('recommendation_student_screen', 'guru'),
      {'should_show': false},
    );
  }
}
