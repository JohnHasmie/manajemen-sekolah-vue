import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';

/// State model for the Teacher Attendance Detail screen.
/// Encapsulates list data and UI interaction flags.
class TeacherAttendanceState {
  final List<Student> students;
  final List<Attendance> attendanceRecords;
  final Map<String, String> editedStatus;
  final bool isEditing;
  final bool isSaving;

  const TeacherAttendanceState({
    this.students = const [],
    this.attendanceRecords = const [],
    this.editedStatus = const {},
    this.isEditing = false,
    this.isSaving = false,
  });

  TeacherAttendanceState copyWith({
    List<Student>? students,
    List<Attendance>? attendanceRecords,
    Map<String, String>? editedStatus,
    bool? isEditing,
    bool? isSaving,
  }) {
    return TeacherAttendanceState(
      students: students ?? this.students,
      attendanceRecords: attendanceRecords ?? this.attendanceRecords,
      editedStatus: editedStatus ?? this.editedStatus,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  /// Calculates student statistics based on CURRENT (potentially edited) status.
  Map<String, int> get statistics {
    int hadir = 0;
    int terlambat = 0;
    int izin = 0;
    int sakit = 0;
    int alpha = 0;

    for (final student in students) {
      final status = editedStatus[student.id]?.toLowerCase() ?? 'absent';
      switch (status) {
        case 'present':
        case 'hadir':
          hadir++;
          break;
        case 'late':
        case 'terlambat':
          terlambat++;
          break;
        case 'excused':
        case 'izin':
          izin++;
          break;
        case 'sick':
        case 'sakit':
          sakit++;
          break;
        case 'absent':
        case 'alpha':
          alpha++;
          break;
      }
    }

    return {
      'hadir': hadir,
      'terlambat': terlambat,
      'izin': izin,
      'sakit': sakit,
      'alpha': alpha,
      'total': students.length,
    };
  }
}
