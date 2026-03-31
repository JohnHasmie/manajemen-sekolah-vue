// Pure data-computation helpers for the grade recap table.
// Extracted from _GradeRecapPageState — these functions have NO dependency on
// widget state, BuildContext, or TextEditingControllers, so they are unit-
// testable and belong in a separate helper file.
//
// In Laravel terms this is a "Service" layer: the screen (Controller) delegates
// business-logic to these pure functions and only handles setState + UI.

/// Result returned by [buildGradeRecapRows].
///
/// Contains:
/// - [rows] — the structured table data (one entry per student).
/// - [predikatTexts] — initial text for each predikat TextEditingController.
/// - [descriptionTexts] — initial text for each description controller.
/// - [scoreTexts] — initial text for every score controller, keyed by
///     `'$studentClassId|$type|${chapterIndex ?? "null"}'`.
class GradeRecapBuildResult {
  final List<Map<String, dynamic>> rows;
  final Map<String, String> predikatTexts;
  final Map<String, String> descriptionTexts;
  final Map<String, String> scoreTexts;

  const GradeRecapBuildResult({
    required this.rows,
    required this.predikatTexts,
    required this.descriptionTexts,
    required this.scoreTexts,
  });
}

/// Transforms raw API data into structured table rows.
///
/// Like a Vue computed that pivots student/grade/recap data for display.
/// Returns a [GradeRecapBuildResult] so the caller can create
/// TextEditingControllers from [GradeRecapBuildResult.scoreTexts] etc.
///
/// Equivalent to `GradeRecapService::buildTableRows()` in Laravel.
GradeRecapBuildResult buildGradeRecapRows({
  required List<dynamic> students,
  required List<dynamic> chapters,
  required List<dynamic> rawGrades,
  required List<dynamic> recaps,
}) {
  final List<Map<String, dynamic>> tableData = [];
  final Map<String, String> predikatTexts = {};
  final Map<String, String> descriptionTexts = {};
  final Map<String, String> scoreTexts = {};

  final String autoDeskripsi =
      "Telah memahami materi ${chapters.map((c) => c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab').join(', ')} dengan cukup baik.";

  for (var studentRow in students) {
    final student = studentRow['student'] ?? studentRow;
    final studentClassId =
        (studentRow['student_class_id'] ?? studentRow['id']).toString();

    // Filter grades for this student
    final studentGrades = rawGrades.where((g) {
      final gStudentClassId =
          (g['student_class_id'] ?? g['siswa_kelas_id'])?.toString();
      return gStudentClassId == studentClassId;
    }).toList();

    // Group daily grades (harian)
    final List<dynamic> dailyGrades = studentGrades.where((g) {
      final typeStr =
          (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
      return [
        'uh',
        'tugas',
        'praktek',
        'formatif',
        'sumatif',
      ].contains(typeStr);
    }).toList();

    // Sort by date
    dailyGrades.sort(
      (a, b) => (a['tanggal'] ?? '').compareTo(b['tanggal'] ?? ''),
    );

    List<double?> chapterScores = [];
    final int numChapters = chapters.isNotEmpty ? chapters.length : 1;

    // Distribute daily grades into chapters evenly
    if (dailyGrades.isNotEmpty && numChapters > 0) {
      final int itemsPerChapter = (dailyGrades.length / numChapters).ceil();
      for (int i = 0; i < numChapters; i++) {
        final int start = i * itemsPerChapter;
        final int end = (start + itemsPerChapter > dailyGrades.length)
            ? dailyGrades.length
            : start + itemsPerChapter;

        if (start < dailyGrades.length) {
          final chunk = dailyGrades.sublist(start, end);
          double sum = 0;
          for (var c in chunk) {
            final double val =
                double.tryParse(
                  (c['score'] ?? c['nilai'] ?? '0').toString(),
                ) ??
                0;
            sum += val;
          }
          chapterScores.add(sum / chunk.length);
        } else {
          chapterScores.add(null);
        }
      }
    } else {
      chapterScores = List.filled(numChapters, null);
    }

    // UTS/PTS & UAS/PAS
    final utsGrade = studentGrades.firstWhere(
      (g) {
        final type = (g['type'] ?? g['jenis'])?.toString().toLowerCase();
        return type == 'uts' || type == 'pts';
      },
      orElse: () => null,
    );
    final uasGrade = studentGrades.firstWhere(
      (g) {
        final type = (g['type'] ?? g['jenis'])?.toString().toLowerCase();
        return type == 'uas' || type == 'pas';
      },
      orElse: () => null,
    );

    // Check existing saved Recap
    final existingRecap = recaps.firstWhere(
      (r) => r['student_class_id']?.toString() == studentClassId,
      orElse: () => null,
    );

    double? utsScore;
    double? uasScore;
    List<double?> finalChapterScores = [];

    if (existingRecap != null && existingRecap['bab_scores'] != null) {
      // Load from saved recap
      final savedChapterScores =
          List<dynamic>.from(existingRecap['bab_scores']);
      finalChapterScores = savedChapterScores
          .map((s) => s != null ? double.tryParse(s.toString()) : null)
          .toList();
      utsScore = existingRecap['uts_score'] != null
          ? double.tryParse(existingRecap['uts_score'].toString())
          : null;
      uasScore = existingRecap['uas_score'] != null
          ? double.tryParse(existingRecap['uas_score'].toString())
          : null;
    } else {
      // Calculate from raw grades
      utsScore = utsGrade != null
          ? double.tryParse(
              (utsGrade['score'] ?? utsGrade['nilai'] ?? '0').toString(),
            )
          : null;
      uasScore = uasGrade != null
          ? double.tryParse(
              (uasGrade['score'] ?? uasGrade['nilai'] ?? '0').toString(),
            )
          : null;
      finalChapterScores = chapterScores;
    }

    // Calculate final average
    double finalScoreValue = 0;
    int componentCount = 0;

    for (var score in finalChapterScores) {
      if (score != null) {
        finalScoreValue += score;
        componentCount++;
      }
    }
    if (utsScore != null) {
      finalScoreValue += utsScore;
      componentCount++;
    }
    if (uasScore != null) {
      finalScoreValue += uasScore;
      componentCount++;
    }

    final double finalAverage =
        componentCount > 0 ? (finalScoreValue / componentCount) : 0;

    final double currentSkillScore =
        (existingRecap != null && existingRecap['skill_score'] != null)
        ? (double.tryParse(existingRecap['skill_score'].toString()) ??
              finalAverage)
        : finalAverage;

    final String currentPredikat =
        existingRecap != null ? (existingRecap['predikat'] ?? '') : '';
    final String currentDescription = existingRecap != null
        ? (existingRecap['deskripsi'] ?? '')
        : (chapters.isNotEmpty ? autoDeskripsi : '');

    // Record initial controller texts
    predikatTexts[studentClassId] = currentPredikat;
    descriptionTexts[studentClassId] = currentDescription;

    for (int i = 0; i < numChapters; i++) {
      scoreTexts['$studentClassId|bab|$i'] =
          finalChapterScores[i]?.toStringAsFixed(1) ?? '';
    }
    scoreTexts['$studentClassId|uts|null'] =
        utsScore?.toStringAsFixed(1) ?? '';
    scoreTexts['$studentClassId|uas|null'] =
        uasScore?.toStringAsFixed(1) ?? '';
    scoreTexts['$studentClassId|skill_score|null'] =
        currentSkillScore.toStringAsFixed(1);

    tableData.add({
      'student_class_id': studentClassId,
      'nis': (student['student_number'] ?? student['nis'] ?? '-').toString(),
      'nama': (student['name'] ?? student['nama'] ?? '-').toString(),
      'bab_scores': finalChapterScores,
      'uts': utsScore,
      'uas': uasScore,
      'final_score': finalAverage,
      'skill_score': currentSkillScore,
      'predikat': currentPredikat,
      'deskripsi': currentDescription,
    });
  }

  return GradeRecapBuildResult(
    rows: tableData,
    predikatTexts: predikatTexts,
    descriptionTexts: descriptionTexts,
    scoreTexts: scoreTexts,
  );
}

/// Overwrites chapter names in [chapters] using the longest bab_names list
/// found among saved [recaps].
///
/// Mutates [chapters] in-place, same as before extraction.
/// Equivalent to a helper inside `GradeRecapService::applyRecapChapterNames()`.
void applyRecapChapterNames({
  required List<dynamic> chapters,
  required List<dynamic> recaps,
}) {
  if (recaps.isEmpty) return;

  List<String> longestChapterNames = [];
  for (var r in recaps) {
    if (r['bab_names'] != null && r['bab_names'] is List) {
      final names = List<String>.from(r['bab_names']);
      if (names.length > longestChapterNames.length) {
        longestChapterNames = names;
      }
    }
  }

  if (longestChapterNames.isEmpty) return;

  while (chapters.length < longestChapterNames.length) {
    chapters.add({
      'judul_bab': 'Bab ${chapters.length + 1}',
      'judul': 'Bab ${chapters.length + 1}',
      'title': 'Bab ${chapters.length + 1}',
    });
  }

  for (int i = 0; i < longestChapterNames.length; i++) {
    if (i < chapters.length) {
      chapters[i]['judul_bab'] = longestChapterNames[i];
      chapters[i]['judul'] = longestChapterNames[i];
      chapters[i]['title'] = longestChapterNames[i];
    }
  }
}

/// Recalculates `final_score` (and optionally `skill_score`) for a single
/// table row after any score edit.
///
/// Mutates [row] in-place and returns the new final score.
/// Returns the [skillScoreControllerText] to push into the controller (or null
/// if skill_score was not auto-updated).
///
/// In Laravel terms: a pure scoring helper — no DB access.
String? recalculateRow(
  Map<String, dynamic> row, {
  required Map<String, dynamic> Function(String key)? getController,
}) {
  double sum = 0;
  int count = 0;
  final double oldFinalScore = row['final_score'] ?? 0.0;

  for (var s in row['bab_scores']) {
    if (s != null) {
      sum += s;
      count++;
    }
  }
  if (row['uts'] != null) {
    sum += row['uts'];
    count++;
  }
  if (row['uas'] != null) {
    sum += row['uas'];
    count++;
  }

  final double newFinalScore = count > 0 ? sum / count : 0.0;
  row['final_score'] = newFinalScore;

  // Auto-update skill_score if it was tracking the previous final_score or is 0
  final double currentSkill = row['skill_score'] ?? 0.0;
  if (currentSkill == oldFinalScore || currentSkill == 0.0) {
    row['skill_score'] = newFinalScore;
    return newFinalScore.toStringAsFixed(1);
  }
  return null;
}
