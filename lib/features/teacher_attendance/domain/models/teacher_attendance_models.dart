// teacher_attendance_models.dart — typed view of the "Presensi Guru"
// (teacher daily attendance) backend contract (backend MR !108).
//
// Why hand-written `fromJson` instead of freezed/json_serializable?
// Every other typed model in this app that needs codegen ships its
// `.g.dart` / `.freezed.dart` alongside, which means running
// build_runner. These DTOs are small and read-only, so we parse them by
// hand — like writing a Laravel API Resource's `toArray()` in reverse.
// The safe numeric/bool coercion helpers below mirror the defensive
// casting other models in this repo do (the API occasionally hands back
// a number as a String, or a 1/0 instead of true/false).
library;

/// One row of the teacher's daily teaching schedule, as surfaced by the
/// config endpoint's `today_schedule[]`. Think of it as a single class
/// period the teacher is booked for today — used only to *show* the
/// teacher what they're teaching and to anchor the "late after" line.
class TeacherTodaySchedule {
  final String? teachingScheduleId;
  final String? classId;
  final String? className;
  final String? subjectId;
  final String? subjectName;
  final String? lessonHourId;
  final String? lessonHourName;
  final int? hourNumber;
  final String? startTime; // "HH:mm" / "HH:mm:ss"
  final String? endTime;

  const TeacherTodaySchedule({
    this.teachingScheduleId,
    this.classId,
    this.className,
    this.subjectId,
    this.subjectName,
    this.lessonHourId,
    this.lessonHourName,
    this.hourNumber,
    this.startTime,
    this.endTime,
  });

  factory TeacherTodaySchedule.fromJson(Map<String, dynamic> json) {
    return TeacherTodaySchedule(
      teachingScheduleId: _asString(json['teaching_schedule_id']),
      classId: _asString(json['class_id']),
      className: _asString(json['class_name']),
      subjectId: _asString(json['subject_id']),
      subjectName: _asString(json['subject_name']),
      lessonHourId: _asString(json['lesson_hour_id']),
      lessonHourName: _asString(json['lesson_hour_name']),
      hourNumber: _asIntOrNull(json['hour_number']),
      startTime: _asString(json['start_time']),
      endTime: _asString(json['end_time']),
    );
  }
}

/// Per-school attendance configuration (camera/location requirements,
/// geofence, checkout toggle, late grace). Returned inside the config
/// payload's `settings` block and — in admin-editable form — by the
/// settings endpoint. Like a `school_settings` row scoped to presensi.
class TeacherAttendanceSettings {
  final bool cameraRequired;
  final bool locationRequired;
  final bool checkoutEnabled;
  final double? geofenceLat;
  final double? geofenceLng;
  final int geofenceRadiusM;
  final bool rejectOutsideGeofence;
  final int lateGraceMinutes;

  /// The centre the server actually verifies against (settings coords,
  /// falling back to the school pin). Present on the config payload.
  final double? effectiveGeofenceLat;
  final double? effectiveGeofenceLng;

  const TeacherAttendanceSettings({
    required this.cameraRequired,
    required this.locationRequired,
    required this.checkoutEnabled,
    this.geofenceLat,
    this.geofenceLng,
    required this.geofenceRadiusM,
    required this.rejectOutsideGeofence,
    required this.lateGraceMinutes,
    this.effectiveGeofenceLat,
    this.effectiveGeofenceLng,
  });

