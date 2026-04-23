import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';

/// Mixin for admin announcement read tracking.
///
/// Handles debounced batch marking of announcements as read
/// when they become visible in the viewport.
mixin AdminReadTrackingMixin on ConsumerState<AdminAnnouncementScreen> {
  final Set<String> processedIds = {};
  final Set<String> pendingReadIds = {};
  Timer? markReadDebounce;

  List<dynamic> get announcements;

  void onItemVisible(Map<String, dynamic> announcement) {
    final model = Announcement.fromJson(announcement);

    if (!model.isRead && !processedIds.contains(model.id)) {
      processedIds.add(model.id);
      pendingReadIds.add(model.id);
      scheduleMarkRead();
    }
  }

  void scheduleMarkRead() {
    if (markReadDebounce?.isActive ?? false) return;

    markReadDebounce = Timer(const Duration(seconds: 1), () {
      if (pendingReadIds.isNotEmpty) {
        final idsToMark = pendingReadIds.toList();
        pendingReadIds.clear();
        flushMarkRead(idsToMark);
      }
    });
  }

  Future<void> flushMarkRead(List<String> ids) async {
    try {
      AppLogger.debug(
        'announcement',
        'Admin Auto-marking ${ids.length} visible announcements as read...',
      );

      setState(() {
        for (final item in announcements) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await AnnouncementService.markAnnouncementRead(ids);
    } catch (e) {
      AppLogger.error('announcement', 'Error auto-marking read: $e');
    }
  }
}
