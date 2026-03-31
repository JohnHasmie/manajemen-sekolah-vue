/// Typed model for a school day record from the `/days` API.
///
/// Replaces raw `Map<String, dynamic>` access like `day['name_id']` with
/// typed, null-safe properties. Like a Laravel Eloquent `Day` model cast
/// to a DTO — centralizes field name resolution and type coercion.
///
/// To convert from API / cache data:
/// ```dart
/// final days = rawList.map((d) => SchoolDay.fromJson(Map<String, dynamic>.from(d))).toList();
/// ```
class SchoolDay {
  final String id;
  final String name;
  final String nameId;

  const SchoolDay({
    required this.id,
    required this.name,
    required this.nameId,
  });

  /// Parses a school day from a JSON map.
  /// Handles both `name_id` (Indonesian) and `name` (English) fields.
  factory SchoolDay.fromJson(Map<String, dynamic> json) => SchoolDay(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        nameId: (json['name_id'] ?? json['name'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_id': nameId,
      };
}
