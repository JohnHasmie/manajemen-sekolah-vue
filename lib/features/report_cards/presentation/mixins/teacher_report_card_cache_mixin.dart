import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';

/// Mixin for cache key building and cache operations.
mixin TeacherReportCardCacheMixin on ConsumerState<ReportCardScreen> {
  Future<void> clearReportCardCache() async {
    await LocalCacheService.clearStartingWith('raport_');
  }

  // Abstract methods to be implemented in state class
  String getTeacherId();
  String getSelectedClassId();
}
