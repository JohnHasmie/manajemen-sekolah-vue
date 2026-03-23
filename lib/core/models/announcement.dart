/// announcement.dart - School announcement data model.
/// Like Laravel's Announcement Eloquent Model but simpler - just a data class (DTO).
/// In Vue terms, this is the TypeScript interface for an announcement object.
library;

/// Represents a school announcement/notification entry.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [title]: Announcement title/headline.
/// - [content]: Full body/content of the announcement.
/// - [date]: Publication date.
/// - [category]: Category string (e.g., "Akademik", "Keuangan") - like a Laravel enum.
class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String category;

  /// Creates an [Announcement] instance. All fields are required.
  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.category,
  });
}
