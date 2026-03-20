/// nilai.dart - Student grade/score data model.
/// Like Laravel's Nilai Eloquent Model but simpler - just a data class (similar to a Laravel Resource or DTO).
/// In Vue terms, this is the TypeScript interface for a grade record object.
library;

/// Represents a single grade record linking a student to a subject score in a semester.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [siswaId]: Foreign key to the student (like Laravel's `belongsTo` relationship).
/// - [mataPelajaran]: Subject name (e.g., "Matematika").
/// - [nilai]: Numeric score/grade (0-100 scale).
/// - [semester]: Semester identifier (e.g., "Ganjil" for odd, "Genap" for even).
class Nilai {
  final String siswaId;
  final String mataPelajaran;
  final double nilai;
  final String semester;

  /// Creates a [Nilai] instance. All fields are required.
  Nilai({
    required this.siswaId,
    required this.mataPelajaran,
    required this.nilai,
    required this.semester,
  });
}