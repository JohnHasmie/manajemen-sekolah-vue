import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';

/// Mixin providing academic period helper methods for the
/// admin schedule controller.
mixin AcademicPeriodMixin {
  /// Determines the correct academic year ID from the list.
  /// Uses the API's "current" flag first, then date-based
  /// fallback. Returns the resolved ID.
  String setDefaultAcademicPeriod({
    required List<dynamic> availableAcademicYears,
  }) {
    if (availableAcademicYears.isEmpty) return '1';

    final currentFromApi = availableAcademicYears.firstWhere(
      (y) => y['current'] == true || y['current'] == 1,
      orElse: () => <String, dynamic>{},
    );

    if ((currentFromApi as Map).isNotEmpty) {
      return currentFromApi['id'].toString();
    }

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final targetYearString = currentMonth >= 7
        ? '$currentYear/${currentYear + 1}'
        : '${currentYear - 1}/$currentYear';

    final dateBasedYear = availableAcademicYears.firstWhere(
      (y) => (y['year'] ?? '').toString() == targetYearString,
      orElse: () => <String, dynamic>{},
    );

    if ((dateBasedYear as Map).isNotEmpty) {
      return dateBasedYear['id'].toString();
    }

    return availableAcademicYears.first['id'].toString();
  }

  /// Determines the correct semester ID to display.
  /// Uses the API's "current" flag first then a backend
  /// date-based lookup. Returns the resolved semester ID,
  /// or null if it matches the current selection.
  Future<String?> updateCurrentSemester({
    required List<dynamic> semesterList,
    required String currentSemesterId,
  }) async {
    if (semesterList.isEmpty) return null;

    String? semesterId;

    final currentFromApi = semesterList.firstWhere(
      (s) => s['current'] == true || s['current'] == 1,
      orElse: () => <String, dynamic>{},
    );

    if ((currentFromApi as Map).isNotEmpty) {
      semesterId = currentFromApi['id'].toString();
    } else {
      try {
        final result = await getIt<ApiScheduleService>().getDateBasedSemester();
        if (result.isNotEmpty && result.containsKey('semester')) {
          final targetSemesterName = result['semester'].toString();
          final dateBasedSemester = semesterList.firstWhere((s) {
            final name = (s['name'] ?? s['nama'] ?? '').toString();
            return name.contains(targetSemesterName);
          }, orElse: () => <String, dynamic>{});

          if ((dateBasedSemester as Map).isNotEmpty) {
            semesterId = dateBasedSemester['id'].toString();
          }
        }
      } catch (e) {
        AppLogger.error('schedule', e);
      }

      semesterId ??= semesterList.first['id'].toString();
    }

    if (semesterId != currentSemesterId) {
      AppLogger.debug(
        'schedule',
        'DEBUG: Auto-switching to semester: '
            '$semesterId',
      );
      return semesterId;
    }
    return null;
  }
}
