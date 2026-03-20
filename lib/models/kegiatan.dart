/// kegiatan.dart - School activity/event data model.
/// Like Laravel's Kegiatan Eloquent Model but simpler - just a data class (similar to a Laravel Resource or DTO).
/// In Vue terms, this is the TypeScript interface for a school event object.
library;

/// Represents a school activity or event (e.g., flag ceremony, exam, competition).
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [nama]: Activity name/title.
/// - [deskripsi]: Detailed description of the activity.
/// - [tanggal]: Date when the activity takes place.
/// - [lokasi]: Physical location/venue of the activity.
class Kegiatan {
  final String id;
  final String nama;
  final String deskripsi;
  final DateTime tanggal;
  final String lokasi;

  /// Creates a [Kegiatan] instance. All fields are required.
  Kegiatan({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.tanggal,
    required this.lokasi,
  });
}