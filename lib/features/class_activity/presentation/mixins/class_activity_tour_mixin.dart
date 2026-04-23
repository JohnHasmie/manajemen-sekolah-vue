import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';

/// Mixin providing tour/tutorial functionality.
mixin ClassActivityTourMixin on ConsumerState<AdminClassActivityScreen> {
  bool get isTourShowing;
  set isTourShowing(bool value);

  GlobalKey get infoKey;
  GlobalKey get searchKey;

  Future<void> checkAndShowTour() async {
    if (isTourShowing) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'class_activity',
        'admin',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !isTourShowing) showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('class_activity', e);
    }
  }

  void showTour() {
    final List<TargetFocus> targets = createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    setState(() {
      isTourShowing = true;
    });

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: _onTourFinish,
      onSkip: _onTourSkip,
      onClickOverlay: (target) {},
    ).show(context: context);
  }

  void _onTourFinish() {
    setState(() {
      isTourShowing = false;
    });
    _completeTour();
  }

  bool _onTourSkip() {
    setState(() {
      isTourShowing = false;
    });
    _completeTour();
    return true;
  }

  void _completeTour() {
    getIt<ApiTourService>().completeTour(
      name: 'admin_class_activity_tour',
      role: 'admin',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('class_activity', 'admin'),
      {'should_show': false},
    );
  }

  List<TargetFocus> createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: 'ClassActivityInfo',
        keyTarget: infoKey,
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
                      'en': 'Class Activities',
                      'id': 'Kegiatan Kelas',
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
                            'Monitor and view teaching activities '
                            'conducted by all teachers.',
                        'id':
                            'Pantau dan lihat kegiatan mengajar yang '
                            'dilakukan oleh semua guru.',
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

    targets.add(
      TargetFocus(
        identify: 'ClassActivitySearch',
        keyTarget: searchKey,
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
                      'en': 'Search Activities',
                      'id': 'Cari Kegiatan',
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
                            'Quickly find teachers, subjects, or '
                            'specific activities.',
                        'id':
                            'Cari guru, mata pelajaran, atau kegiatan '
                            'tertentu dengan cepat.',
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
