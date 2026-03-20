/// siswa.dart - Student (Siswa) data model with JSON serialization.
/// Like Laravel's Siswa Eloquent Model but simpler - just a data class with fromJson/toJson
/// (similar to a Laravel Resource or DTO).
/// In Vue terms, this is the TypeScript interface for a student object,
/// with helper methods to parse/serialize from/to the API's JSON shape.
library;

/// Represents a student record with personal info and class assignment.
/// Like a Laravel Eloquent Model but simpler - just a data class with fromJson/toJson.
///
/// Key properties:
/// - [name]: Student's full name.
/// - [className]: Resolved class name (e.g., "7A"). Comes from either `kelas_nama`
///   or the nested `class.name` in the API response (like a Laravel accessor).
/// - [nis]: Student identification number (Nomor Induk Siswa).
/// - [alamat]: Home address.
/// - [nameParent]: Guardian/parent name (like a flattened `belongsTo` relationship).
/// - [noTelepon]: Contact phone number.
/// - [classId]: Optional foreign key to the class (nullable for unassigned students).
/// - [studentClassId]: Optional pivot table ID linking student to class
///   (like Laravel's pivot ID in a `belongsToMany`).
class Siswa {
  final String id;
  final String name;
  final String className;
  final String nis;
  final String alamat;
  final String nameParent;
  final String noTelepon;
  final String? classId;
  final String? studentClassId;

  Siswa({
    required this.id,
    required this.name,
    required this.className,
    required this.nis,
    required this.alamat,
    required this.nameParent,
    required this.noTelepon,
    this.classId,
    this.studentClassId,
  });

  /// Constructs a [Siswa] from a JSON map returned by the backend API.
  /// Handles two different API response shapes for the class name:
  /// 1. Flat: `{ "kelas_nama": "7A" }` (from list endpoints)
  /// 2. Nested: `{ "class": { "name": "7A" } }` (from detail endpoints)
  /// This is similar to how a Laravel Resource might `whenLoaded` a relationship.
  ///
  /// [json] - The raw API response map for a single student.
  factory Siswa.fromJson(Map<String, dynamic> json) {
    return Siswa(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      // Try flat key first, fall back to nested class object
      className: json['kelas_nama'] ?? json['class']?['name'] ?? '',
      nis: json['student_number'] ?? '',
      alamat: json['address'] ?? '',
      nameParent: json['guardian_name'] ?? '',
      noTelepon: json['phone_number'] ?? '',
      classId: json['class_id'],
      studentClassId: json['student_class_id'],
    );
  }

  /// Serializes this student to a JSON map for sending to the API.
  /// Uses snake_case keys to match the Laravel backend convention.
  /// Like calling `$model->toArray()` in Laravel.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kelas_nama': className,
      'student_number': nis,
      'address': alamat,
      'guardian_name': nameParent,
      'phone_number': noTelepon,
      'class_id': classId,
      'student_class_id': studentClassId,
    };
  }
}
