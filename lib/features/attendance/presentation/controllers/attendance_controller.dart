import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';

/// Provider for the Attendance Service to allow easier mocking and dependency injection.
final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService();
});

/// A lightweight AsyncNotifier to manage global Attendance invalidations.
class AttendanceController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state does nothing, acts as a command controller
  }

  Future<void> markPresenceAsRead(List<String> attendanceIds) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await AttendanceService.markPresenceAsRead(attendanceIds);
    });
  }
}

final attendanceControllerProvider = AsyncNotifierProvider.autoDispose<AttendanceController, void>(() {
  return AttendanceController();
});
