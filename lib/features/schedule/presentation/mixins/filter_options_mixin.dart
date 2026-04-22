import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/services/filter_options_service.dart';

/// Result returned by [loadFilterOptions] method.
class FilterOptionsResult {
  final List<dynamic> teachers;
  final List<dynamic> classes;
  final List<dynamic> days;
  final List<dynamic> semesters;
  final List<dynamic> academicYears;

  const FilterOptionsResult({
    required this.teachers,
    required this.classes,
    required this.days,
    required this.semesters,
    required this.academicYears,
  });
}

/// Mixin providing filter options loading for the admin
/// schedule controller.
mixin FilterOptionsMixin {
  /// Fetches filter options via consolidated endpoint with caching.
  Future<FilterOptionsResult?> loadFilterOptions({
    required String selectedAcademicYear,
  }) async {
    try {
      final data = await FilterOptionsService.getFilterOptions(
        role: 'admin',
        academicYearId: selectedAcademicYear,
      );

      final result = FilterOptionsResult(
        teachers: List<dynamic>.from(data['teachers'] ?? []),
        classes: List<dynamic>.from(data['classes'] ?? []),
        days: List<dynamic>.from(data['days'] ?? []),
        semesters: List<dynamic>.from(data['semesters'] ?? []),
        academicYears: List<dynamic>.from(data['academic_years'] ?? []),
      );

      AppLogger.info('schedule', 'Schedule filter options loaded');
      return result;
    } catch (e) {
      AppLogger.error('schedule', e);
      return null;
    }
  }
}
