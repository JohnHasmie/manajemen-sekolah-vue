/// student.dart - Student data model with JSON serialization.
/// Uses freezed for immutability, copyWith, == and toString generation.
/// Custom fromJson handles two API response shapes for className.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'student.freezed.dart';

/// Represents a student record with personal info and class assignment.
/// Like a Laravel Eloquent Model but immutable (similar to a Laravel Resource/DTO).
@freezed
class Student with _$Student {
  const Student._();

  const factory Student({
    required String id,
    @Default('') String name,
    @Default('') String className,
    @Default('') String studentNumber,
    @Default('') String address,
    @Default('') String guardianName,
    @Default('') String phoneNumber,
    String? classId,
    String? studentClassId,
  }) = _Student;

  /// Serializes to API-compatible JSON with snake_case keys.
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

  /// Custom fromJson to handle two API response shapes:
  /// 1. Flat: `{ "kelas_nama": "7A" }` (from list endpoints)
  /// 2. Nested: `{ "class": { "name": "7A" } }` (from detail endpoints)
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      className: json['kelas_nama'] ?? json['class']?['name'] ?? '',
      studentNumber: json['student_number'] ?? '',
      address: json['address'] ?? '',
      guardianName: json['guardian_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      classId: json['class_id']?.toString(),
      studentClassId: json['student_class_id']?.toString(),
    );
  }
}
