import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance.freezed.dart';
part 'attendance.g.dart';

/// Represents a single attendance record for a student on a specific date.
@freezed
abstract class Attendance with _$Attendance {
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

    // Map Indonesian keys to backend-expected snake_case English model
    // properties
    mapped['student_id'] ??= mapped['id_siswa'];
    mapped['date'] ??= mapped['tanggal'];
    // Normalize is_read: API may return int (0/1), String ("0"/"1"), or bool
    final rawIsRead = mapped['is_read'] ?? mapped['isRead'];
    mapped['is_read'] = rawIsRead == true || rawIsRead == 1 || rawIsRead == '1';

    // Extract names from nested eager-loaded relations (preferred)
    // or fall back to legacy appended Indonesian fields.
    final subject = mapped['subject'];
    final lessonHour = mapped['lesson_hour'] ?? mapped['lessonHour'];
    final classObj = mapped['class'];
    final teacher = mapped['teacher'];

    mapped['subject_name'] ??=
        (subject is Map ? subject['name'] : null) ??
        mapped['mata_pelajaran_nama'];
    mapped['subject_id'] ??=
        (subject is Map ? subject['id']?.toString() : null) ??
        mapped['id_mata_pelajaran'] ??
        mapped['mata_pelajaran_id'];
    mapped['lesson_hour_name'] ??=
        (lessonHour is Map ? lessonHour['name'] : null) ??
        mapped['jam_pelajaran_nama'];
    mapped['lesson_hour_id'] ??=
        (lessonHour is Map ? lessonHour['id']?.toString() : null) ??
        mapped['id_jam_pelajaran'];
    mapped['class_id'] ??=
        (classObj is Map ? classObj['id']?.toString() : null) ??
        mapped['kelas_id'] ??
        mapped['id_kelas'];
    mapped['teacher_id'] ??=
        (teacher is Map ? teacher['id']?.toString() : null) ??
        mapped['guru_id'];

    // Force string types for IDs to avoid type cast errors
    if (mapped['id'] != null) mapped['id'] = mapped['id'].toString();
    if (mapped['student_id'] != null) {
      mapped['student_id'] = mapped['student_id'].toString();
    }
    if (mapped['subject_id'] != null) {
      mapped['subject_id'] = mapped['subject_id'].toString();
    }
    if (mapped['lesson_hour_id'] != null) {
      mapped['lesson_hour_id'] = mapped['lesson_hour_id'].toString();
    }
    if (mapped['class_id'] != null) {
      mapped['class_id'] = mapped['class_id'].toString();
    }
    if (mapped['teacher_id'] != null) {
      mapped['teacher_id'] = mapped['teacher_id'].toString();
    }

    return mapped;
  }
}
