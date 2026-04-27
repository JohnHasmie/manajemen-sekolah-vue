import 'package:freezed_annotation/freezed_annotation.dart';

part 'student.freezed.dart';
part 'student.g.dart';

/// Represents a student record with personal info and class assignment.
@freezed
abstract class Student with _$Student {
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
    String? gender,
    @JsonKey(name: 'date_of_birth') String? dateOfBirth,
    @JsonKey(name: 'guardian_email') String? guardianEmail,
  }) = _Student;

  /// Uppercase first letter of [name], or `'?'` when empty.
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';

  /// Custom fromJson to handle various API response shapes by standardizing
  /// them before generation.
  factory Student.fromJson(Map<String, dynamic> json) =>
      _$StudentFromJson(_standardizeJson(json));

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);

    // 1. Resolve Name
    mapped['name'] ??= mapped['nama'];

    // 2. Resolve Class Name. The API surfaces this in *six* shapes depending
    //    on which endpoint produces the row. Normalize them all so
    //    `Student.className` is reliable for the parent dropdown / detail
    //    cards (P2/P3 were rendering "Kelas: -" because the parent-grade and
    //    parent-attendance endpoints return the nested-relation shape, while
    //    parent-class-activity returns the flat shape — see PR-9 in
    //    P0_PR_Plan.md).
    //
    //   a. flat English          : { class_name: "7A" }
    //   b. flat Indonesian       : { kelas_nama: "7A" }
    //   c. nested relation       : { class: { name: "7A" } }
    //   d. nested relation (id)  : { kelas: { nama: "7A" } }
    //   e. nested enrollment     : { student_classes: [{ class: { name: "7A" } }] }
    //   f. nested enrollment (id): { siswa_kelas:    [{ kelas: { nama: "7A" } }] }
    mapped['class_name'] ??= mapped['kelas_nama'];
    if (mapped['class'] is Map && mapped['class']['name'] != null) {
      mapped['class_name'] ??= mapped['class']['name'];
    }
    if (mapped['kelas'] is Map && mapped['kelas']['nama'] != null) {
      mapped['class_name'] ??= mapped['kelas']['nama'];
    }
    if (mapped['class_name'] == null) {
      final enrollments = mapped['student_classes'] ?? mapped['siswa_kelas'];
      if (enrollments is List && enrollments.isNotEmpty) {
        final first = enrollments.first;
        if (first is Map) {
          final cls = first['class'] ?? first['kelas'];
          if (cls is Map) {
            mapped['class_name'] = cls['name'] ?? cls['nama'];
          }
          // Some payloads put the class name directly on the enrollment row
          // instead of nesting a `class`/`kelas` object.
          mapped['class_name'] ??= first['class_name'] ?? first['kelas_nama'];
        }
      }
    }

    // 3. Resolve Other Fields
    mapped['student_number'] ??=
        mapped['nomor_induk'] ?? mapped['nis'] ?? mapped['nisn'];
    mapped['guardian_name'] ??= mapped['nama_wali'];
    mapped['phone_number'] ??= mapped['nomor_hp'];
    mapped['class_id'] ??= mapped['id_kelas'];
    mapped['student_class_id'] ??= mapped['id_siswa_kelas'];
    mapped['gender'] ??= mapped['jenis_kelamin'];
    mapped['date_of_birth'] ??= mapped['tanggal_lahir'] ?? mapped['tgl_lahir'];
    mapped['guardian_email'] ??= mapped['parent_email'] ?? mapped['email_wali'];

    // Use "name" from alternate keys used by report-card APIs.
    mapped['name'] ??= mapped['student_name'];

    // Fall back to student_id if id missing (recommendation APIs)
    mapped['id'] ??= mapped['student_id'];

    // 4. Force String types — provide defaults for required fields to prevent null cast errors
    mapped['id'] = (mapped['id'] ?? '').toString();
    mapped['name'] = (mapped['name'] ?? '').toString();
    mapped['class_name'] = (mapped['class_name'] ?? '').toString();
    mapped['student_number'] = (mapped['student_number'] ?? '').toString();
    mapped['address'] = (mapped['address'] ?? mapped['alamat'] ?? '')
        .toString();
    mapped['guardian_name'] = (mapped['guardian_name'] ?? '').toString();
    mapped['phone_number'] = (mapped['phone_number'] ?? '').toString();
    if (mapped['class_id'] != null) {
      mapped['class_id'] = mapped['class_id'].toString();
    }
    if (mapped['student_class_id'] != null) {
      mapped['student_class_id'] = mapped['student_class_id'].toString();
    }

    return mapped;
  }
}
