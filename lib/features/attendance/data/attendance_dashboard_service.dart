// Wrapper around the admin Kehadiran dashboard endpoint
// (Mockup #11). Returns typed [AttendanceDashboard] with the ring,
// KPI strip series, and per-tingkat trend data.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/widgets/admin_attendance_components.dart';

class AttendanceDashboard {
  final AttendanceBreakdown breakdown;
  final double avgPct;
  final int absentCount;
  final int absentDelta;
  final List<double> kpiSparkline;
  final List<TingkatTrend> tingkats;
  final String rangeLabel;

  const AttendanceDashboard({
    required this.breakdown,
    required this.avgPct,
    required this.absentCount,
    required this.absentDelta,
    required this.kpiSparkline,
    required this.tingkats,
    required this.rangeLabel,
  });
}

class TingkatTrend {
  final int tingkat;
  final double currentPct;
  final double deltaPct;
  final List<double> series;
  final String? alertCopy;

  const TingkatTrend({
    required this.tingkat,
    required this.currentPct,
    required this.deltaPct,
    required this.series,
    this.alertCopy,
  });
}

class AttendanceDashboardService {
  final ApiService _api;
  AttendanceDashboardService(this._api);

  /// GET /api/attendance/dashboard-summary?range=today|week|month
  Future<AttendanceDashboard> fetch({String range = 'today'}) async {
    final raw = await _api.get('/attendance/dashboard-summary?range=$range');
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};

    final totals = Map<String, dynamic>.from(
      (data['totals'] as Map?) ?? const {},
    );
    final kpi = Map<String, dynamic>.from((data['kpi'] as Map?) ?? const {});
    final tingkatRaw = (data['tingkats'] as List?) ?? const <dynamic>[];

    return AttendanceDashboard(
      breakdown: AttendanceBreakdown(
        present: (totals['present'] as num?)?.toInt() ?? 0,
        excused: (totals['excused'] as num?)?.toInt() ?? 0,
        sick: (totals['sick'] as num?)?.toInt() ?? 0,
        // Backend canonical: `absent` (was `alpha`/`alpa`).
        alpha:
            (totals['absent'] as num?)?.toInt() ??
            (totals['alpha'] as num?)?.toInt() ??
            0,
        presentPct: (totals['present_pct'] as num?)?.toDouble() ?? 0,
      ),
      avgPct: (kpi['avg_pct'] as num?)?.toDouble() ?? 0,
      absentCount: (kpi['absent_count'] as num?)?.toInt() ?? 0,
      absentDelta: (kpi['absent_delta'] as num?)?.toInt() ?? 0,
      kpiSparkline: (kpi['sparkline'] as List? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      tingkats: tingkatRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(
            (m) => TingkatTrend(
              tingkat: (m['tingkat'] as num?)?.toInt() ?? 0,
              currentPct: (m['current_pct'] as num?)?.toDouble() ?? 0,
              deltaPct: (m['delta_pct'] as num?)?.toDouble() ?? 0,
              series: (m['series'] as List? ?? const [])
                  .map((e) => (e as num).toDouble())
                  .toList(),
              alertCopy: m['alert_copy']?.toString(),
            ),
          )
          .toList(),
      rangeLabel: (data['range_label'] ?? '').toString(),
    );
  }
}

// =====================================================================
// Per-student heatmap (Mockup #12)
// =====================================================================

class StudentHeatmapEntry {
  final String id;
  final String name;
  final String? studentNumber;
  final List<CellState> cells;
  final double monthlyPct;
  final int presentDays;
  final int totalDays;
  final bool alert;
  final String? alertCopy;

  const StudentHeatmapEntry({
    required this.id,
    required this.name,
    this.studentNumber,
    required this.cells,
    required this.monthlyPct,
    required this.presentDays,
    required this.totalDays,
    required this.alert,
    this.alertCopy,
  });
}

