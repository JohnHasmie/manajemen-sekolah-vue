import 'package:flutter/material.dart';

/// RPP / lesson plan format axis.
///
/// Mirrors `App\Enums\LessonPlanFormat` on the backend. The `value`
/// field is the string the API exchanges (`k13`, `rpp_1_halaman`,
/// `modul_ajar`, `file`); UI surfaces use [label], [shortLabel], and
/// [color].
///
/// **Section keys**: structured formats expose their section list via
/// [sectionKeys]. The detail dispatcher and the regen sheet both read
/// from there so we never need a `match` ladder in widget code.
enum LessonPlanFormat {
  k13(
    value: 'k13',
    label: 'K13',
    longLabel: 'Kurikulum 2013',
    shortLabel: 'K13',
  ),
  rpp1Halaman(
    value: 'rpp_1_halaman',
    label: 'RPP 1 Halaman',
    longLabel: 'RPP 1 Halaman',
    shortLabel: '1 HAL',
  ),
  modulAjar(
    value: 'modul_ajar',
    label: 'Modul Ajar',
    longLabel: 'Modul Ajar (Kurikulum Merdeka)',
    shortLabel: 'MODUL AJAR',
  ),
  file(
    value: 'file',
    label: 'Upload File',
    longLabel: 'Upload File (PDF / DOCX)',
    shortLabel: 'FILE',
  );

  const LessonPlanFormat({
    required this.value,
    required this.label,
    required this.longLabel,
    required this.shortLabel,
  });

  /// String value exchanged with the backend.
  final String value;

  /// Display label used in pickers and the AppBar kicker.
  final String label;

  /// Full descriptive label used in the format chooser tile body.
  final String longLabel;

  /// Compact label used in list-card badges (`K13` / `1 HAL` /
  /// `MODUL AJAR` / `FILE`).
  final String shortLabel;

  /// Section keys that compose a complete lesson plan for this format.
  /// `file` returns an empty list — file rows have no editable
  /// sections, only metadata + the attached PDF/DOCX.
  List<String> get sectionKeys {
    switch (this) {
      case LessonPlanFormat.k13:
        return const [
          'identitas',
          'kd_indikator',
          'tujuan',
          'langkah_kegiatan',
          'penilaian',
        ];
      case LessonPlanFormat.rpp1Halaman:
        return const ['tujuan', 'kegiatan', 'asesmen'];
      case LessonPlanFormat.modulAjar:
        return const [
          'info_umum',
          'capaian',
          'tujuan',
          'pemahaman_pemantik',
          'kegiatan',
          'asesmen_refleksi',
        ];
      case LessonPlanFormat.file:
        return const [];
    }
  }

  /// Bahasa Indonesia label for a single section key. Used by detail
  /// section headers, the editor, and the regen sheet checkboxes.
  String sectionLabel(String key) {
    switch (key) {
      // K13
      case 'identitas':
        return 'Identitas';
      case 'kd_indikator':
        return 'Kompetensi Dasar & Indikator';
      case 'langkah_kegiatan':
        return 'Langkah Kegiatan';
      case 'penilaian':
        return 'Penilaian';
      // Shared
      case 'tujuan':
        return 'Tujuan Pembelajaran';
      case 'kegiatan':
        return 'Kegiatan Pembelajaran';
      case 'asesmen':
        return 'Asesmen';
      // Modul Ajar
      case 'info_umum':
        return 'Informasi Umum';
      case 'capaian':
        return 'Capaian Pembelajaran';
      case 'pemahaman_pemantik':
        return 'Pemahaman Bermakna & Pertanyaan Pemantik';
      case 'asesmen_refleksi':
        return 'Asesmen & Refleksi';
      default:
        return key;
    }
  }

  /// True when this format renders as structured sections (and is
  /// eligible for AI generation + per-section regen). `file` rows are
  /// non-structured — the detail screen shows a file-card preview.
  bool get isStructured => this != LessonPlanFormat.file;

  /// True when AI generation is supported. Currently equivalent to
  /// [isStructured] (file uploads can be AI-converted, but that's a
  /// follow-up flow not implemented yet).
  bool get supportsAiGeneration => isStructured;

