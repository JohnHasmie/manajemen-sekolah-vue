import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';

/// Mixin for tour functionality in lesson plan screens.
/// Handles tour initialization, display, and completion logic.
mixin LessonPlanTourMixin on ConsumerState<LessonPlanScreen> {
  /// Abstract getter: subclass provides the filter key for tour targeting.
  GlobalKey get filterKey;

  /// Abstract getter: subclass provides the add RPP key for tour targeting.
  GlobalKey get addRppKey;

  /// Checks if tour should be shown and displays it if needed.
  /// Cache-only: tour status pre-fetched from dashboard.
  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('rpp_screen', 'guru');
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
      AppLogger.error('lesson_plan', 'Error checking tour status: $e');
    }
  }

  /// Shows the tour with all targets and handles completion.
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
          name: 'rpp_screen_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('rpp_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'rpp_screen_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('rpp_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  /// Creates all tour targets for the lesson plan screen.
  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    // Filter button tour target
    targets.add(
      TargetFocus(
        identify: 'FilterRPP',
        keyTarget: filterKey,
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
                      'en': 'Filter RPP',
                      'id': 'Filter RPP Cerdas',
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
                        'en': 'Use this to filter your RPP by status or class.',
                        'id':
                            'Temukan Rencana Pelaksanaan Pembelajaran dengan mudah. Filter berdasarkan Mata Pelajaran, Kelas, atau Status.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // Add RPP button tour target
    targets.add(
      TargetFocus(
        identify: 'AddRPP',
        keyTarget: addRppKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
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
                      'en': 'Add New RPP',
                      'id': 'Tambah & Generate RPP',
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
                            'Tap here to add a new RPP, either manually or via AI.',
                        'id':
                            'Klik ikon ini untuk membuat RPP baru. Anda dapat menggunakan fitur AI untuk men-generate otomatis atau mengunggah RPP manual.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}
