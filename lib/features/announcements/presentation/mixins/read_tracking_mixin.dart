import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for tracking announcement visibility and marking read.
///
/// Implements a debounced "mark as read" pattern: when items become
/// visible, their IDs are queued. After 1 second of no new items,
/// all queued IDs are sent to the API in one batch.
mixin ReadTrackingMixin on ConsumerState<ParentAnnouncementScreen> {
  final Set<String> processedIds = {};
  final Set<String> pendingReadIds = {};
  Timer? markReadDebounce;

  List<dynamic> get announcementList;

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
        'Auto-marking ${ids.length} visible announcements as read...',
      );

      setState(() {
        for (final item in announcementList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await AnnouncementService.markAnnouncementRead(ids);
    } catch (e) {
      AppLogger.error('announcement', e);
    }
  }

  Future<void> flushPendingReads() async {
    markReadDebounce?.cancel();
    if (pendingReadIds.isEmpty) return;
    final ids = pendingReadIds.toList();
    pendingReadIds.clear();
    try {
      await AnnouncementService.markAnnouncementRead(ids);
    } catch (e) {
      AppLogger.error('announcement', e);
    }
  }

  @override
  void dispose() {
    markReadDebounce?.cancel();
    super.dispose();
  }
}
