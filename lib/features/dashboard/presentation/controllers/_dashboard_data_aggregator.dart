import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/_dashboard_state_transformer.dart';

/// Helper for aggregating and applying fetched data to state.
class DashboardDataAggregator {
  /// Apply all fetched results to current state.
  static DashboardState applyFetchResults(
    DashboardState? currentState,
    Map<String, dynamic> dashboardData,
    Map<String, dynamic> charts,
    List<dynamic> schools,
    List<dynamic> roles,
    Map<String, dynamic>? teacherResult,
    String? semesterLabel,
    int? financeCount,
    String normalizedRole,
  ) {
    var newState =
        currentState?.copyWith(
          accessibleSchools: schools,
          availableRoles: roles,
          attendanceChartData: charts['attendance'],
          financeChartData: charts['finance'],
          isStatsLoaded: true,
        ) ??
        const DashboardState();

    // Apply teacher-specific data
    if (teacherResult != null) {
      newState = _applyTeacherData(newState, teacherResult);
    }

    // Apply semester label
    if (semesterLabel != null) {
      newState = newState.copyWith(currentSemesterLabel: semesterLabel);
    }

    // Apply finance count
    if (financeCount != null) {
      newState = newState.copyWith(unverifiedPaymentCount: financeCount);
    }

    // Apply stats transformation
    newState = DashboardStateTransformer.applyStatsToState(
      newState,
      dashboardData,
      normalizedRole,
    );

    return newState;
  }

  static DashboardState _applyTeacherData(
    DashboardState state,
    Map<String, dynamic> teacherResult,
  ) {
    return state.copyWith(
      userData: teacherResult['userData'] as Map<String, dynamic>,
      user: User.fromJson(teacherResult['userData'] as Map<String, dynamic>),
      homeroomClasses: teacherResult['homeroomClasses'] as List<dynamic>,
    );
  }
}