  factory TeacherAttendanceSettings.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceSettings(
      cameraRequired: _asBool(json['camera_required'], fallback: true),
      locationRequired: _asBool(json['location_required'], fallback: true),
      checkoutEnabled: _asBool(json['checkout_enabled'], fallback: false),
      geofenceLat: _asDoubleOrNull(json['geofence_lat']),
      geofenceLng: _asDoubleOrNull(json['geofence_lng']),
      geofenceRadiusM: _asIntOrNull(json['geofence_radius_m']) ?? 150,
      rejectOutsideGeofence: _asBool(
        json['reject_outside_geofence'],
        fallback: true,
      ),
      lateGraceMinutes: _asIntOrNull(json['late_grace_minutes']) ?? 0,
      effectiveGeofenceLat: _asDoubleOrNull(json['effective_geofence_lat']),
      effectiveGeofenceLng: _asDoubleOrNull(json['effective_geofence_lng']),
    );
  }

  /// True when the teacher must supply a live selfie at all.
  bool get needsCamera => cameraRequired;

  /// True when the teacher must supply a GPS fix at all.
  bool get needsLocation => locationRequired;
}

/// A single teacher-attendance record (TeacherAttendanceResource). The
/// canonical shape returned by check-in/out, the config's
/// `state.record`, history items, and admin list items. Only `status`
/// and the timestamps drive the UI; the rest is shown as detail.
class TeacherAttendanceRecord {
  final String id;
  final String? schoolId;
  final String? teacherId;
  final String? teachingScheduleId;
  final String? date; // "YYYY-MM-DD"
  final String status; // "present" | "late"

  final String? checkInAt; // ISO8601
  final String? checkInPhotoUrl;
  final double? checkInLat;
  final double? checkInLng;
  final int? checkInDistanceM;
  final bool checkInOutsideGeofence;

  final String? checkOutAt;
  final String? checkOutPhotoUrl;
  final double? checkOutLat;
  final double? checkOutLng;
  final int? checkOutDistanceM;
  final bool checkOutOutsideGeofence;

  final String? notes;

  /// Only populated on the admin list (whenLoaded teacher).
  final String? teacherName;
  final String? teacherEmployeeNumber;

  const TeacherAttendanceRecord({
    required this.id,
    this.schoolId,
    this.teacherId,
    this.teachingScheduleId,
    this.date,
    required this.status,
    this.checkInAt,
    this.checkInPhotoUrl,
    this.checkInLat,
    this.checkInLng,
    this.checkInDistanceM,
    this.checkInOutsideGeofence = false,
    this.checkOutAt,
    this.checkOutPhotoUrl,
    this.checkOutLat,
    this.checkOutLng,
    this.checkOutDistanceM,
    this.checkOutOutsideGeofence = false,
    this.notes,
    this.teacherName,
    this.teacherEmployeeNumber,
  });

  factory TeacherAttendanceRecord.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'];
    return TeacherAttendanceRecord(
      id: _asString(json['id']) ?? '',
      schoolId: _asString(json['school_id']),
      teacherId: _asString(json['teacher_id']),
      teachingScheduleId: _asString(json['teaching_schedule_id']),
      date: _asString(json['date']),
      status: _asString(json['status']) ?? 'present',
      checkInAt: _asString(json['check_in_at']),
      checkInPhotoUrl: _asString(json['check_in_photo_url']),
      checkInLat: _asDoubleOrNull(json['check_in_lat']),
      checkInLng: _asDoubleOrNull(json['check_in_lng']),
      checkInDistanceM: _asIntOrNull(json['check_in_distance_m']),
      checkInOutsideGeofence: _asBool(json['check_in_outside_geofence']),
      checkOutAt: _asString(json['check_out_at']),
      checkOutPhotoUrl: _asString(json['check_out_photo_url']),
      checkOutLat: _asDoubleOrNull(json['check_out_lat']),
      checkOutLng: _asDoubleOrNull(json['check_out_lng']),
      checkOutDistanceM: _asIntOrNull(json['check_out_distance_m']),
      checkOutOutsideGeofence: _asBool(json['check_out_outside_geofence']),
      notes: _asString(json['notes']),
      teacherName: teacher is Map ? _asString(teacher['name']) : null,
      teacherEmployeeNumber: teacher is Map
          ? _asString(teacher['employee_number'])
          : null,
    );
  }

  bool get isLate => status == 'late';
}

