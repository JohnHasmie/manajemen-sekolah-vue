/// attendance.dart - Student attendance record model.
/// Like Laravel's Attendance Eloquent Model but simpler - just a data class (DTO).
/// In Vue terms, this is the shape of the attendance object you'd define in a TypeScript interface.
library;

/// Represents a single attendance record for a student on a specific date.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM or DB interaction.
///
/// Key properties:
/// - [studentId]: Foreign key to the student (like `$belongsTo` in Laravel).
/// - [date]: The date of the attendance record.
/// - [status]: Attendance status string - one of 'hadir' (present), 'sakit' (sick),
///   'izin' (permission/excused), or 'alpha' (absent without notice).
class Attendance {
  final String studentId;
  final DateTime date;
  final String status; // hadir, sakit, izin, alpha

  /// Creates an [Attendance] instance.
  Attendance({
    required this.studentId,
    required this.date,
    required this.status,
  });
}
