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
