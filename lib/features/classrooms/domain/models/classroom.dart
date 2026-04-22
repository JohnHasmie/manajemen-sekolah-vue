import 'package:freezed_annotation/freezed_annotation.dart';

part 'classroom.freezed.dart';
part 'classroom.g.dart';

/// Represents a school class/classroom (e.g., "7A", "8B").
///
/// The API returns classroom data in several shapes:
///   - `homeroom_teacher` can be a Map `{id, name}`, a List of such maps,
///     or absent entirely with the name flattened to
///     `homeroom_teacher_name` / `wali_kelas_nama`.
///   - Key names may be English or Indonesian (`name` / `nama`,
///     `student_count` / `jumlah_siswa`, `grade_level` / `tingkat`).
///
/// [Classroom.fromJson] normalizes all these variations via [_standardizeJson].
@freezed
abstract class Classroom with _$Classroom {
  const Classroom._();

  const factory Classroom({
    required String id,
    required String name,
    @JsonKey(name: 'homeroom_teacher_name') String? homeroomTeacherName,
    @JsonKey(name: 'homeroom_teacher_id') String? homeroomTeacherId,
    @JsonKey(name: 'student_count') @Default(0) int studentCount,
    @JsonKey(name: 'grade_level') String? gradeLevel,
    @JsonKey(name: 'academic_year_id') String? academicYearId,
  }) = _Classroom;

  factory Classroom.fromJson(Map<String, dynamic> json) =>
      _$ClassroomFromJson(_standardizeJson(json));

  /// True when this classroom has an assigned homeroom teacher.
  bool get hasHomeroomTeacher =>
      (homeroomTeacherName ?? '').isNotEmpty ||
      (homeroomTeacherId ?? '').isNotEmpty;

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);

    // Name (English + Indonesian)
    mapped['name'] ??= mapped['nama'];

    // Grade level
    mapped['grade_level'] ??= mapped['tingkat'];

    // Student count (multiple possible keys)
    mapped['student_count'] ??=
        mapped['jumlah_siswa'] ?? mapped['students_count'];

    // Homeroom teacher can be Map, List<Map>, or flat fields
    final dynamic ht = mapped['homeroom_teacher'];
    if (ht is Map) {
      mapped['homeroom_teacher_id'] ??= ht['id'];
      mapped['homeroom_teacher_name'] ??= ht['name'] ?? ht['nama'];
    } else if (ht is List && ht.isNotEmpty && ht.first is Map) {
      final first = ht.first as Map;
      mapped['homeroom_teacher_id'] ??= first['id'];
      mapped['homeroom_teacher_name'] ??= first['name'] ?? first['nama'];
    }
    // Indonesian structured fallback: `wali_kelas` as Map or List of Maps
    final dynamic wk = mapped['wali_kelas'];
    if (wk is Map) {
      mapped['homeroom_teacher_id'] ??= wk['id'];
      mapped['homeroom_teacher_name'] ??= wk['nama'] ?? wk['name'];
    } else if (wk is List && wk.isNotEmpty && wk.first is Map) {
      final first = wk.first as Map;
      mapped['homeroom_teacher_id'] ??= first['id'];
      mapped['homeroom_teacher_name'] ??= first['nama'] ?? first['name'];
    }

    // Flat fallbacks
    mapped['homeroom_teacher_name'] ??=
        mapped['wali_kelas_nama'] ?? mapped['wali_kelas_name'];
    mapped['homeroom_teacher_id'] ??= mapped['wali_kelas_id'];

    // Coerce required to String
    mapped['id'] = (mapped['id'] ?? '').toString();
    mapped['name'] = (mapped['name'] ?? '').toString();

    // Coerce nullable IDs / names to String
    for (final key in const [
      'homeroom_teacher_id',
      'homeroom_teacher_name',
      'grade_level',
      'academic_year_id',
    ]) {
      if (mapped[key] != null) mapped[key] = mapped[key].toString();
    }

    // Coerce student_count to int
    final sc = mapped['student_count'];
    if (sc is String) {
      mapped['student_count'] = int.tryParse(sc) ?? 0;
    } else if (sc is num) {
      mapped['student_count'] = sc.toInt();
    } else {
      mapped['student_count'] = 0;
    }

    return mapped;
  }
}
