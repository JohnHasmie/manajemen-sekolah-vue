import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';

/// Provider for the Lesson Plan Service to allow easier mocking and dependency injection.
final lessonPlanServiceProvider = Provider<LessonPlanService>((ref) {
  return LessonPlanService();
});

/// A lightweight AsyncNotifier to manage global Lesson Plan invalidations
/// or generic listing states if needed across multiple screens.
///
/// Note: Complex pagination and form states are currently retained in their respective
/// ConsumerStatefulWidgets (Admin & Teacher RPP Screens) to avoid prop drilling
/// massive multipart file upload states.
class LessonPlanController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state does nothing, acts as a command controller
  }

  /// Example of delegating mutations through Riverpod instead of static classes
  Future<void> updateStatus(
    String lessonPlanId,
    String status, {
    String? catatan,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await LessonPlanService.updateLessonPlanStatus(
        lessonPlanId,
        status,
        catatan: catatan,
      );
    });
  }
}

final lessonPlanControllerProvider =
    AsyncNotifierProvider.autoDispose<LessonPlanController, void>(() {
      return LessonPlanController();
    });
