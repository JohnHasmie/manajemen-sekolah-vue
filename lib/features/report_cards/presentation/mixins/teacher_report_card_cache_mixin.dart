import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';

/// Mixin for cache key building and cache operations.
mixin TeacherReportCardCacheMixin on ConsumerState<ReportCardScreen> {
  String? _getAcademicYearId() {
    final provider = ref.read(academicYearRiverpod);
    return (provider.selectedAcademicYear?['id'] ??
            provider.activeAcademicYear?['id'])
        ?.toString();
  }

  String _buildClassesCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    return 'raport_classes_${getTeacherId()}_$academicYearId';
  }

  String _buildStudentsCacheKey() {
    final academicYearId = _getAcademicYearId() ?? '';
    final classId = getSelectedClassId();
    return 'raport_students_${classId}_$academicYearId';
  }

  Future<void> clearReportCardCache() async {
    await LocalCacheService.clearStartingWith('raport_');
    await LocalCacheService.clearStartingWith('tour_raport_');
  }

  // Abstract methods to be implemented in state class
  String getTeacherId();
  String getSelectedClassId();
}
