import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

/// Helper class for fetching dashboard data from APIs.
class DashboardDataFetcher {
  final Ref ref;

  DashboardDataFetcher(this.ref);

  /// Fetch all core dashboard data in a single API call.
  ///
  /// Replaces 5 separate parallel calls (stats, schools, roles,
  /// teacher data, semester label) with one `GET /dashboard/full` request.
  /// Charts and finance stats remain separate due to their complex parameters.
  Future<Map<String, dynamic>> fetchDashboardFull(
    String role,
    String? academicYearId,
  ) async {
    try {
      final queryParams = <String, dynamic>{'role': role};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }

      final response = await dioClient.get(
        '/dashboard/full',
        queryParameters: queryParams,
      );

      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        return Map<String, dynamic>.from(result['data'] ?? {});
      }
      return {};
    } catch (e) {
      AppLogger.error('dashboard_data_fetcher', 'Error fetching /dashboard/full: $e');
      return {};
    }
  }

  /// Process teacher data from /dashboard/full response.
  /// Sets up the TeacherProvider with fetched data, matching what
  /// fetchTeacherSpecificData used to do with separate API calls.
  Map<String, dynamic>? processTeacherData(
    Map<String, dynamic> fullData,
    Map<String, dynamic>? userData,
  ) {
    final teacherData = fullData['teacher_data'];
    if (teacherData == null || userData == null) return null;

    try {
      final teacher = teacherData['teacher'] as Map<String, dynamic>?;
      if (teacher == null) return null;

      final teacherId = teacher['id']?.toString() ?? '';
      final userId = (userData['user_id'] ?? userData['id']).toString();

      final updatedUserData = {
        ...userData,
        ...teacher,
        'id': userId,
        'user_id': userId,
        'teacher_id': teacherId,
      };

      final allClasses = List<dynamic>.from(teacherData['classes'] ?? []);
      final homeroomClasses = List<dynamic>.from(
        teacherData['homeroom_classes'] ?? [],
      );

      // Update TeacherProvider
      ref.read(teacherRiverpod).setTeacherData(
        userId: userId,
        teacherId: teacherId,
        teacherName: updatedUserData['nama'] ?? 'Guru',
        teacherData: updatedUserData,
        allClasses: allClasses,
        homeroomClasses: homeroomClasses,
      );

      return {'userData': updatedUserData, 'homeroomClasses': homeroomClasses};
    } catch (e) {
      AppLogger.error(
        'dashboard_data_fetcher',
        'Error processing teacher data: $e',
      );
      return null;
    }
  }

  /// Fetch chart data based on role and academic year.
  Future<Map<String, dynamic>> fetchChartData(
    String role,
    String? yearId,
  ) async {
    List<Map<String, dynamic>>? attendance;
    List<Map<String, dynamic>>? finance;

    if (role == 'admin' || role == 'wali') {
      final now = DateTime.now();
      final month = _getMonthName(now.month);
      final week = 'Pekan ${(now.day / 7).ceil().clamp(1, 5)}';

      final attendanceData =
          await AttendanceService.getAttendanceDashboardChart(
            academicYearId: yearId,
            month: month,
            week: week,
            role: role == 'wali' ? role : null,
          );
      attendance = List<Map<String, dynamic>>.from(attendanceData);

      if (role == 'admin') {
        final financeData = await FinanceService.getFinanceDashboardChart(
          academicYearId: yearId,
        );
        finance = List<Map<String, dynamic>>.from(financeData);
      }
    }
    return {'attendance': attendance, 'finance': finance};
  }

  /// Fetch unverified payment count. Returns count or null.
  Future<int?> fetchFinanceStats(String role) async {
    if (role != 'admin') return null;
    try {
      final financeStats = await FinanceService.getFinanceDashboardStats();
      return int.tryParse(
            financeStats['pembayaran_pending']?.toString() ?? '0',
          ) ??
          0;
    } catch (e) {
      AppLogger.error(
        'dashboard_data_fetcher',
        'Error fetching finance stats: $e',
      );
    }
    return null;
  }

  /// Prefetch tours for the platform.
  Future<void> prefetchTours(String role) async {
    try {
      await ApiTourService.getCompletedTours(platform: 'mobile');
    } catch (e) {
      AppLogger.error('dashboard_data_fetcher', 'Error prefetching tours: $e');
    }
  }

  /// Prefetch schedule data for the current week so the Schedule
  /// screen loads instantly when a teacher navigates to it.
  Future<void> prefetchScheduleData(String? academicYearId) async {
    try {
      final tp = ref.read(teacherRiverpod);
      final teacherId = tp.teacherId;
      if (teacherId == null || teacherId.isEmpty) return;

      // Prefetch week summary (the main data the schedule screen needs)
      await getIt<ApiScheduleService>().getWeekSummary(
        teacherId: teacherId,
        academicYearId: academicYearId,
      );
      AppLogger.debug(
        'dashboard_data_fetcher',
        'Prefetched schedule week summary for teacher $teacherId',
      );
    } catch (e) {
      // Prefetch failures are non-critical — silently ignore
      AppLogger.debug(
        'dashboard_data_fetcher',
        'Schedule prefetch skipped: $e',
      );
    }
  }

  /// Lightweight stats-only fetch for refreshStats().
  /// Uses the individual /dashboard/stats endpoint (not /dashboard/full).
  Future<Map<String, dynamic>> getDashboardStats(
    String role,
    String? academicYearId,
  ) => DashboardService.getDashboardStats(
    role: role,
    academicYearId: academicYearId,
  );

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }
}
