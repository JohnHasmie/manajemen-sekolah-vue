/// attendance_summary.dart - Aggregated attendance summary per subject per date.
/// Like a Laravel Attendance summary Resource/DTO - presents pre-aggregated attendance data.
/// In Vue terms, this is the shape returned by a "GET /attendance/summary" API call.
library;

/// Holds a summarized attendance snapshot for one subject on one date.
/// Like a Laravel Eloquent Model but simpler - just a data class with fromJson.
///
/// Key properties:
/// - [subjectId] / [subjectName]: The subject this summary belongs to.
/// - [totalStudents]: Total number of students expected.
/// - [present]: Count of students who were present.
/// - [absent]: Count of students who were absent (sick + excused + alpha combined).
class AttendanceSummary {
  final String id;
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final int totalStudents;
  final int present;
  final int absent;

  AttendanceSummary({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.totalStudents,
    required this.present,
    required this.absent,
  });

  /// Constructs an [AttendanceSummary] from a JSON map returned by the backend API.
  /// JSON keys are Indonesian (matching the Laravel backend field names).
  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      id: json['id'] ?? '',
      subjectId: json['mata_pelajaran_id'] ?? '',
      subjectName: json['mata_pelajaran_nama'] ?? '',
      date: DateTime.parse(json['tanggal']),
      totalStudents: json['total_siswa'] ?? 0,
      present: json['hadir'] ?? 0,
      absent: json['tidak_hadir'] ?? 0,
    );
  }
}
