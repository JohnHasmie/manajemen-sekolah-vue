import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/grades/data/grade_recap_service.dart';
import 'package:manajemensekolah/features/grades/exports/grade_recap_export_service.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_delete_chapter_dialog.dart';

/// Mixin for grade data operations:
/// bulk grade calculations, chapter management,
/// row recalculation, save, and Excel export.
mixin GradeRecapDataOpsMixin {
  // Required from ConsumerState
  BuildContext get context;
  bool get mounted;
  WidgetRef get ref;
  void setState(VoidCallback fn);
  // ── Abstract bridge to state fields ──────────────
  List<dynamic> get chapters;
  set chapters(List<dynamic> v);

  List<dynamic> get allAvailableChapters;
  set allAvailableChapters(List<dynamic> v);

  List<Map<String, dynamic>> get tableData;
  set tableData(List<Map<String, dynamic>> v);

  List<dynamic> get rawGrades;

  Map<String, dynamic>? get selectedClass;
  Map<String, dynamic>? get selectedSubject;

  Map<String, TextEditingController> get predikatControllers;
  Map<String, TextEditingController> get descriptionControllers;
  Map<String, TextEditingController> get scoreControllers;

  bool get isSaving;
  set isSaving(bool v);

  bool get isExporting;
  set isExporting(bool v);

  bool get hasUnsavedChanges;
  set hasUnsavedChanges(bool v);

  String? recalculateRow(
    Map<String, dynamic> row, {
    required TextEditingController? Function(
      String studentClassId,
      String type,
      int? chapterIndex,
    )?
    getController,
  });

  void showBulkDialog(String type, [int? chapterIndex]);

  void updateAllDescriptions();

  // ── Table value updates ──────────────────────────

  void updateTableValue(
    String studentClassId,
    String type,
    int? chapterIndex,
    double newValue,
  ) {
    setState(() {
      final row = findRow(studentClassId);
      if (row == null) return;

      final key =
          '$studentClassId|$type'
          '|${chapterIndex ?? 'null'}';
      if (scoreControllers.containsKey(key)) {
        scoreControllers[key]!.text = newValue.toStringAsFixed(1);
      }

      setRowValue(row, type, chapterIndex, newValue);
      recalculateRowInternal(row);
    });
  }

  void updateTableValueSilently(
    String studentClassId,
    String type,
    int? chapterIndex,
    double newValue,
  ) {
    setState(() {
      final row = findRow(studentClassId);
      if (row == null) return;
      setRowValue(row, type, chapterIndex, newValue);
      recalculateRowInternal(row);
    });
  }

  Map<String, dynamic>? findRow(String studentClassId) {
    final idx = tableData.indexWhere(
      (r) => r['student_class_id'] == studentClassId,
    );
    return idx != -1 ? tableData[idx] : null;
  }

  void setRowValue(
    Map<String, dynamic> row,
    String type,
    int? chapterIndex,
    double value,
  ) {
    if (type == 'bab' && chapterIndex != null) {
      row['bab_scores'][chapterIndex] = value;
    } else if (type == 'uts') {
      row['uts'] = value;
    } else if (type == 'uas') {
      row['uas'] = value;
    } else if (type == 'skill_score') {
      row['skill_score'] = value;
    }
  }

  // ── Bulk selection ───────────────────────────────

  void applyBulkGrades(
    String type,
    List<Map<String, dynamic>> selected, [
    int? chapterIndex,
  ]) {
    setState(() {
      for (final row in tableData) {
        final scId = row['student_class_id'];
        final avg = calcBulkAverage(scId, type, selected);
        if (avg == null) continue;

        final key =
            '$scId|$type'
            '|${chapterIndex ?? 'null'}';
        if (scoreControllers.containsKey(key)) {
          scoreControllers[key]!.text = avg.toStringAsFixed(1);
        }

        setRowValue(row, type, chapterIndex, avg);
        recalculateRowInternal(row);
        hasUnsavedChanges = true;
      }
    });

    if (type == 'bab') updateAllDescriptions();
  }

  double? calcBulkAverage(
    String studentClassId,
    String type,
    List<Map<String, dynamic>> assessments,
  ) {
    double total = 0;
    int count = 0;

    for (final a in assessments) {
      final title = a['title'];
      final date = a['date'];

      final grades = rawGrades.where((g) {
        final gScId = (g['student_class_id'] ?? g['siswa_kelas_id'])
            ?.toString();
        if (gScId != studentClassId) return false;

        final gTitle =
            g['assessment']?['title'] ?? g['title'] ?? g['judul'] ?? '';
        final gDate =
            g['assessment']?['date'] ?? g['date'] ?? g['tanggal'] ?? '';
        final gType = (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';

        if (type == 'uts' && gType != 'uts' && gType != 'pts') return false;
        if (type == 'uas' && gType != 'uas' && gType != 'pas') return false;
        if (type != 'bab' && type != 'uts' && type != 'uas' && gType != type) {
          return false;
        }

        return gTitle == title && gDate == date;
      }).toList();

      if (grades.isNotEmpty) {
        final s =
            double.tryParse(
              (grades[0]['score'] ?? grades[0]['nilai'] ?? '0').toString(),
            ) ??
            0;
        total += s;
        count++;
      }
    }

    return count > 0 ? total / count : null;
  }

  // ── Chapter management ───────────────────────────

  void addChapter() {
    setState(() {
      final newIdx = chapters.length;
      final name = 'Bab ${newIdx + 1}';
      final ch = {'judul_bab': name, 'judul': name, 'title': name};

      chapters.add(ch);
      allAvailableChapters.add(Map.from(ch));

      for (final row in tableData) {
        final scId = row['student_class_id'];
        if (row['bab_scores'] is List) {
          row['bab_scores'] = List<dynamic>.from(row['bab_scores'])..add(null);
        }
        final key = '$scId|bab|$newIdx';
        scoreControllers[key] = TextEditingController(text: '');
        recalculateRowInternal(row);
      }
    });

    updateAllDescriptions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showBulkDialog('bab', chapters.length - 1);
    });
  }

  void deleteChapter(int chapterIndex) {
    if (chapters.length <= 1) {
      SnackBarUtils.showWarning(context, 'Minimal harus ada 1 materi');
      return;
    }

    showGradeRecapDeleteChapterDialog(
      context: context,
      onConfirm: () {
        setState(() {
          chapters.removeAt(chapterIndex);
          updateTableAfterChapterDelete(chapterIndex);
        });
        updateAllDescriptions();
      },
    );
  }

  void updateTableAfterChapterDelete(int chapterIndex) {
    for (final row in tableData) {
      final scId = row['student_class_id'];

      if (row['bab_scores'] is List &&
          row['bab_scores'].length > chapterIndex) {
        row['bab_scores'].removeAt(chapterIndex);
      }

      scoreControllers.removeWhere((k, _) => k.startsWith('$scId|bab|'));

      for (int i = 0; i < chapters.length; i++) {
        final key = '$scId|bab|$i';
        scoreControllers[key] = TextEditingController(
          text: row['bab_scores'][i] != null
              ? row['bab_scores'][i].toStringAsFixed(1)
              : '',
        );
      }

      recalculateRowInternal(row);
    }
  }

  // ── Row recalculation ────────────────────────────

  void recalculateRowInternal(Map<String, dynamic> row) {
    final text = recalculateRow(row, getController: null);
    if (text != null) {
      final scId = row['student_class_id'];
      final key = '$scId|skill_score|null';
      if (scoreControllers.containsKey(key)) {
        scoreControllers[key]!.text = text;
      }
    }
  }

  // ── Save & Export ────────────────────────────────

  /// Persists the in-memory recap to the server.
  ///
  /// Returns `true` on success, `false` if any error was caught and
  /// surfaced as a snackbar. Callers can branch on the return value —
  /// the modal-dialog entry uses it to auto-dismiss after a clean save.
  Future<bool> saveRecaps() async {
    setState(() => isSaving = true);
    try {
      final provider = ref.read(academicYearRiverpod);
      final ayId =
          (provider.selectedAcademicYear?['id'] ??
                  provider.activeAcademicYear?['id'])
              ?.toString() ??
          '';

      if (ayId.isEmpty) {
        throw Exception('Academic Year is required.');
      }

      final payload = tableData.map((row) {
        final scId = row['student_class_id'];
        return {
          'student_class_id': scId,
          'subject_id': selectedSubject!['id'].toString(),
          'academic_year_id': ayId,
          'predikat': predikatControllers[scId]?.text,
          'deskripsi': descriptionControllers[scId]?.text,
          'bab_scores': row['bab_scores'],
          'bab_names': chapters
              .map((c) => c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab')
              .toList(),
          'uts_score': row['uts'],
          'uas_score': row['uas'],
          'final_score': row['final_score'],
          'skill_score': row['skill_score'],
        };
      }).toList();

      await getIt<ApiGradeRecapService>().batchSaveGradeRecap(payload);

      if (mounted) {
        setState(() => hasUnsavedChanges = false);
        SnackBarUtils.showInfo(context, AppLocalizations.gradeRecapSaved.tr);
      }
      return true;
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
      return false;
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> exportToExcel() async {
    setState(() => isExporting = true);
    try {
      final className =
          selectedClass?['nama'] ?? selectedClass?['name'] ?? 'Kelas';
      final subjectName =
          selectedSubject?['nama'] ??
          selectedSubject?['name'] ??
          'Mata_Pelajaran';

      await ExcelGradeRecapService.exportGradeRecapToExcel(
        tableData: tableData,
        chapters: chapters,
        className: className,
        subjectName: subjectName,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => isExporting = false);
      }
    }
  }
}
