/// Typed model for a school day record from the `/days` API.
///
/// The backend stores English day names (Monday, Tuesday, …) in a single
/// `name` column. Translation to Indonesian (Senin, Selasa, …) is handled
/// at the Flutter UI layer via [dayNameToIndonesian].
///
/// To convert from API / cache data:
/// ```dart
/// final days = rawList.map((d) => SchoolDay.fromJson(Map<String,
/// dynamic>.from(d))).toList();
/// ```
class SchoolDay {
  final String id;
  final String name;

  const SchoolDay({required this.id, required this.name});

  /// Parses a school day from a JSON map.
  factory SchoolDay.fromJson(Map<String, dynamic> json) => SchoolDay(
    id: (json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
