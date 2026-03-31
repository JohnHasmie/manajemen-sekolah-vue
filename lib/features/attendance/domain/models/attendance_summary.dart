import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance_summary.freezed.dart';
part 'attendance_summary.g.dart';

/// Represents a summary of attendance data for a specific date or period.
@freezed
class AttendanceSummary with _$AttendanceSummary {
  const factory AttendanceSummary({
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'date') required DateTime date,
    @Default(0) int present,
    @Default(0) int sick,
    @Default(0) int excused,
    @Default(0) int absent,
    @JsonKey(name: 'total_students') @Default(0) int totalStudents,
    @JsonKey(name: 'subject_name') String? subjectName,
    @JsonKey(name: 'subject_id') String? subjectId,
  }) = _AttendanceSummary;

  /// Custom fromJson to handle various API response shapes by standardizing
  /// them before generation.
  factory AttendanceSummary.fromJson(Map<String, dynamic> json) => 
      _$AttendanceSummaryFromJson(_standardizeJson(json));

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);
    
    // Standardize all variations of Indonesian keys into the backend-expected snake_case English keys
    mapped['date'] ??= mapped['tanggal'];
    mapped['present'] ??= mapped['hadir'];
    mapped['sick'] ??= mapped['sakit'];
    mapped['excused'] ??= mapped['izin'];
    mapped['absent'] ??= mapped['alpha'] ?? mapped['alpa'] ?? mapped['tidak_hadir'];
    mapped['total_students'] ??= mapped['total_siswa'];
    mapped['subject_name'] ??= mapped['mata_pelajaran_nama'];
    mapped['subject_id'] ??= mapped['id_mata_pelajaran'] ?? mapped['mata_pelajaran_id'];
    
    // Force string types for IDs to avoid type cast errors
    if (mapped['id'] != null) mapped['id'] = mapped['id'].toString();
    if (mapped['subject_id'] != null) mapped['subject_id'] = mapped['subject_id'].toString();
    
    return mapped;
  }
}
