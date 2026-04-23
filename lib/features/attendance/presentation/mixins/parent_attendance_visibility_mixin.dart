import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_state_mixin.dart';

/// Tracks visibility and manages mark-as-read for attendance items.
mixin ParentAttendanceVisibilityMixin
    on ConsumerState<ParentAttendanceScreen>, ParentAttendanceStateMixin {
  late Set<String> processedIds;
  late Set<String> pendingReadIds;
  Timer? markReadDebounce;

  @override
  void initState() {
    super.initState();
    processedIds = {};
    pendingReadIds = {};
  }

  @override
  void dispose() {
    markReadDebounce?.cancel();
    if (pendingReadIds.isNotEmpty) {
      flushMarkReadSilently(List.from(pendingReadIds));
      pendingReadIds.clear();
    }
    super.dispose();
  }

  Future<void> flushMarkReadSilently(List<String> ids) async {
    try {
      await AttendanceService.markPresenceAsRead(ids);
    } catch (e) {
      AppLogger.error('attendance', e);
    }
  }

  void onItemVisible(Attendance record) {
    final id = record.id;
    final isRead = record.isRead;

    if (!isRead && !processedIds.contains(id)) {
      processedIds.add(id);
      pendingReadIds.add(id);
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
        'attendance',
        'Auto-marking ${ids.length} visible presence as read...',
      );

      if (!mounted) return;
      updateAttendanceRead(ids);

      await AttendanceService.markPresenceAsRead(ids);
    } catch (e) {
      AppLogger.error('attendance', e);
    }
  }
}
