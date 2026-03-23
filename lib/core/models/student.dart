/// student.dart - Student data model with JSON serialization.
/// Like Laravel's Student Eloquent Model but simpler - just a data class with fromJson/toJson
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
/// - [studentNumber]: Student identification number (NIS).
/// - [address]: Home address.
/// - [guardianName]: Guardian/parent name (like a flattened `belongsTo` relationship).
/// - [phoneNumber]: Contact phone number.
/// - [classId]: Optional foreign key to the class (nullable for unassigned students).
/// - [studentClassId]: Optional pivot table ID linking student to class
///   (like Laravel's pivot ID in a `belongsToMany`).
class Student {
  final String id;
  final String name;
  final String className;
  final String studentNumber;
  final String address;
  final String guardianName;
  final String phoneNumber;
  final String? classId;
  final String? studentClassId;

  Student({
    required this.id,
    required this.name,
    required this.className,
    required this.studentNumber,
    required this.address,
    required this.guardianName,
    required this.phoneNumber,
    this.classId,
    this.studentClassId,
  });

  /// Constructs a [Student] from a JSON map returned by the backend API.
  /// Handles two different API response shapes for the class name:
  /// 1. Flat: `{ "kelas_nama": "7A" }` (from list endpoints)
  /// 2. Nested: `{ "class": { "name": "7A" } }` (from detail endpoints)
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      // Try flat key first, fall back to nested class object
      className: json['kelas_nama'] ?? json['class']?['name'] ?? '',
      studentNumber: json['student_number'] ?? '',
      address: json['address'] ?? '',
      guardianName: json['guardian_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      classId: json['class_id'],
      studentClassId: json['student_class_id'],
    );
  }

  /// Serializes this student to a JSON map for sending to the API.
  /// Uses snake_case keys to match the Laravel backend convention.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kelas_nama': className,
      'student_number': studentNumber,
      'address': address,
      'guardian_name': guardianName,
      'phone_number': phoneNumber,
      'class_id': classId,
      'student_class_id': studentClassId,
    };
  }
}
