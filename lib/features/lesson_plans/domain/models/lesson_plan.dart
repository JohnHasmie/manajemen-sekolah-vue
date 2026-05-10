import 'package:freezed_annotation/freezed_annotation.dart';

import 'lesson_plan_format.dart';

part 'lesson_plan.freezed.dart';
part 'lesson_plan.g.dart';

/// Represents a single lesson plan (RPP) submitted by a teacher and
/// reviewed by an admin.
///
/// The API returns lesson plan data in mixed English + Indonesian keys:
///   title / judul, subject_name / mata_pelajaran_nama,
///   class_name / kelas_nama, teacher_name / guru_nama (or nested
///   `teacher.name`), academic_year / tahun_ajaran, notes /catatan,
///   admin_notes / catatan_admin.
///
/// [LessonPlan.fromJson] normalizes all variations via [_standardizeJson].
@freezed
abstract class LessonPlan with _$LessonPlan {
  const LessonPlan._();

  const factory LessonPlan({
    required String id,
    required String title,
    @Default('') String status,
    @JsonKey(name: 'subject_name') String? subjectName,
    @JsonKey(name: 'class_name') String? className,
    @JsonKey(name: 'teacher_name') String? teacherName,
    @JsonKey(name: 'academic_year') String? academicYear,
    String? semester,
    String? notes,
    @JsonKey(name: 'admin_notes') String? adminNotes,
    @JsonKey(name: 'created_at') String? createdAt,
    // Format axis (k13 / rpp_1_halaman / modul_ajar / file). Defaults
    // to k13 for legacy rows where the column is empty.
    @Default('k13') String format,
    @JsonKey(name: 'ai_generated') @Default(false) bool aiGenerated,
    // File upload metadata (only populated when format == 'file')
    @JsonKey(name: 'file_path') String? filePath,
    @JsonKey(name: 'file_name') String? fileName,
    @JsonKey(name: 'file_url') String? fileUrl,
    @JsonKey(name: 'file_size') int? fileSize,
    @JsonKey(name: 'file_mime') String? fileMime,
  }) = _LessonPlan;

  factory LessonPlan.fromJson(Map<String, dynamic> json) =>
      _$LessonPlanFromJson(_standardizeJson(json));

  /// First 10 chars of created_at (YYYY-MM-DD), or '-' if absent.
  String get createdAtDate {
    final raw = createdAt;
    if (raw == null || raw.isEmpty) return '-';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  /// True when the lesson plan has non-empty admin notes.
  bool get hasAdminNotes => (adminNotes ?? '').isNotEmpty;

  /// True when the lesson plan has non-empty teacher notes.
  bool get hasNotes => (notes ?? '').isNotEmpty;

  /// Resolved format enum. Falls back to K13 for legacy rows.
  LessonPlanFormat get resolvedFormat => LessonPlanFormat.fromValue(format);

  /// True when this row is a file upload (PDF/DOCX) — used by the
  /// list-card to render the FILE badge and skip the AI sparkle hint.
  bool get isFileFormat =>
      resolvedFormat == LessonPlanFormat.file ||
      ((filePath ?? '').isNotEmpty && format == 'k13' && (notes ?? '').isEmpty);

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(json);

    // Title: English and Indonesian
    m['title'] ??= m['judul'];

    // Subject name
    m['subject_name'] ??= m['mata_pelajaran_nama'];

    // Class name
    m['class_name'] ??= m['kelas_nama'];

    // Teacher name can be flat (English or Indonesian) or nested
    m['teacher_name'] ??= m['guru_nama'];
    if (m['teacher_name'] == null && m['teacher'] is Map) {
      final t = m['teacher'] as Map;
      m['teacher_name'] = t['name'] ?? t['nama'];
    }

    // Academic year
    m['academic_year'] ??= m['tahun_ajaran'];

    // Notes (English + Indonesian)
    m['notes'] ??= m['catatan'];
    m['admin_notes'] ??= m['catatan_admin'];

    // Required -> String coercion
    m['id'] = (m['id'] ?? '').toString();
    m['title'] = (m['title'] ?? '').toString();
    m['status'] = (m['status'] ?? '').toString();

    // Nullable -> String coercion where present
    for (final key in const [
      'subject_name',
      'class_name',
      'teacher_name',
      'academic_year',
      'semester',
      'notes',
      'admin_notes',
      'created_at',
    ]) {
      if (m[key] != null) m[key] = m[key].toString();
    }

    return m;
  }
}
