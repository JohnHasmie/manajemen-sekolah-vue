import 'package:freezed_annotation/freezed_annotation.dart';

part 'subject.freezed.dart';
part 'subject.g.dart';

/// Represents a subject (mata pelajaran) that teachers can be assigned to.
///
/// The API returns subject data in mixed English + Indonesian keys:
///   name / nama, code / kode, class_count / jumlah_kelas,
///   is_active (bool), class_names / kelas_names (comma-separated string).
///
/// [Subject.fromJson] normalizes variations via [_standardizeJson].
@freezed
abstract class Subject with _$Subject {
  const Subject._();

  const factory Subject({
    required String id,
    required String name,
    String? code,
    @JsonKey(name: 'class_count') @Default(0) int classCount,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'class_names') String? classNames,
  }) = _Subject;

  factory Subject.fromJson(Map<String, dynamic> json) =>
      _$SubjectFromJson(_standardizeJson(json));

  /// First character of the subject name (upper-cased), or 'S' as fallback.
  String get initial {
    if (name.isEmpty) return 'S';
    return name[0].toUpperCase();
  }

  /// Parsed, trimmed, non-empty class names from the comma-separated string.
  List<String> get classNameList {
    final raw = classNames ?? '';
    if (raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(json);

    // Name (English + Indonesian)
    m['name'] ??= m['nama'];

    // Code
    m['code'] ??= m['kode'];

    // Class count
    m['class_count'] ??= m['jumlah_kelas'];

    // Class names (comma-separated string)
    m['class_names'] ??= m['kelas_names'];

    // Required -> String
    m['id'] = (m['id'] ?? '').toString();
    m['name'] = (m['name'] ?? '').toString();

    // Nullable strings
    for (final key in const ['code', 'class_names']) {
      if (m[key] != null) m[key] = m[key].toString();
    }

    // class_count -> int
    final cc = m['class_count'];
    if (cc is String) {
      m['class_count'] = int.tryParse(cc) ?? 0;
    } else if (cc is num) {
      m['class_count'] = cc.toInt();
    } else {
      m['class_count'] = 0;
    }

    // is_active -> bool (default true)
    final active = m['is_active'];
    if (active is bool) {
      m['is_active'] = active;
    } else if (active is num) {
      m['is_active'] = active != 0;
    } else if (active is String) {
      m['is_active'] =
          active.toLowerCase() == 'true' || active == '1';
    } else {
      m['is_active'] = true;
    }

    return m;
  }
}
