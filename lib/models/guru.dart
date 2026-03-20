/// guru.dart - Teacher (Guru) data model.
/// Like Laravel's Guru Eloquent Model but simpler - just a data class (similar to a Laravel Resource or DTO).
/// In Vue terms, this is the TypeScript interface for a teacher object.
library;

/// Represents a teacher record with minimal identifying information.
/// Like a Laravel Eloquent Model but simpler - just a data class with no
/// database interaction, ORM, or relationships.
///
/// Key properties:
/// - [id]: Unique identifier (like Laravel's `$model->id`).
/// - [nama]: Teacher's full name.
class Guru {
  final String id;
  final String nama;

  /// Creates a [Guru] instance with required [id] and [nama].
  Guru({
    required this.id,
    required this.nama,
  });
}