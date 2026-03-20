/// pengumuman.dart - School announcement data model.
/// Like Laravel's Pengumuman Eloquent Model but simpler - just a data class (similar to a Laravel Resource or DTO).
/// In Vue terms, this is the TypeScript interface for an announcement object.
library;

/// Represents a school announcement/notification entry.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [judul]: Announcement title/headline.
/// - [isi]: Full body/content of the announcement.
/// - [tanggal]: Publication date.
/// - [kategori]: Category string (e.g., "Akademik", "Keuangan") - like a Laravel enum or
///   a `type` column used for filtering.
class Pengumuman {
  final String id;
  final String judul;
  final String isi;
  final DateTime tanggal;
  final String kategori;

  /// Creates a [Pengumuman] instance. All fields are required.
  Pengumuman({
    required this.id,
    required this.judul,
    required this.isi,
    required this.tanggal,
    required this.kategori,
  });
}