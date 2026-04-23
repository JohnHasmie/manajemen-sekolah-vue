import 'dart:convert';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// Helper class for cache operations.
class DashboardCacheManager {
  /// Load cached state from local storage.
  static Future<DashboardState> loadLocalCache(String role) async {
    final prefs = PreferencesService();
    final userString = prefs.getString('user');
    final lastYearId = prefs.getString('dashboard_last_year_id');

    Map<String, dynamic> userData = {};
    User? user;
    if (userString != null) {
      userData = json.decode(userString);
      user = User.fromJson(userData);
    }

    final schoolId = userData['school_id']?.toString() ?? 'default';
    final normRole = _normalizeRole(role);
    final yearId = lastYearId ?? 'default';
    final cacheKeyBase = 'dashboard_${normRole}_${schoolId}_$yearId';

    final cachedStats = await LocalCacheService.load('${cacheKeyBase}_stats');
    final cachedAttendance = await LocalCacheService.load(
      '${cacheKeyBase}_attendance_chart',
    );
    final cachedFinance = await LocalCacheService.load(
      '${cacheKeyBase}_finance_chart',
    );

    DashboardState cachedState = DashboardState(
      userData: userData,
      user: user,
      isLoading: false,
    );

    if (cachedStats != null) {
      cachedState = cachedState.copyWith(
        stats: Map<String, dynamic>.from(cachedStats),
      );
    }

    if (cachedAttendance != null) {
      cachedState = cachedState.copyWith(
        attendanceChartData: List<Map<String, dynamic>>.from(
          (cachedAttendance as List).map((e) => Map<String, dynamic>.from(e)),
        ),
      );
    }

    if (cachedFinance != null) {
      cachedState = cachedState.copyWith(
        financeChartData: List<Map<String, dynamic>>.from(
          (cachedFinance as List).map((e) => Map<String, dynamic>.from(e)),
        ),
      );
    }

    return cachedState;
  }

  /// Save dashboard data to cache.
  static void saveToCache(
    String role,
    String schoolId,
    String? academicYearId,
    Map<String, dynamic> dashboardData,
    Map<String, dynamic> charts,
  ) {
    final normRole = _normalizeRole(role);
    final yearId = academicYearId ?? 'default';
    final cacheKeyBase = 'dashboard_${normRole}_${schoolId}_$yearId';
    LocalCacheService.save('${cacheKeyBase}_stats', dashboardData);
    if (charts['attendance'] != null) {
      LocalCacheService.save(
        '${cacheKeyBase}_attendance_chart',
        charts['attendance'],
      );
    }
    if (charts['finance'] != null) {
      LocalCacheService.save(
        '${cacheKeyBase}_finance_chart',
        charts['finance'],
      );
    }
  }

  /// Update the last used academic year ID in preferences.
  static void updateLastAcademicYear(String academicYearId) {
    PreferencesService().setString('dashboard_last_year_id', academicYearId);
  }

  static String _normalizeRole(String role) {
    if (role == 'teacher') return 'guru';
    if (role == 'parent') return 'wali';
    return role;
  }
}
