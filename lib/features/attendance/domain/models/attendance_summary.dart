/// attendance_summary.dart - Aggregated attendance summary per subject per date.
/// Uses freezed for immutability, copyWith, == and toString.
/// Custom fromJson maps Indonesian API field names to English properties.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance_summary.freezed.dart';

/// Holds a summarized attendance snapshot for one subject on one date.
@freezed
class AttendanceSummary with _$AttendanceSummary {
  const factory AttendanceSummary({
    @Default('') String id,
    @Default('') String subjectId,
    @Default('') String subjectName,
    required DateTime date,
    @Default(0) int totalStudents,
    @Default(0) int present,
    @Default(0) int absent,
  }) = _AttendanceSummary;

  /// Custom fromJson mapping Indonesian API keys to English properties.
  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      id: (json['id'] ?? '').toString(),
      subjectId: (json['mata_pelajaran_id'] ?? '').toString(),
      subjectName: json['mata_pelajaran_nama'] ?? '',
      date: DateTime.parse(json['tanggal']),
      totalStudents: json['total_siswa'] ?? 0,
      present: json['hadir'] ?? 0,
      absent: json['tidak_hadir'] ?? 0,
    );
  }
}
