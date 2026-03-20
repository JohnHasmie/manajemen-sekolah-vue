/// absensi.dart - Student attendance record model.
/// Like Laravel's Absensi Eloquent Model but simpler - just a data class (similar to a Laravel Resource or DTO).
/// In Vue terms, this is the shape of the attendance object you'd define in a TypeScript interface.
library;

/// Represents a single attendance record for a student on a specific date.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM or DB interaction.
///
/// Key properties:
/// - [siswaId]: Foreign key to the student (like `$belongsTo` in Laravel).
/// - [tanggal]: The date of the attendance record.
/// - [status]: Attendance status string - one of 'hadir' (present), 'sakit' (sick),
///   'izin' (permission/excused), or 'alpha' (absent without notice).
class Absensi {
  final String siswaId;
  final DateTime tanggal;
  final String status; // hadir, sakit, izin, alpha

  /// Creates an [Absensi] instance.
  ///
  /// All parameters are required since every attendance record must have
  /// a student, date, and status.
  Absensi({
    required this.siswaId,
    required this.tanggal,
    required this.status,
  });
}