class StudentHeatmapResult {
  final int days;
  final String startDate;
  final String endDate;
  final List<StudentHeatmapEntry> students;

  const StudentHeatmapResult({
    required this.days,
    required this.startDate,
    required this.endDate,
    required this.students,
  });
}

CellState _parseCellState(String? raw) {
  // Backend canonical attendance statuses: `present` / `sick` /
  // `excused` / `absent` / `late`. Legacy `alpha` / `alpa` still
  // accepted for back-compat.
  switch (raw?.toLowerCase()) {
    case 'present':
      return CellState.present;
    case 'excused':
      return CellState.excused;
    case 'sick':
      return CellState.sick;
    case 'absent':
    case 'alpha':
    case 'alpa':
      return CellState.alpha;
    case 'holiday':
      return CellState.holiday;
    default:
      return CellState.none;
  }
}

extension StudentHeatmapFetch on AttendanceDashboardService {
  /// GET /api/attendance/student-heatmap
  ///
  /// One of [tingkat] or [classId] should be passed; if both are
  /// null the backend returns the school-wide set (capped at 60).
  Future<StudentHeatmapResult> fetchStudentHeatmap({
    int? tingkat,
    String? classId,
    int days = 30,
  }) async {
    final params = <String, String>{'days': days.toString()};
    if (tingkat != null) params['tingkat'] = tingkat.toString();
    if (classId != null) params['class_id'] = classId;
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final raw = await _api.get('/attendance/student-heatmap?$qs');
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};

    final students = (data['students'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(
          (m) => StudentHeatmapEntry(
            id: (m['id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            studentNumber: m['student_number']?.toString(),
            cells: (m['cells'] as List? ?? const [])
                .map((c) => _parseCellState(c?.toString()))
                .toList(),
            monthlyPct: (m['monthly_pct'] as num?)?.toDouble() ?? 0,
            presentDays: (m['present_days'] as num?)?.toInt() ?? 0,
            totalDays: (m['total_days'] as num?)?.toInt() ?? 0,
            alert: (m['alert'] as bool?) ?? false,
            alertCopy: m['alert_copy']?.toString(),
          ),
        )
        .toList();

    return StudentHeatmapResult(
      days: (data['days'] as num?)?.toInt() ?? days,
      startDate: (data['start_date'] ?? '').toString(),
      endDate: (data['end_date'] ?? '').toString(),
      students: students,
    );
  }
}

class HeatmapScope {
  final int? tingkat;
  final String? classId;
  final int days;
  const HeatmapScope({this.tingkat, this.classId, this.days = 30});

  @override
  bool operator ==(Object other) =>
      other is HeatmapScope &&
      other.tingkat == tingkat &&
      other.classId == classId &&
      other.days == days;

  @override
  int get hashCode => Object.hash(tingkat, classId, days);
}

final studentHeatmapProvider = FutureProvider.autoDispose
    .family<StudentHeatmapResult, HeatmapScope>((ref, scope) async {
      return ref
          .read(attendanceDashboardServiceProvider)
          .fetchStudentHeatmap(
            tingkat: scope.tingkat,
            classId: scope.classId,
            days: scope.days,
          );
    });

// =====================================================================
// Riverpod
// =====================================================================

final attendanceDashboardServiceProvider = Provider<AttendanceDashboardService>(
  (ref) {
    return AttendanceDashboardService(ApiService());
  },
);

/// Family provider keyed by the active [AttendanceRange]. Switching
/// the chip in the hero invalidates the auto-disposed instance and
/// re-fetches.
final attendanceDashboardProvider = FutureProvider.autoDispose
    .family<AttendanceDashboard, AttendanceRange>((ref, range) async {
      final slug = switch (range) {
        AttendanceRange.thisWeek => 'week',
        AttendanceRange.thisMonth => 'month',
        _ => 'today',
      };
      return ref.read(attendanceDashboardServiceProvider).fetch(range: slug);
    });
