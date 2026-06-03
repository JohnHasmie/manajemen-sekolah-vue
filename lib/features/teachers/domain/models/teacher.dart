import 'package:freezed_annotation/freezed_annotation.dart';

part 'teacher.freezed.dart';
part 'teacher.g.dart';

/// Represents a teacher record with personal info, homeroom assignment, and
/// role.
///
/// The API returns teacher data in several shapes (English + Indonesian keys,
/// nested `user` objects, `homeroom_class` as either Map or List). This model
/// normalizes those variations via [Teacher.fromJson] / [_standardizeJson].
///
/// Use this class as the typed replacement for the `Map<String, dynamic>`
/// `teacher` parameter passed around in teacher-management screens.
@freezed
abstract class Teacher with _$Teacher {
  const Teacher._();

  const factory Teacher({
    required String id,
    required String name,
    required String email,
    required String role,
    @JsonKey(name: 'employee_number') String? employeeNumber,
    @JsonKey(name: 'phone_number') String? phoneNumber,
    String? address,
    @JsonKey(name: 'homeroom_class_id') String? homeroomClassId,
    @JsonKey(name: 'homeroom_class_name') String? homeroomClassName,
    @JsonKey(name: 'subject_ids') List<String>? subjectIds,
    @JsonKey(name: 'subject_names') List<String>? subjectNames,
    @JsonKey(name: 'user_id') String? userId,
  }) = _Teacher;

  /// Parse a teacher from one of the API's several response shapes.
  factory Teacher.fromJson(Map<String, dynamic> json) =>
      _$TeacherFromJson(_standardizeJson(json));

  /// True when this teacher has an assigned homeroom class.
  bool get isHomeroomTeacher =>
      homeroomClassId != null && homeroomClassId!.isNotEmpty;

  /// Display-friendly initials, e.g. "John Doe" → "JD".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);

    // Name (English and Indonesian)
    mapped['name'] ??= mapped['nama'];

    // Email: nested under `user` or flat
    if (mapped['user'] is Map) {
      final user = mapped['user'] as Map;
      mapped['email'] ??= user['email'];
      mapped['user_id'] ??= user['id'];
      mapped['phone_number'] ??= user['phone_number'] ?? user['phone'];
    }

    // Homeroom class can arrive as:
    //   homeroom_class: Map { id, name }
    //   homeroom_class: List [ { id, name }, ... ]
    //   homeroom_classes: List [ ... ]
    //   homeroom_class_name: String (flat)
    final dynamic hc = mapped['homeroom_class'] ?? mapped['homeroom_classes'];
    if (hc is Map) {
      mapped['homeroom_class_id'] ??= hc['id'];
      mapped['homeroom_class_name'] ??= hc['name'] ?? hc['nama'];
    } else if (hc is List && hc.isNotEmpty && hc.first is Map) {
      final first = hc.first as Map;
      mapped['homeroom_class_id'] ??= first['id'];
      mapped['homeroom_class_name'] ??= first['name'] ?? first['nama'];
    }

    // Indonesian fallbacks — NIP (Nomor Induk Pegawai) and NUPTK are
    // alternate names for the employee-identifier field.
    mapped['employee_number'] ??=
        mapped['nomor_induk'] ?? mapped['nip'] ?? mapped['nuptk'];
    mapped['phone_number'] ??= mapped['nomor_hp'];
    mapped['address'] ??= mapped['alamat'];

    // Subjects can arrive as list of Maps or list of IDs
    if (mapped['subjects'] is List) {
      final subs = mapped['subjects'] as List;
      if (subs.isNotEmpty && subs.first is Map) {
        mapped['subject_ids'] ??= subs
            .map((s) => (s as Map)['id']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        mapped['subject_names'] ??= subs
            .map((s) => (s as Map)['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }

    // teacher_id is an alias for id in some API shapes (e.g. report cards)
    mapped['id'] ??= mapped['teacher_id'];

    // Force required fields to be strings (defensive against null/int id)
    mapped['id'] = (mapped['id'] ?? '').toString();
    mapped['name'] = (mapped['name'] ?? '').toString();
    mapped['email'] = (mapped['email'] ?? '').toString();
    mapped['role'] = (mapped['role'] ?? 'guru').toString();

    // Convert nullable ID-like fields to String where present
    for (final key in const [
      'employee_number',
      'phone_number',
      'address',
      'homeroom_class_id',
      'homeroom_class_name',
      'user_id',
    ]) {
      if (mapped[key] != null) mapped[key] = mapped[key].toString();
    }

    // Normalize subject_ids / subject_names to List<String>
    if (mapped['subject_ids'] is List) {
      mapped['subject_ids'] = (mapped['subject_ids'] as List)
          .map((e) => e.toString())
          .toList();
    }
    if (mapped['subject_names'] is List) {
      mapped['subject_names'] = (mapped['subject_names'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return mapped;
  }
}
