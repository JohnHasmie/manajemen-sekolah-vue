/// schedule_kpi_summary.dart — Snapshot returned by
/// GET /teaching-schedule/stats for the admin Jadwal KPI strip.
///
/// The backend already returned `total`, `total_teachers`, `total_classes`,
/// and `total_subjects` before the redesign. The TR.1 backend patch added
/// `today` (count of sessions scheduled for the day_name that matches the
/// server's current day) and `conflicts` (count of rows in a slot+teacher
/// or slot+class collision). This class normalizes both legacy and new
/// shapes so callers don't need to null-check.
library;

class ScheduleKpiSummary {
  /// Total schedules in the scoped query (school+filters).
  final int total;

  /// Count of schedules whose day matches today (server-side).
  /// Drives the "Hari Ini" KPI cell on the redesigned hub.
  final int today;

  /// Count of rows involved in a slot conflict (teacher- or class-collision
  /// at the same lesson_hour_days_id within the same semester+academic_year).
  /// Drives the red "Bentrok" KPI cell on the redesigned hub.
  final int conflicts;

  /// Distinct teachers represented in the result set. Used by the
  /// (legacy) admin schedule stats card on dashboards that haven't been
  /// migrated to the new KPI strip yet.
  final int totalTeachers;

  /// Distinct classes represented in the result set.
  final int totalClasses;

  /// Distinct subjects represented in the result set.
  final int totalSubjects;

  const ScheduleKpiSummary({
    required this.total,
    required this.today,
    required this.conflicts,
    required this.totalTeachers,
    required this.totalClasses,
    required this.totalSubjects,
  });

  /// Empty snapshot — used as a placeholder before the first fetch
  /// completes so the KPI strip can render `—` without flickering.
  const ScheduleKpiSummary.empty()
      : total = 0,
        today = 0,
        conflicts = 0,
        totalTeachers = 0,
        totalClasses = 0,
        totalSubjects = 0;

  factory ScheduleKpiSummary.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return ScheduleKpiSummary(
      total: asInt(json['total']),
      today: asInt(json['today']),
      conflicts: asInt(json['conflicts']),
      totalTeachers: asInt(json['total_teachers'] ?? json['totalTeachers']),
      totalClasses: asInt(json['total_classes'] ?? json['totalClasses']),
      totalSubjects: asInt(json['total_subjects'] ?? json['totalSubjects']),
    );
  }
}

/// Reads `conflict_with` from a raw schedule JSON map. The backend
/// attaches this per-row in TR.2 so the redesigned grid / list can
/// render BENTROK pills on first paint without a second round-trip.
///
/// Always returns a `List<String>` — empty when the row has no
/// conflicts or the field is absent (older clients on stale cache).
extension ScheduleConflictJson on Map<String, dynamic> {
  List<String> get conflictWithIds {
    final raw = this['conflict_with'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  /// True when the row is in conflict with at least one other schedule.
  bool get hasScheduleConflict => conflictWithIds.isNotEmpty;
}
