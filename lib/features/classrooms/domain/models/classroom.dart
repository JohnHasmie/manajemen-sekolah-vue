/// classroom.dart - Classroom data model.
/// Like Laravel's Classroom Eloquent Model but simpler - just a data class (DTO).
/// In Vue terms, this is the TypeScript interface for a classroom object.
library;

/// Represents a school class/classroom with its homeroom teacher and student count.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [name]: Class name (e.g., "7A", "8B").
/// - [homeroomTeacher]: Homeroom teacher's name (like a `belongsTo` relationship flattened to a string).
/// - [studentCount]: Number of students enrolled in this class.
class Classroom {
  final String id;
  final String name;
  final String homeroomTeacher;
  final int studentCount;

  /// Creates a [Classroom] instance. All fields are required.
  Classroom({
    required this.id,
    required this.name,
    required this.homeroomTeacher,
    required this.studentCount,
  });
}
