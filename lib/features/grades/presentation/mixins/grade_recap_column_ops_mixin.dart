import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/features/grades/data/grade_recap_table_builder.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/add_chapter_sheet.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/column_source_picker_sheet.dart';

/// Column-source + chapter management for [GradeRecapPage].
///
/// Houses the concrete implementations the screen previously declared
/// inline: the weighted-average row recalculation, the bulk/edit sheet
/// router ([showBulkDialog]), the fixed-column (UTS/UAS/Keterampilan)
/// source picker, and add/delete chapter. These all share the same
/// "pull per-student scores from an assessment in [rawGrades]" logic, so
/// they live together.
///
/// Applied AFTER [GradeRecapDataOpsMixin] in the screen's `with` clause
/// so the implementations here win over that mixin's defaults for the
/// methods both declare ([recalculateRow], [showBulkDialog], [addChapter],
/// [deleteChapter]) — preserving the original screen-overrides-mixin
/// resolution.
mixin GradeRecapColumnOpsMixin on ConsumerState<GradeRecapPage> {
  // ── Bridge to state fields (implemented by the host State) ─────────
  List<dynamic> get chapters;
  set chapters(List<dynamic> v);

  List<Map<String, dynamic>> get tableData;

  List<dynamic> get rawGrades;

  List<String> get availableMaterials;

  Map<String, TextEditingController> get predikatControllers;
  Map<String, TextEditingController> get scoreControllers;
  Map<String, FocusNode> get scoreFocusNodes;

  set hasUnsavedChanges(bool v);

  Color getPrimaryColor();

  /// Provided by [GradeRecapDataOpsMixin] — recomputes a single row's
  /// final score + predikat in place.
  void recalculateRowInternal(Map<String, dynamic> row);

  String? recalculateRow(
    Map<String, dynamic> row, {
    required TextEditingController? Function(
      String studentClassId,
      String type,
      int? chapterIndex,
    )?
    getController,
  }) {
    // Weighted average across three buckets: bab (40%), UTS (20%),
    // UAS (40%). We only include a bucket in the weight denominator if
    // it actually has data — otherwise an empty UTS/UAS would silently
    // drag the final score toward zero and a 100 on bab alone would
    // score 40, stamping the student with a "D".
    final babScores = row['bab_scores'] as List?;
    double babSum = 0;
    int babCount = 0;
    if (babScores != null) {
      for (final s in babScores) {
        if (s is num && s > 0) {
          babSum += s.toDouble();
          babCount++;
        }
      }
    }
    final double? babAvg = babCount > 0 ? babSum / babCount : null;

    final utsRaw = (row['uts'] as num?)?.toDouble();
    final uasRaw = (row['uas'] as num?)?.toDouble();
    // Treat 0 as "not yet entered". A real zero is rare and teachers can
    // always bump it to 0.1 if they need to preserve an actual failing
    // mark while UAS is pending.
    final double? uts = (utsRaw != null && utsRaw > 0) ? utsRaw : null;
    final double? uas = (uasRaw != null && uasRaw > 0) ? uasRaw : null;

    double weightedSum = 0;
    double totalWeight = 0;
    if (babAvg != null) {
      weightedSum += babAvg * 0.4;
      totalWeight += 0.4;
    }
    if (uts != null) {
      weightedSum += uts * 0.2;
      totalWeight += 0.2;
    }
    if (uas != null) {
      weightedSum += uas * 0.4;
      totalWeight += 0.4;
    }

    if (totalWeight == 0) return null; // nothing filled yet

    final finalScore = weightedSum / totalWeight;
    row['final_score'] = finalScore;

    // Auto-generate predikat.
    final scId = row['student_class_id'];
    final predikat = finalScore >= 90
        ? 'A'
        : finalScore >= 80
        ? 'B'
        : finalScore >= 70
        ? 'C'
        : 'D';
    predikatControllers[scId]?.text = predikat;
    return null;
  }

  void showBulkDialog(String type, [int? chapterIndex]) {
    // Fix-EE — UTS / UAS / Keterampilan columns now route to a
    // single-step source picker so teachers can pull per-student
    // scores from existing Buku Nilai assessments, matching the bab
    // column behaviour. Bab columns keep using the 2-step
    // `showAddChapterSheet` (materi → source).
    if (type == 'uts' || type == 'uas' || type == 'skill_score') {
      _showFixedColumnSourcePicker(type);
      return;
    }

    // SS3-HH — long-press "Edit bab" lands here. Re-uses the same
    // `showAddChapterSheet` the "+" add flow uses, but in edit mode
    // (initialName prefilled, label flipped to "Simpan").
    if (type != 'bab' || chapterIndex == null) return;
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return;

    final ch = chapters[chapterIndex] as Map;
    final currentName =
        (ch['judul_bab'] ??
                ch['judul'] ??
                ch['title'] ??
                'Bab ${chapterIndex + 1}')
            .toString();

    final assessments = GradeRecapTableBuilder.deriveAvailableAssessments(
      rawGrades,
    );

    showAddChapterSheet(
      context: context,
      primaryColor: getPrimaryColor(),
      nextChapterIndex: chapterIndex,
      availableMaterials: availableMaterials,
      availableAssessments: assessments,
      initialName: currentName,
      isEdit: true,
    ).then((result) {
      if (result == null || result.name.isEmpty || !mounted) return;
      setState(() {
        final updated = Map<String, dynamic>.from(ch);
        updated['judul_bab'] = result.name;
        updated['judul'] = result.name;
        updated['title'] = result.name;
        chapters = List.from(chapters)..[chapterIndex] = updated;

        // If the teacher picked an assessment to re-pull scores from
        // (instead of "Input Manual"), refill this column's scores for
        // every row. Mirrors the same pull logic `addChapter` does for
        // a newly-created column.
        if (result.assessment != null) {
          final pickTitle = (result.assessment!['title'] ?? '').toString();
          final pickType = (result.assessment!['type'] ?? '').toString();
          final pickDate = (result.assessment!['date'] ?? '').toString();
          final Map<String, double> perStudentScore = {};
          for (final g in rawGrades) {
            if (g is! Map) continue;
            final title = (g['title'] ?? g['judul'] ?? '').toString();
            final gType = (g['type'] ?? g['grade_type'] ?? '')
                .toString()
                .toLowerCase();
            final date = (g['date'] ?? g['tanggal'] ?? '').toString();
            if (title != pickTitle || gType != pickType || date != pickDate) {
              continue;
            }
            final scId = (g['student_class_id'] ?? '').toString();
            final score = g['score'] ?? g['nilai'];
            if (scId.isEmpty || score == null) continue;
            final parsed = score is num
                ? score.toDouble()
                : double.tryParse(score.toString());
            if (parsed != null) perStudentScore[scId] = parsed;
          }
          for (final row in tableData) {
            final scId = row['student_class_id'].toString();
            final pulled = perStudentScore[scId];
            final babList = row['bab_scores'] as List;
            if (chapterIndex < babList.length) {
              babList[chapterIndex] = pulled;
            }
            final key = '$scId|bab|$chapterIndex';
            scoreControllers[key]?.text = pulled != null
                ? pulled.toStringAsFixed(0)
                : '';
            recalculateRowInternal(row);
          }
        }

        hasUnsavedChanges = true;
      });
    });
  }

  /// Fix-EE — opens the source picker for one of the three fixed
  /// columns (UTS / UAS / skill_score) and applies the result.
  ///
  /// On "Input Manual" the column is cleared for every row. On
  /// picking an assessment, per-student scores are pulled from
  /// `rawGrades` and written into the matching column. Either path
  /// triggers a full row recalculation so the Predikat + final score
  /// reflect the new values and the Simpan button enables.
  void _showFixedColumnSourcePicker(String type) async {
    final assessments = GradeRecapTableBuilder.deriveAvailableAssessments(
      rawGrades,
    );

    final result = await showColumnSourcePickerSheet(
      context: context,
      primaryColor: getPrimaryColor(),
      columnType: type,
      allAssessments: assessments,
    );

    if (!mounted || result == null) return;

    setState(() {
      if (result.assessment == null) {
        // Input Manual — clear the column for every row.
        for (final row in tableData) {
          final scId = row['student_class_id'].toString();
          _setFixedColumnValue(row, type, null);
          final key = '$scId|$type|null';
          scoreControllers[key]?.text = '';
          recalculateRowInternal(row);
        }
      } else {
        // Pull per-student scores matching the picked assessment.
        final pickTitle = (result.assessment!['title'] ?? '').toString();
        final pickType = (result.assessment!['type'] ?? '').toString();
        final pickDate = (result.assessment!['date'] ?? '').toString();

        final perStudentScore = <String, double>{};
        for (final g in rawGrades) {
          if (g is! Map) continue;
          final title = (g['title'] ?? g['judul'] ?? '').toString();
          final gType = (g['type'] ?? g['grade_type'] ?? '')
              .toString()
              .toLowerCase();
          final date = (g['date'] ?? g['tanggal'] ?? '').toString();
          if (title != pickTitle || gType != pickType || date != pickDate) {
            continue;
          }
          final scId = (g['student_class_id'] ?? '').toString();
          final score = g['score'] ?? g['nilai'];
          if (scId.isEmpty || score == null) continue;
          final parsed = score is num
              ? score.toDouble()
              : double.tryParse(score.toString());
          if (parsed != null) perStudentScore[scId] = parsed;
        }

        for (final row in tableData) {
          final scId = row['student_class_id'].toString();
          final pulled = perStudentScore[scId];
          _setFixedColumnValue(row, type, pulled);
          final key = '$scId|$type|null';
          scoreControllers[key]?.text = pulled != null
              ? (pulled == pulled.roundToDouble()
                    ? pulled.toInt().toString()
                    : pulled.toStringAsFixed(1))
              : '';
          recalculateRowInternal(row);
        }
      }
      hasUnsavedChanges = true;
    });
  }

  /// Writes [value] (or `null` to clear) into the appropriate fixed-
  /// column slot of [row]. Pulled out so both the "manual" branch and
  /// the "pull from assessment" branch share one place that knows the
  /// row schema.
  void _setFixedColumnValue(
    Map<String, dynamic> row,
    String type,
    double? value,
  ) {
    switch (type) {
      case 'uts':
        row['uts'] = value;
        break;
      case 'uas':
        row['uas'] = value;
        break;
      case 'skill_score':
        row['skill_score'] = value;
        break;
    }
  }

  void addChapter() async {
    // Two-step sheet:
    //   (1) Materi / Bab — pick a lesson-plan title or type a custom name.
    //   (2) Cara mengisi nilai — pick an existing assessment to pull scores
    //       from, or "Input Manual" to leave the new column blank.
    final assessments = GradeRecapTableBuilder.deriveAvailableAssessments(
      rawGrades,
    );
    final result = await showAddChapterSheet(
      context: context,
      primaryColor: getPrimaryColor(),
      nextChapterIndex: chapters.length,
      availableMaterials: availableMaterials,
      availableAssessments: assessments,
    );
    if (result == null || result.name.isEmpty || !mounted) return;

    setState(() {
      final newIndex = chapters.length;
      chapters = [
        ...chapters,
        {'judul_bab': result.name},
      ];

      // Build a per-student lookup from the chosen assessment. If the
      // teacher picked "Input Manual" (assessment == null), every student
      // gets a blank cell.
      final Map<String, double> perStudentScore = {};
      if (result.assessment != null) {
        final pickTitle = (result.assessment!['title'] ?? '').toString();
        final pickType = (result.assessment!['type'] ?? '').toString();
        final pickDate = (result.assessment!['date'] ?? '').toString();
        for (final g in rawGrades) {
          if (g is! Map) continue;
          final title = (g['title'] ?? g['judul'] ?? '').toString();
          final type = (g['type'] ?? g['grade_type'] ?? '')
              .toString()
              .toLowerCase();
          final date = (g['date'] ?? g['tanggal'] ?? '').toString();
          if (title != pickTitle || type != pickType || date != pickDate) {
            continue;
          }
          final scId = (g['student_class_id'] ?? '').toString();
          final score = g['score'] ?? g['nilai'];
          if (scId.isEmpty || score == null) continue;
          final parsed = score is num
              ? score.toDouble()
              : double.tryParse(score.toString());
          if (parsed != null) perStudentScore[scId] = parsed;
        }
      }

      for (final row in tableData) {
        final scId = row['student_class_id'].toString();
        final pulled = perStudentScore[scId];
        (row['bab_scores'] as List).add(pulled);
        final key = '$scId|bab|$newIndex';
        scoreControllers[key] = TextEditingController(
          text: pulled != null ? pulled.toStringAsFixed(0) : '',
        );
        scoreFocusNodes[key] = FocusNode(debugLabel: 'score:$key');
      }

      // If we pre-filled any cell, recalculate every row so final score
      // and predikat reflect the new column immediately.
      if (perStudentScore.isNotEmpty) {
        for (final row in tableData) {
          recalculateRowInternal(row);
        }
      }
      hasUnsavedChanges = true;
    });
  }

  // SS3-HH — the rename-only `editChapter` method was removed. The
  // long-press path now opens the full bulk editor (`showBulkDialog`)
  // which already lets the teacher edit the bab name plus the per-row
  // scores. Two affordances for the same column collapsed into one.

  void deleteChapter(int chapterIndex) async {
    if (chapters.length <= 1) return;

    // Long-press already raised the gesture cost, but the actual
    // mutation wipes scores from every student row in this column.
    // Route through the shared ConfirmationDialog (gradient header,
    // "Hapus" / "Batal" pair) so the destructive confirm matches
    // every other destructive flow in the app.
    final ch = chapters[chapterIndex] as Map;
    final name =
        (ch['judul_bab'] ??
                ch['judul'] ??
                ch['title'] ??
                'Bab ${chapterIndex + 1}')
            .toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: kGraDeleteChapter.tr,
        content:
            '${kGraConfirmDelete.tr} "$name"? '
            '${kGraAllGradesWillBeDeleted.tr}.',
        confirmText: kDelete.tr,
        confirmColor: ColorUtils.error600,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      chapters = List.from(chapters)..removeAt(chapterIndex);
      for (final row in tableData) {
        (row['bab_scores'] as List).removeAt(chapterIndex);
      }
      // Rebuild score controllers + focus nodes for bab columns. We drop
      // every existing bab entry and re-create in sequence so the column
      // index in the key matches its new position in `bab_scores`.
      final keysToRemove = scoreControllers.keys
          .where((k) => k.contains('|bab|'))
          .toList();
      for (final key in keysToRemove) {
        scoreControllers[key]?.dispose();
        scoreControllers.remove(key);
        scoreFocusNodes[key]?.dispose();
        scoreFocusNodes.remove(key);
      }
      for (final row in tableData) {
        final scId = row['student_class_id'];
        final scores = row['bab_scores'] as List;
        for (int i = 0; i < scores.length; i++) {
          final key = '$scId|bab|$i';
          scoreControllers[key] = TextEditingController(
            text: scores[i] != null
                ? (scores[i] as num).toStringAsFixed(0)
                : '',
          );
          scoreFocusNodes[key] = FocusNode(debugLabel: 'score:$key');
        }
      }
      hasUnsavedChanges = true;
    });
  }
}
