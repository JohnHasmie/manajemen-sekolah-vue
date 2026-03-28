import 'package:freezed_annotation/freezed_annotation.dart';

part 'student.freezed.dart';
part 'student.g.dart';

/// Represents a student record with personal info and class assignment.
@freezed
class Student with _$Student {
  const Student._();

  const factory Student({
    required String id,
    required String name,
    @JsonKey(name: 'class_name') required String className,
    @JsonKey(name: 'student_number') required String studentNumber,
    required String address,
    @JsonKey(name: 'guardian_name') required String guardianName,
    @JsonKey(name: 'phone_number') required String phoneNumber,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'student_class_id') String? studentClassId,
  }) = _Student;

  /// Custom fromJson to handle various API response shapes by standardizing
  /// them before generation.
  factory Student.fromJson(Map<String, dynamic> json) => 
      _$StudentFromJson(_standardizeJson(json));

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);
    
    // 1. Resolve Name
    mapped['name'] ??= mapped['nama'];
    
    // 2. Resolve Class Name (handles: class_name, kelas_nama, or nested class.name)
    mapped['class_name'] ??= mapped['kelas_nama'];
    if (mapped['class'] is Map && mapped['class']['name'] != null) {
      mapped['class_name'] ??= mapped['class']['name'];
    }

    // 3. Resolve Other Fields
    mapped['student_number'] ??= mapped['nomor_induk'];
    mapped['guardian_name'] ??= mapped['nama_wali'];
    mapped['phone_number'] ??= mapped['nomor_hp'];
    mapped['class_id'] ??= mapped['id_kelas'];
    mapped['student_class_id'] ??= mapped['id_siswa_kelas'];
    
    // 4. Force String types for IDs and numbers to avoid type cast errors
    if (mapped['id'] != null) mapped['id'] = mapped['id'].toString();
    if (mapped['class_id'] != null) mapped['class_id'] = mapped['class_id'].toString();
    if (mapped['student_class_id'] != null) mapped['student_class_id'] = mapped['student_class_id'].toString();
    if (mapped['student_number'] != null) mapped['student_number'] = mapped['student_number'].toString();
    
    return mapped;
  }
}