/// The teacher's own current day-state, mirroring the config payload's
/// `state` block. Drives which big button the Presensi screen shows.
class TeacherAttendanceState {
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final bool canCheckOut; // checkout_enabled && checked_in && !checked_out
  final TeacherAttendanceRecord? record;

  const TeacherAttendanceState({
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    required this.canCheckOut,
    this.record,
  });

  factory TeacherAttendanceState.fromJson(Map<String, dynamic> json) {
    final record = json['record'];
    return TeacherAttendanceState(
      hasCheckedIn: _asBool(json['has_checked_in']),
      hasCheckedOut: _asBool(json['has_checked_out']),
      canCheckOut: _asBool(json['can_check_out']),
      record: record is Map<String, dynamic>
          ? TeacherAttendanceRecord.fromJson(record)
          : null,
    );
  }
}

/// The full bootstrap payload of `GET /teacher-attendance/config` — the
/// single call the Presensi screen makes on open. Bundles who the
/// teacher is, the per-school settings, today's schedule, the late
/// threshold, and the current state, so the screen renders in one shot.
class TeacherAttendanceConfig {
  final String? teacherId;
  final String? teacherName;
  final String? teacherEmployeeNumber;
  final String? date; // "YYYY-MM-DD"
  final String? serverTime; // ISO8601
  final TeacherAttendanceSettings settings;
  final List<TeacherTodaySchedule> todaySchedule;
  final String? firstTeachingStart; // ISO8601 | null
  final String? lateAfter; // ISO8601 | null
  final TeacherAttendanceState state;

  const TeacherAttendanceConfig({
    this.teacherId,
    this.teacherName,
    this.teacherEmployeeNumber,
    this.date,
    this.serverTime,
    required this.settings,
    required this.todaySchedule,
    this.firstTeachingStart,
    this.lateAfter,
    required this.state,
  });

  factory TeacherAttendanceConfig.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'];
    final scheduleRaw = json['today_schedule'];
    final settingsRaw = json['settings'];
    final stateRaw = json['state'];

    return TeacherAttendanceConfig(
      teacherId: teacher is Map ? _asString(teacher['id']) : null,
      teacherName: teacher is Map ? _asString(teacher['name']) : null,
      teacherEmployeeNumber: teacher is Map
          ? _asString(teacher['employee_number'])
          : null,
      date: _asString(json['date']),
      serverTime: _asString(json['server_time']),
      settings: settingsRaw is Map<String, dynamic>
          ? TeacherAttendanceSettings.fromJson(settingsRaw)
          : const TeacherAttendanceSettings(
              cameraRequired: true,
              locationRequired: true,
              checkoutEnabled: false,
              geofenceRadiusM: 150,
              rejectOutsideGeofence: true,
              lateGraceMinutes: 0,
            ),
      todaySchedule: scheduleRaw is List
          ? scheduleRaw
                .whereType<Map>()
                .map(
                  (e) => TeacherTodaySchedule.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const <TeacherTodaySchedule>[],
      firstTeachingStart: _asString(json['first_teaching_start']),
      lateAfter: _asString(json['late_after']),
      state: stateRaw is Map<String, dynamic>
          ? TeacherAttendanceState.fromJson(stateRaw)
          : const TeacherAttendanceState(
              hasCheckedIn: false,
              hasCheckedOut: false,
              canCheckOut: false,
            ),
    );
  }
}

// ── Admin report — per-row pagination ─────────────────────────────────
// The admin per-row list (`GET /teacher-attendance/admin`) is a standard
// Laravel resource collection: `{ data: [...], meta: {...} }`. We surface
// the meta so the screen can paginate, mirroring the web service's
// `listFromJson`.