  /// Brand color for headers, KPI cells, and list-card badges.
  Color get brandColor {
    switch (this) {
      case LessonPlanFormat.k13:
        return const Color(0xFF4338CA); // indigo-600
      case LessonPlanFormat.rpp1Halaman:
        return const Color(0xFF047857); // emerald-600
      case LessonPlanFormat.modulAjar:
        return const Color(0xFF7C3AED); // violet-600
      case LessonPlanFormat.file:
        return const Color(0xFF475569); // slate-600
    }
  }

  /// Darker shade used for the gradient header start color.
  Color get brandDarkColor {
    switch (this) {
      case LessonPlanFormat.k13:
        return const Color(0xFF3730A3); // indigo-700
      case LessonPlanFormat.rpp1Halaman:
        return const Color(0xFF065F46); // emerald-800
      case LessonPlanFormat.modulAjar:
        return const Color(0xFF6D28D9); // violet-700
      case LessonPlanFormat.file:
        return const Color(0xFF334155); // slate-700
    }
  }

  /// Light tint used as the background for badges and section labels.
  Color get tintColor {
    switch (this) {
      case LessonPlanFormat.k13:
        return const Color(0xFFE0E7FF); // indigo-50
      case LessonPlanFormat.rpp1Halaman:
        return const Color(0xFFD1FAE5); // emerald-50
      case LessonPlanFormat.modulAjar:
        return const Color(0xFFEDE9FE); // violet-50
      case LessonPlanFormat.file:
        return const Color(0xFFF1F5F9); // slate-100
    }
  }

  /// Material icon used in chooser tiles and the AppBar badge.
  IconData get icon {
    switch (this) {
      case LessonPlanFormat.k13:
        return Icons.menu_book_rounded;
      case LessonPlanFormat.rpp1Halaman:
        return Icons.description_rounded;
      case LessonPlanFormat.modulAjar:
        return Icons.auto_awesome_rounded;
      case LessonPlanFormat.file:
        return Icons.upload_file_rounded;
    }
  }

  /// Resolve a format from its string value. Falls back to [k13] for
  /// unknown / null inputs so legacy rows keep rendering.
  static LessonPlanFormat fromValue(String? raw) {
    if (raw == null || raw.isEmpty) return LessonPlanFormat.k13;
    for (final f in LessonPlanFormat.values) {
      if (f.value == raw) return f;
    }
    return LessonPlanFormat.k13;
  }

  /// Resolve format from a raw lesson-plan JSON map. Reads `format`
  /// (preferred), falls back to inferring from `file_path`.
  static LessonPlanFormat fromMap(Map<String, dynamic>? map) {
    if (map == null) return LessonPlanFormat.k13;
    final raw = map['format'];
    if (raw is String && raw.isNotEmpty) return fromValue(raw);

    // Legacy heuristic: rows with a file_path but no K13 content are
    // file uploads. The migration backfills `format` for these so this
    // branch only runs for in-flight rows during the transition.
    final filePath = map['file_path'];
    if (filePath is String && filePath.isNotEmpty) {
      final hasContent = (map['learning_objective'] is String &&
              (map['learning_objective'] as String).isNotEmpty) ||
          (map['learning_activities'] is String &&
              (map['learning_activities'] as String).isNotEmpty);
      if (!hasContent) return LessonPlanFormat.file;
    }
    return LessonPlanFormat.k13;
  }
}

/// Read a section value from a lesson plan map. Tries `format_data[key]`
/// first (the new path), then falls back to legacy K13 columns when the
/// row's format is K13.
String? readLessonPlanSection(Map<String, dynamic>? map, String key) {
  if (map == null) return null;
  final formatData = map['format_data'];
  if (formatData is Map) {
    final v = formatData[key];
    if (v is String && v.isNotEmpty) return v;
  }
  // Legacy K13 column fallback
  const legacy = <String, String>{
    'tujuan': 'learning_objective',
    'kd_indikator': 'basic_competence',
    'langkah_kegiatan': 'learning_activities',
    'penilaian': 'assessment',
  };
  final col = legacy[key] ?? key;
  final v = map[col];
  return (v is String && v.isNotEmpty) ? v : null;
}
