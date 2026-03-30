import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance.freezed.dart';
part 'attendance.g.dart';

/// Represents a single attendance record for a student on a specific date.
@freezed
class Attendance with _$Attendance {
  const factory Attendance({
    required String id,
    @JsonKey(name: 'student_id') required String studentId,
    required DateTime date,
    required String status,
    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'subject_name') String? subjectName,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'lesson_hour_name') String? lessonHourName,
    @JsonKey(name: 'lesson_hour_id') String? lessonHourId,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'teacher_id') String? teacherId,
  }) = _Attendance;

  /// Custom fromJson to handle various API response shapes by standardizing
  /// them before generation.
  factory Attendance.fromJson(Map<String, dynamic> json) => 
      _$AttendanceFromJson(_standardizeJson(json));

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);
    
    // Map Indonesian keys to backend-expected snake_case English model properties
    mapped['student_id'] ??= mapped['id_siswa'];
    mapped['date'] ??= mapped['tanggal'];
    // Normalize is_read: API may return int (0/1), String ("0"/"1"), or bool
    final rawIsRead = mapped['is_read'] ?? mapped['isRead'];
    mapped['is_read'] = rawIsRead == true || rawIsRead == 1 || rawIsRead == '1';
    mapped['subject_name'] ??= mapped['mata_pelajaran_nama'];
    mapped['subject_id'] ??= mapped['id_mata_pelajaran'] ?? mapped['mata_pelajaran_id'];
    mapped['lesson_hour_name'] ??= mapped['jam_pelajaran_nama'];
    mapped['lesson_hour_id'] ??= mapped['id_jam_pelajaran'] ?? mapped['lesson_hour_id'];
    mapped['class_id'] ??= mapped['kelas_id'] ?? mapped['id_kelas'] ?? mapped['class_id'];
    mapped['teacher_id'] ??= mapped['guru_id'] ?? mapped['teacher_id'];
    
    // Force string types for IDs to avoid type cast errors
    if (mapped['id'] != null) mapped['id'] = mapped['id'].toString();
    if (mapped['student_id'] != null) mapped['student_id'] = mapped['student_id'].toString();
    if (mapped['subject_id'] != null) mapped['subject_id'] = mapped['subject_id'].toString();
    if (mapped['lesson_hour_id'] != null) mapped['lesson_hour_id'] = mapped['lesson_hour_id'].toString();
    if (mapped['class_id'] != null) mapped['class_id'] = mapped['class_id'].toString();
    if (mapped['teacher_id'] != null) mapped['teacher_id'] = mapped['teacher_id'].toString();
    
    return mapped;
  }
}
