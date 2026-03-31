/// teacher.dart - Teacher data model.
/// Like Laravel's Teacher Eloquent Model but simpler - just a data class (DTO).
/// In Vue terms, this is the TypeScript interface for a teacher object.
library;

/// Represents a teacher record with minimal identifying information.
/// Like a Laravel Eloquent Model but simpler - just a data class with no
/// database interaction, ORM, or relationships.
///
/// Key properties:
/// - [id]: Unique identifier (like Laravel's `$model->id`).
/// - [name]: Teacher's full name.
class Teacher {
  final String id;
  final String name;

  /// Creates a [Teacher] instance with required [id] and [name].
  Teacher({required this.id, required this.name});
}
