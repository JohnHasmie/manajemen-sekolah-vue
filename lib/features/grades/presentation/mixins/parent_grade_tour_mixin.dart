import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';

/// Mixin for tour (tutorial) functionality.
///
/// Handles check, display, and tracking of tutorial for parent grades.
mixin ParentGradeTourMixin on ConsumerState<ParentGradeScreen> {
  // Expected to be provided by state
  GlobalKey get studentSelectorKey;
  GlobalKey get gradeListKey;
  List<dynamic> get studentList;

  /// Check if tour should be shown and display it.
  Future<void> checkAndShowTour() async {
    final tourCacheKey = CacheKeyBuilder.tourStatus(
      'parent_grade_screen',
      'wali',
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
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  /// Show the tour overlay.
  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'parent_grade_screen_tour',
          role: 'wali',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('parent_grade_screen', 'wali'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'parent_grade_screen_tour',
          role: 'wali',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('parent_grade_screen', 'wali'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  /// Build list of tour target focus points.
  List<TargetFocus> _createTourTargets() {
    final languageProvider = ref.read(languageRiverpod);
    return [
      _createSelectorTarget(languageProvider),
      _createGradeListTarget(languageProvider),
    ];
  }

  /// Create student selector tour target.
  TargetFocus _createSelectorTarget(LanguageProvider languageProvider) {
    return TargetFocus(
      identify: 'StudentSelector',
      keyTarget: studentSelectorKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Child',
                    'id': 'Pilih Anak',
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
                      'en': 'Select your child to view their grades.',
                      'id': 'Pilih anak Anda untuk melihat nilai mereka.',
                    }),
                    style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Create grade list tour target.
  TargetFocus _createGradeListTarget(LanguageProvider languageProvider) {
    return TargetFocus(
      identify: 'GradeList',
      keyTarget: gradeListKey,
      alignSkip: Alignment.topRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Grade List',
                    'id': 'Daftar Nilai',
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
                          'Here you can see the scores and details of '
                          'your child\'s assessments.',
                      'id':
                          'Di sini Anda dapat melihat skor dan detail '
                          'dari penilaian anak Anda.',
                    }),
                    style: const TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
