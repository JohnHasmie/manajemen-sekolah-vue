import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';

/// Mixin for visibility-based read tracking.
///
/// Handles debounced marking of grades as read when scrolled into view.
mixin ParentGradeReadTrackingMixin on ConsumerState<ParentGradeScreen> {
  // Visibility Tracking
  final Set<String> _processedIds = {};
  final Set<String> _pendingReadIds = {};
  Timer? _markReadDebounce;

  /// Called when an item becomes visible in the list.
  void onItemVisible(Map<String, dynamic> grade) {
    final id = grade['id'].toString();
    final isRead =
        grade['is_read'] == true ||
        grade['is_read'] == 1 ||
        grade['is_read'] == '1';

    if (!isRead && !_processedIds.contains(id)) {
      _processedIds.add(id);
      _pendingReadIds.add(id);
      _scheduleMarkRead();
    }
  }

  /// Schedule debounced flush of pending read markers.
  void _scheduleMarkRead() {
    if (_markReadDebounce?.isActive ?? false) return;

    _markReadDebounce = Timer(const Duration(seconds: 1), () {
      if (_pendingReadIds.isNotEmpty) {
        final idsToMark = _pendingReadIds.toList();
        _pendingReadIds.clear();
        _flushMarkRead(idsToMark);
      }
    });
  }

  /// Flush pending IDs to API with optimistic UI update.
  Future<void> _flushMarkRead(List<String> ids) async {
    try {
      AppLogger.debug(
        'grades',
        'Auto-marking ${ids.length} visible grades as read...',
      );

      await GradeService.markGradeAsRead(ids);
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  /// Flush pending IDs silently (no UI update) on dispose.
  Future<void> flushMarkReadSilently(List<String> ids) async {
    try {
      await GradeService.markGradeAsRead(ids);
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  /// Clean up debounce timer and flush remaining pending IDs.
  void disposeReadTracking() {
    _markReadDebounce?.cancel();
    if (_pendingReadIds.isNotEmpty) {
      flushMarkReadSilently(List.from(_pendingReadIds));
      _pendingReadIds.clear();
    }
  }
}
