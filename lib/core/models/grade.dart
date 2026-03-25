/// grade.dart - Student grade/score data model.
/// Like Laravel's Grade Eloquent Model but simpler - just a data class (DTO).
/// In Vue terms, this is the TypeScript interface for a grade record object.
library;

/// Represents a single grade record linking a student to a subject score in a semester.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [studentId]: Foreign key to the student (like Laravel's `belongsTo` relationship).
/// - [subject]: Subject name (e.g., "Matematika").
/// - [score]: Numeric score/grade (0-100 scale).
/// - [semester]: Semester identifier (e.g., "Ganjil" for odd, "Genap" for even).
class Grade {
  final String studentId;
  final String subject;
  final double score;
  final String semester;

  /// Creates a [Grade] instance. All fields are required.
  Grade({
    required this.studentId,
    required this.subject,
    required this.score,
    required this.semester,
  });
}
