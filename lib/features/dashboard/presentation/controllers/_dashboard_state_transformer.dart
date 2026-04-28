import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// Helper class for transforming and applying dashboard data to state.
class DashboardStateTransformer {
  /// Safely parse a value to int.
  static int toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  /// Apply stats data to dashboard state based on role.
  static DashboardState applyStatsToState(
    DashboardState currentState,
    Map<String, dynamic> data, [
    String? role,
  ]) {
    final effectiveRole = role ?? _effectiveRoleFromState(currentState);
    final stats = {...currentState.stats};
    List<dynamic> todaysSchedule = currentState.todaysSchedule;
    List<dynamic> materialOverview = currentState.materialOverview;

    if (effectiveRole == 'guru') {
      _applyTeacherStats(
        data,
        stats,
        (schedules) => todaysSchedule = schedules,
        (materials) => materialOverview = materials,
      );
    } else if (effectiveRole == 'admin') {
      _applyAdminStats(data, stats);
    } else if (effectiveRole == 'wali') {
      _applyParentStats(data, stats);
    }

    return currentState.copyWith(
      stats: stats,
      todaysSchedule: todaysSchedule,
      materialOverview: materialOverview,
    );
  }

  static void _applyTeacherStats(
    Map<String, dynamic> data,
    Map<String, dynamic> stats,
    Function(List<dynamic>) scheduleCallback,
    Function(List<dynamic>) materialCallback,
  ) {
    scheduleCallback(List<dynamic>.from(data['todays_schedule'] ?? []));
    materialCallback(List<dynamic>.from(data['material_overview'] ?? []));

    stats
      ..['total_students'] = toInt(
        data['total_students'] ?? data['total_siswa'],
      )
      ..['total_classes'] = toInt(data['total_classes'] ?? data['total_kelas'])
      ..['classes_today'] = toInt(
        data['classes_today'] ?? data['kelas_hari_ini'],
      )
      ..['total_materials'] = toInt(
        data['total_materials'] ?? data['total_materi'],
      )
      ..['total_rpps'] = toInt(data['total_rpps'] ?? data['total_rpp'])
      ..['rpp_approved'] = toInt(data['rpp_approved'])
      ..['rpp_rejected'] = toInt(data['rpp_rejected'])
      ..['rpp_pending'] = toInt(data['rpp_pending'])
      ..['attendance_summary'] = data['attendance_summary'] is Map
          ? data['attendance_summary']
          : {}
      ..['unread_notifications'] = toInt(data['unread_notifications'])
      ..['unread_announcements'] = toInt(data['unread_announcements'])
      ..['unread_class_activities'] = toInt(data['unread_class_activities']);
  }

  static void _applyAdminStats(
    Map<String, dynamic> data,
    Map<String, dynamic> stats,
  ) {
    stats
      ..['total_students'] = toInt(
        data['total_students'] ?? data['total_siswa'],
      )
      ..['total_teachers'] = toInt(data['total_teachers'] ?? data['total_guru'])
      ..['total_classes'] = toInt(data['total_classes'] ?? data['total_kelas'])
      ..['total_subjects'] = toInt(
        data['total_subjects'] ?? data['total_mapel'],
      )
      // Phase 3 hero KPI + inbox aggregates
      ..['attendance_rate_today'] = toInt(data['attendance_rate_today'])
      ..['attendance_delta_pct'] = toInt(data['attendance_delta_pct'])
      ..['pending_lesson_plans'] = toInt(data['pending_lesson_plans'])
      ..['draft_announcements'] = toInt(data['draft_announcements'])
      ..['overdue_bills'] = toInt(data['overdue_bills'])
      ..['unread_notifications'] = toInt(data['unread_notifications'])
      ..['unread_announcements'] = toInt(data['unread_announcements'])
      ..['unread_class_activities'] = toInt(data['unread_class_activities']);
  }

  static void _applyParentStats(
    Map<String, dynamic> data,
    Map<String, dynamic> stats,
  ) {
    stats
      ..['children_registered'] = toInt(
        data['children_registered'] ?? data['anak_terdaftar'],
      )
      ..['unread_notifications'] = toInt(data['unread_notifications'])
      ..['unread_announcements'] = toInt(data['unread_announcements'])
      ..['unread_class_activities'] = toInt(data['unread_class_activities'])
      ..['unread_grades'] = toInt(data['unread_grades'])
      ..['unread_presence'] = toInt(data['unread_presence'])
      ..['unread_billings'] = toInt(
        data['unread_billings'] ?? data['unread_billing'],
      );
  }

  static String _effectiveRoleFromState(DashboardState state) {
    final role = state.userData['role']?.toString() ?? 'admin';
    if (role == 'teacher') return 'guru';
    if (role == 'parent') return 'wali';
    return role;
  }

  /// Normalize role name (teacher -> guru, parent -> wali).
  static String normalizeRole(String role) {
    if (role == 'teacher') return 'guru';
    if (role == 'parent') return 'wali';
    return role;
  }
}
