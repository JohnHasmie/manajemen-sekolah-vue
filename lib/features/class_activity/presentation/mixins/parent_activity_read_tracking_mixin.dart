import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';

mixin ParentActivityReadTrackingMixin
    on ConsumerState<ParentClassActivityScreen> {
  void onItemVisible(Map<String, dynamic> activity) {
    final state = this as dynamic;
    if (!state._hasFreshData) return;

    final id = activity['id'].toString();
    final isRead =
        activity['is_read'] == true ||
        activity['is_read'] == 1 ||
        activity['is_read'] == '1';

    if (!isRead && !state._processedIds.contains(id)) {
      state._processedIds.add(id);
      state._pendingReadIds.add(id);
      scheduleMarkRead();
    }
  }

  void scheduleMarkRead() {
    final state = this as dynamic;
    if (state._markReadDebounce?.isActive ?? false) return;

    state._markReadDebounce = Timer(const Duration(seconds: 1), () {
      if (state._pendingReadIds.isNotEmpty) {
        final idsToMark = state._pendingReadIds.toList();
        state._pendingReadIds.clear();
        flushMarkRead(idsToMark);
      }
    });
  }

  Future<void> flushMarkRead(List<String> ids) async {
    try {
      AppLogger.debug(
        'class_activity',
        'Auto-marking ${ids.length} visible class activities as read...',
      );

      final state = this as dynamic;
      setState(() {
        for (final item in state._activityList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      final cacheKey = (this as dynamic).buildActivitiesCacheKey();
      await LocalCacheService.save(cacheKey, state._activityList);

      await getIt<ApiClassActivityService>().markAsRead(ids);
    } catch (e) {
      AppLogger.error('class_activity', 'Error auto-marking read: $e');
    }
  }
}
