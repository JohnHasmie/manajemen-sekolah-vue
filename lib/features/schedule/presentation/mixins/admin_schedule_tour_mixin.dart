import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_tour_target_builder.dart';

mixin AdminScheduleTourMixin
    on ConsumerState<TeachingScheduleManagementScreen> {
  // Abstract getters for GlobalKeys
  GlobalKey get menuKey;
  GlobalKey get searchKey;
  GlobalKey get filterKey;
  GlobalKey get fabKey;
  GlobalKey get viewToggleKey;

  // Abstract getter/setter for tour visibility
  bool get isTourShowing;
  set isTourShowing(bool value);

  /// Checks cache for tour status and shows tour if needed
  Future<void> checkAndShowTour() async {
    if (isTourShowing) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'schedule_management',
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
      AppLogger.error('schedule', e);
    }
  }

  /// Displays the tutorial coach mark for the admin schedule tour
  void showTour() {
    final List<TargetFocus> targets = createTourTargets();
    if (targets.isEmpty) return;

    setState(() => isTourShowing = true);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: ref.read(languageRiverpod).getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: completeTour,
      onSkip: () {
        completeTour();
        return true;
      },
      onClickOverlay: (_) {},
    ).show(context: context);
  }

  /// Marks the tour as complete in API and cache
  void completeTour() {
    setState(() => isTourShowing = false);
    getIt<ApiTourService>().completeTour(
      name: 'teaching_schedule_management_tour',
      role: 'admin',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('schedule_management', 'admin'),
      {'should_show': false},
    );
  }

  /// Creates tour targets for the schedule management screen
  List<TargetFocus> createTourTargets() => ScheduleTourTargetBuilder.build(
    viewToggleKey: viewToggleKey,
    menuKey: menuKey,
    searchKey: searchKey,
    filterKey: filterKey,
    fabKey: fabKey,
    languageProvider: ref.read(languageRiverpod),
  );
}