/// Pagination meta echoed by the admin per-row list. Like the `meta`
/// block of a Laravel `->paginate()` JSON response.
class TeacherAttendancePageMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const TeacherAttendancePageMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory TeacherAttendancePageMeta.fromJson(
    Map<String, dynamic> json, {
    int fallbackPerPage = 20,
    int fallbackTotal = 0,
  }) {
    return TeacherAttendancePageMeta(
      currentPage: _asIntOrNull(json['current_page']) ?? 1,
      lastPage: _asIntOrNull(json['last_page']) ?? 1,
      perPage: _asIntOrNull(json['per_page']) ?? fallbackPerPage,
      total: _asIntOrNull(json['total']) ?? fallbackTotal,
    );
  }
}

/// One page of the admin per-row report: the parsed records plus the
/// pagination meta. Returned by the admin report list endpoint.
class TeacherAttendanceListResult {
  final List<TeacherAttendanceRecord> items;
  final TeacherAttendancePageMeta meta;

  const TeacherAttendanceListResult({required this.items, required this.meta});

  factory TeacherAttendanceListResult.fromJson(dynamic body) {
    final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final rawList = map['data'];
    final items = rawList is List
        ? rawList
              .whereType<Map>()
              .map(
                (e) => TeacherAttendanceRecord.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : <TeacherAttendanceRecord>[];
    final rawMeta = map['meta'];
    final meta = rawMeta is Map<String, dynamic>
        ? TeacherAttendancePageMeta.fromJson(
            rawMeta,
            fallbackPerPage: items.length,
            fallbackTotal: items.length,
          )
        : TeacherAttendancePageMeta(
            currentPage: 1,
            lastPage: 1,
            perPage: items.length,
            total: items.length,
          );
    return TeacherAttendanceListResult(items: items, meta: meta);
  }
}

// ── Admin rekap — per-teacher summary ─────────────────────────────────
// The per-teacher rekap (`GET /teacher-attendance/admin/summary`)
// aggregates each teacher's records over a date range. Status columns
// are DYNAMIC: `present` + `late` are always present, and further
// statuses (sick / excused / absent…) may appear. The AUTHORITATIVE
// ordered column list is `meta.statuses` — read that rather than
// hardcoding columns. This mirrors the web `adminSummary` parser 1:1.

/// Default status columns when the server omits/mangles `meta.statuses`,
/// so the rekap table never renders column-less.
const List<String> kTeacherAttendanceDefaultStatuses = ['present', 'late'];

/// Reads the ordered status-column list from a summary `meta.statuses`,
/// falling back to [kTeacherAttendanceDefaultStatuses].
List<String> _statusKeysFromMeta(dynamic meta) {
  final raw = meta is Map ? meta['statuses'] : null;
  if (raw is List) {
    final keys = raw
        .map((s) => s?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (keys.isNotEmpty) return keys;
  }
  return List<String>.from(kTeacherAttendanceDefaultStatuses);
}

/// Pulls the per-status int counts out of a raw row/totals map using the
/// authoritative `statuses` list. Any status the server omitted for a
/// row reads as 0 (a teacher with no `late` records still gets `late: 0`).
Map<String, int> _statusCountsFromJson(
  Map<String, dynamic> raw,
  List<String> statuses,
) {
  final out = <String, int>{};
  for (final key in statuses) {
    out[key] = _asIntOrNull(raw[key]) ?? 0;
  }
  return out;
}

/// One per-teacher rekap row (`data[]`). Carries the dynamic per-status
/// counts ([counts], indexed by the meta status keys) plus the teacher
/// identity, aggregate total, and attendance percentage.
class TeacherAttendanceSummaryRow {
  final String teacherId;
  final String teacherName;
  final String? employeeNumber;

  /// Per-status counts, keyed by the status keys from `meta.statuses`.
  final Map<String, int> counts;

  /// Records aggregated for this teacher over the range.
  final int total;

  /// round((present + late) / total * 100, 1); 0.0 when total is 0.
  final double presentPct;

  const TeacherAttendanceSummaryRow({
    required this.teacherId,
    required this.teacherName,
    this.employeeNumber,
    required this.counts,
    required this.total,
    required this.presentPct,
  });

  /// Count for a dynamic status column (0 when absent for this teacher).
  int countFor(String status) => counts[status] ?? 0;

  factory TeacherAttendanceSummaryRow.fromJson(
    Map<String, dynamic> json,
    List<String> statuses,
  ) {
    return TeacherAttendanceSummaryRow(
      teacherId: _asString(json['teacher_id']) ?? '',
      teacherName: _asString(json['teacher_name']) ?? '-',
      employeeNumber: _asString(json['employee_number']),
      counts: _statusCountsFromJson(json, statuses),
      total: _asIntOrNull(json['total']) ?? 0,
      presentPct: _asDoubleOrNull(json['present_pct']) ?? 0,
    );
  }
}

/// The school-wide totals row (`totals`). Same dynamic-status shape as a
/// row, plus the distinct-teacher count over the range.
class TeacherAttendanceSummaryTotals {
  final Map<String, int> counts;
  final int total;
  final double presentPct;
  final int teacherCount;

  const TeacherAttendanceSummaryTotals({
    required this.counts,
    required this.total,
    required this.presentPct,
    required this.teacherCount,
  });

  int countFor(String status) => counts[status] ?? 0;

  factory TeacherAttendanceSummaryTotals.fromJson(
    Map<String, dynamic> json,
    List<String> statuses, {
    int fallbackTeacherCount = 0,
  }) {
    return TeacherAttendanceSummaryTotals(
      counts: _statusCountsFromJson(json, statuses),
      total: _asIntOrNull(json['total']) ?? 0,
      presentPct: _asDoubleOrNull(json['present_pct']) ?? 0,
      teacherCount: _asIntOrNull(json['teacher_count']) ?? fallbackTeacherCount,
    );
  }
}

/// The full `GET /teacher-attendance/admin/summary` payload: the period
/// meta (with the dynamic [statuses] column list), the per-teacher rows,
/// and the school-wide totals. Parsed defensively so a surprise shape
/// renders an empty rekap rather than crashing.
class TeacherAttendanceAdminSummary {
  final String startDate; // "YYYY-MM-DD"
  final String endDate; // "YYYY-MM-DD"

  /// Authoritative ordered list of status columns present in the data.
  final List<String> statuses;
  final List<TeacherAttendanceSummaryRow> rows;
  final TeacherAttendanceSummaryTotals totals;

  const TeacherAttendanceAdminSummary({
    required this.startDate,
    required this.endDate,
    required this.statuses,
    required this.rows,
    required this.totals,
  });

  factory TeacherAttendanceAdminSummary.fromJson(dynamic body) {
    final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final meta = map['meta'];
    final statuses = _statusKeysFromMeta(meta);
    final rawRows = map['data'];
    final rows = rawRows is List
        ? rawRows
              .whereType<Map>()
              .map(
                (e) => TeacherAttendanceSummaryRow.fromJson(
                  Map<String, dynamic>.from(e),
                  statuses,
                ),
              )
              .toList()
        : <TeacherAttendanceSummaryRow>[];
    final rawTotals = map['totals'];
    final totals = TeacherAttendanceSummaryTotals.fromJson(
      rawTotals is Map<String, dynamic> ? rawTotals : <String, dynamic>{},
      statuses,
      fallbackTeacherCount: rows.length,
    );
    return TeacherAttendanceAdminSummary(
      startDate: (meta is Map ? _asString(meta['start_date']) : null) ?? '',
      endDate: (meta is Map ? _asString(meta['end_date']) : null) ?? '',
      statuses: statuses,
      rows: rows,
      totals: totals,
    );
  }
}

// ── Safe coercion helpers ─────────────────────────────────────────────
// The API is mostly clean, but Laravel + JSON can hand back a number as
// a String or a 1/0 instead of true/false depending on the cast. These
// keep the parsing total (never throws on a surprise type).

String? _asString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

double? _asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool _asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}
