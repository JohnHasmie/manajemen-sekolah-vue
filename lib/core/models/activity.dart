/// activity.dart - School activity/event data model.
/// Like Laravel's Activity Eloquent Model but simpler - just a data class (DTO).
/// In Vue terms, this is the TypeScript interface for a school event object.
library;

/// Represents a school activity or event (e.g., flag ceremony, exam, competition).
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [name]: Activity name/title.
/// - [description]: Detailed description of the activity.
/// - [date]: Date when the activity takes place.
/// - [location]: Physical location/venue of the activity.
class Activity {
  final String id;
  final String name;
  final String description;
  final DateTime date;
  final String location;

  /// Creates an [Activity] instance. All fields are required.
  Activity({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.location,
  });
}
