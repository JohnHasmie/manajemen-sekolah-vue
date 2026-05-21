// Pure-data helpers for the grade recap screen.
//
// Why this exists
// ---------------
// `teacher_grade_recap_screen.dart` was carrying ~150 lines of
// non-UI work: parsing the API response into the row/cell shape
// the table mixin expects, fetching the lesson-plan title list
// for the add-bab sheet, fetching the grades pool, and deduping
// that pool into picker-ready assessment entries.
//
// None of that touches `setState`, `BuildContext`, or any widget
// state — it's all pure transforms and one-shot service calls.
// Pulling it into a static helper class keeps the screen focused
// on lifecycle + composition and makes the parsing logic easier
// to read in isolation.
//
// The screen still owns disposal of the controllers it holds; this
// helper mutates the maps in place, matching the pattern the
// existing mixins already rely on.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';

/// Bundle returned by [GradeRecapTableBuilder.build].
///
/// Carries the fresh chapter list and table rows. The screen swaps
/// these into its `chapters` / `tableData` fields and the existing
/// table mixin picks up from there.
class GradeRecapTableBuildResult {
  final List<dynamic> chapters;
  final List<Map<String, dynamic>> tableData;

  const GradeRecapTableBuildResult({
    required this.chapters,
    required this.tableData,
  });
}

class GradeRecapTableBuilder {
  /// Pulls lesson-plan titles for the current (teacher, subject, class,
  /// academic-year) slice and returns them as a clean, deduped list of
  /// materi names. Failures return `[]` — the add-bab sheet handles the
  /// empty case by dropping straight into custom-input mode.
  static Future<List<String>> fetchMaterialsForSubject({
    required String teacherId,
    required String subjectId,
    required String classId,
    required String academicYearId,
  }) async {
    try {
      final resp = await LessonPlanService.getLessonPlansPaginated(
        page: 1,
        limit: 100,
        teacherId: teacherId.isEmpty ? null : teacherId,
        subjectId: subjectId.isEmpty ? null : subjectId,
        classId: classId.isEmpty ? null : classId,
        academicYearId: academicYearId.isEmpty ? null : academicYearId,
      );
      final list = resp['data'];
      if (list is! List) return <String>[];
      final titles = <String>{};
      for (final item in list) {
        if (item is! Map) continue;
        final title = (item['title'] ?? item['judul'] ?? item['nama'])
            ?.toString()
            .trim();
        if (title != null && title.isNotEmpty) titles.add(title);
      }
      return titles.toList();
    } catch (e) {
      AppLogger.error('grade_recap', 'Error loading lesson-plan titles: $e');
      return <String>[];
    }
  }

  /// Pulls every grade recorded for this (teacher, subject, year) combo.
  /// Used in two ways: (1) as the pool the add-bab sheet dedupes into a
  /// list of assessments, and (2) as the per-student lookup we consult
  /// when the teacher picks an assessment to fill a new column from.
  static Future<List<dynamic>> fetchGradesForSubject({
    required String teacherId,
    required String subjectId,
    required String classId,
    required String academicYearId,
  }) async {
    try {
      return await GradeService.getGrades(
        teacherId: teacherId.isEmpty ? null : teacherId,
        subjectId: subjectId.isEmpty ? null : subjectId,
        classId: classId.isEmpty ? null : classId,
        academicYearId: academicYearId.isEmpty ? null : academicYearId,
        limit: 1000,
      );
    } catch (e) {
      AppLogger.error('grade_recap', 'Error loading grades pool: $e');
      return <dynamic>[];
    }
  }

