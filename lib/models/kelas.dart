/// kelas.dart - Classroom (Kelas) data model.
/// Like Laravel's Kelas Eloquent Model but simpler - just a data class (similar to a Laravel Resource or DTO).
/// In Vue terms, this is the TypeScript interface for a classroom object.
library;

/// Represents a school class/classroom with its homeroom teacher and student count.
/// Like a Laravel Eloquent Model but simpler - just a data class with no ORM.
///
/// Key properties:
/// - [nama]: Class name (e.g., "7A", "8B").
/// - [waliKelas]: Homeroom teacher's name (like a `belongsTo` relationship flattened to a string).
/// - [jumlahSiswa]: Number of students enrolled in this class.
class Kelas {
  final String id;
  final String nama;
  final String waliKelas;
  final int jumlahSiswa;

  /// Creates a [Kelas] instance. All fields are required.
  Kelas({
    required this.id,
    required this.nama,
    required this.waliKelas,
    required this.jumlahSiswa,
  });
}