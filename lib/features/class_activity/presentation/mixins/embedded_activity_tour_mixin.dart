import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/class_activity_tour.dart';

/// Handles tour display logic.
mixin EmbeddedActivityTourMixin on ConsumerState<EmbeddedActivityListScreen> {
  // Abstract declarations for fields from state class
  GlobalKey get tabSwitcherKey;
  GlobalKey get searchFilterKey;
  GlobalKey get fabKey;

  Future<void> checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'class_activity_screen',
        'guru',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map && cached['should_show'] == true) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showTour();
          });
        }
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error checking tour status: $e');
    }
  }

  void showTour() {
    showClassActivityTour(
      context: context,
      targets: buildClassActivityTourTargets(
        tabSwitcherKey: tabSwitcherKey,
        searchFilterKey: searchFilterKey,
        fabKey: fabKey,
        selectedSubjectCanEdit: widget.canEdit,
      ),
    );
  }
}