  /// Collapses [rawGrades] into a deduped list of assessments, keyed by
  /// (title, type, date). Each entry is the shape the add-bab sheet
  /// expects: `{ title, type, date }`.
  static List<Map<String, dynamic>> deriveAvailableAssessments(
    List<dynamic> rawGrades,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final g in rawGrades) {
      if (g is! Map) continue;
      final title = (g['title'] ?? g['judul'] ?? '').toString().trim();
      final type = (g['type'] ?? g['grade_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final date = (g['date'] ?? g['tanggal'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final key = '$title|$type|$date';
      if (seen.add(key)) {
        out.add({'title': title, 'type': type, 'date': date});
      }
    }
    // Sort: group by type first (tugas/uh/…), then by date ascending.
    out.sort((a, b) {
      final t = (a['type'] as String).compareTo(b['type'] as String);
      if (t != 0) return t;
      return (a['date'] as String).compareTo(b['date'] as String);
    });
    return out;
  }

  /// Converts the API recap response into the `chapters` + `tableData`
  /// shape the table mixin reads, and (re)builds the four controller
  /// maps the screen owns.
  ///
  /// Why mutate maps in place: the screen's mixin contract exposes
  /// these maps as `final` references. We dispose old entries and
  /// repopulate so existing references stay valid.
  static GradeRecapTableBuildResult build({
    required List<dynamic> apiData,
    required Map<String, TextEditingController> predikatControllers,
    required Map<String, TextEditingController> descriptionControllers,
    required Map<String, TextEditingController> scoreControllers,
    required Map<String, FocusNode> scoreFocusNodes,
  }) {
    // Determine chapters from the first student that has bab data.
    List<dynamic> babNames = [];
    int maxBabs = 0;
    for (final row in apiData) {
      final scores = row['bab_scores'];
      final names = row['bab_names'];
      if (scores is List && scores.length > maxBabs) {
        maxBabs = scores.length;
        if (names is List && names.length == scores.length) {
          babNames = names;
        }
      }
    }

    // Default to 1 empty chapter if none exist yet — the screen always
    // shows at least one bab column so the teacher has somewhere to type.
    if (maxBabs == 0) {
      maxBabs = 1;
      babNames = ['Bab 1'];
    }
    final chapters = List.generate(maxBabs, (i) {
      final name = i < babNames.length ? babNames[i]?.toString() : null;
      return {'judul_bab': name ?? 'Bab ${i + 1}'};
    });

    // Dispose old controllers + focus nodes before rebuilding.
    for (final c in scoreControllers.values) {
      c.dispose();
    }
    for (final f in scoreFocusNodes.values) {
      f.dispose();
    }
    for (final c in predikatControllers.values) {
      c.dispose();
    }
    for (final c in descriptionControllers.values) {
      c.dispose();
    }
    scoreControllers.clear();
    scoreFocusNodes.clear();
    predikatControllers.clear();
    descriptionControllers.clear();

    // Format score: integer if whole number, else 1 decimal (preserves
    // precision so 85.5 doesn't get rendered as "86" when reopened).
    String fmt(double? v) {
      if (v == null) return '';
      return v == v.roundToDouble()
          ? v.toInt().toString()
          : v.toStringAsFixed(1);
    }

    // Build table rows.
    final tableData = apiData.map<Map<String, dynamic>>((row) {
      final scId = row['student_class_id']?.toString() ?? '';
      // Use growable list — JSON decode returns fixed-length lists.
      final babScores = row['bab_scores'] is List
          ? List<double?>.from(
              (row['bab_scores'] as List).map(
                (v) => v is num ? v.toDouble() : null,
              ),
            )
          : List<double?>.generate(maxBabs, (_) => null);

      // Pad bab_scores to maxBabs.
      while (babScores.length < maxBabs) {
        babScores.add(null);
      }

      final uts = row['uts_score'] is num
          ? (row['uts_score'] as num).toDouble()
          : null;
      final uas = row['uas_score'] is num
          ? (row['uas_score'] as num).toDouble()
          : null;
      final finalScore = row['final_score'] is num
          ? (row['final_score'] as num).toDouble()
          : null;
      final skillScore = row['skill_score'] is num
          ? (row['skill_score'] as num).toDouble()
          : null;

      // Predikat + deskripsi controllers.
      predikatControllers[scId] = TextEditingController(
        text: row['predikat']?.toString() ?? '',
      );
      descriptionControllers[scId] = TextEditingController(
        text: row['deskripsi']?.toString() ?? '',
      );

      // Score controllers + focus nodes keyed as "scId|type|chapterIndex".
      // Keeping both maps in lock-step lets the cell builder look up its
      // own focus node AND the adjacent row's focus node by the same key
      // shape, which is what powers Enter/Arrow-Down → next row.
      void registerCell(String cellKey, String text) {
        scoreControllers[cellKey] = TextEditingController(text: text);
        scoreFocusNodes[cellKey] = FocusNode(debugLabel: 'score:$cellKey');
      }

      for (int i = 0; i < maxBabs; i++) {
        registerCell('$scId|bab|$i', fmt(babScores[i]));
      }
      registerCell('$scId|uts|null', fmt(uts));
      registerCell('$scId|uas|null', fmt(uas));
      registerCell('$scId|skill_score|null', fmt(skillScore));

      return {
        'student_class_id': scId,
        'student_id': row['student_id']?.toString() ?? '',
        'nama': row['student_name']?.toString() ?? '-',
        'nis': row['nis']?.toString() ?? '',
        'bab_scores': babScores,
        'uts': uts,
        'uas': uas,
        'final_score': finalScore,
        'skill_score': skillScore,
      };
    }).toList();

    return GradeRecapTableBuildResult(chapters: chapters, tableData: tableData);
  }
}
