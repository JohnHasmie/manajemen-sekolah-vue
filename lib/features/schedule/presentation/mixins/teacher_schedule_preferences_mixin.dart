import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

/// Mixin for view preferences and caching.
mixin TeacherSchedulePreferencesMixin on ConsumerState<TeachingScheduleScreen> {
  bool isTableViewInternal = false;

  Future<void> loadViewPreference() async {
    try {
      final cached = await LocalCacheService.load('schedule_view_preference');
      if (cached != null && cached is Map && mounted) {
        setState(() {
          isTableViewInternal = cached['is_table_view'] ?? false;
        });
      }
    } catch (e) {
      AppLogger.error('schedule', 'Error loading view preference: $e');
    }
  }

  void toggleView() {
    setState(() {
      isTableViewInternal = !isTableViewInternal;
    });
    LocalCacheService.save('schedule_view_preference', {
      'is_table_view': isTableViewInternal,
    });
  }

  bool get isTableView => isTableViewInternal;
  set isTableView(bool v) => isTableViewInternal = v;
}
