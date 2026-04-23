import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_selection_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/edit_deskripsi_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_editable_cell.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_screen.dart';

/// Mixin for grade UI dialogs and cell builders.
/// Handles grade selection, bulk selection, and description editing.
mixin GradeRecapGradeOpsMixin on ConsumerState<GradeRecapPage> {
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

  /// Parallel to [scoreControllers] — same key shape
  /// (`"$studentClassId|$type|$chapterIndex"`), one [FocusNode] per cell.
  /// Populated by the host state at the same time score controllers are
  /// built. Used here to move focus vertically when the teacher presses
  /// Enter or ArrowDown inside a cell.
  Map<String, FocusNode> get scoreFocusNodes;

  bool get isSaving;
  set isSaving(bool v);

  bool get isExporting;
  set isExporting(bool v);

  bool get hasUnsavedChanges;
  set hasUnsavedChanges(bool v);

  Color getPrimaryColor();

  // ── Grade selection dialog ───────────────────────

  void showGradeSelectionForCell(
    String studentClassId,
    String type,
    int? chapterIndex,
  ) {
    showGradeSelectionDialog(
      context: context,
      rawGrades: rawGrades,
      studentClassId: studentClassId,
      type: type,
      chapterIndex: chapterIndex,
      onAverageSelected: (average) {
        updateTableValue(studentClassId, type, chapterIndex, average);
      },
    );
  }

  // ── Table value updates (delegated to mixin) ────

  void updateTableValue(
    String studentClassId,
    String type,
    int? chapterIndex,
    double newValue,
  );

  void updateTableValueSilently(
    String studentClassId,
    String type,
    int? chapterIndex,
    double newValue,
  );

  void setRowValue(
    Map<String, dynamic> row,
    String type,
    int? chapterIndex,
    double value,
  );

  Map<String, dynamic>? findRow(String studentClassId);

  // ── Editable cell builder ────────────────────────

  Widget buildEditableGradeCell(
    String studentClassId,
    String type,
    int? chapterIndex,
  ) {
    final key =
        '$studentClassId|$type'
        '|${chapterIndex ?? 'null'}';
    final controller = scoreControllers[key];

    if (controller == null) return const Text('-');

    // Resolve focus neighbours by finding this row in [tableData] and
    // looking up the cell in the adjacent row that shares (type,
    // chapterIndex). `null` at the table edges — the cell disables the
    // corresponding movement callback.
    final rowIndex = tableData.indexWhere(
      (r) => r['student_class_id']?.toString() == studentClassId,
    );

    FocusNode? neighbour(int delta) {
      if (rowIndex < 0) return null;
      final target = rowIndex + delta;
      if (target < 0 || target >= tableData.length) return null;
      final neighbourScId =
          tableData[target]['student_class_id']?.toString() ?? '';
      if (neighbourScId.isEmpty) return null;
      final neighbourKey =
          '$neighbourScId|$type|${chapterIndex ?? 'null'}';
      return scoreFocusNodes[neighbourKey];
    }

    final focusNode = scoreFocusNodes[key];
    final downNode = neighbour(1);
    final upNode = neighbour(-1);

    return GradeRecapEditableCell(
      controller: controller,
      focusNode: focusNode,
      onMoveDown: downNode == null ? null : () => downNode.requestFocus(),
      onMoveUp: upNode == null ? null : () => upNode.requestFocus(),
      onHistoryTap: () =>
          showGradeSelectionForCell(studentClassId, type, chapterIndex),
      onChanged: (v) =>
          updateTableValueSilently(studentClassId, type, chapterIndex, v),
    );
  }

  // ── Bulk selection (delegated to mixin) ────────

  void showBulkDialog(String type, [int? chapterIndex]);

  void applyBulkGrades(
    String type,
    List<Map<String, dynamic>> selected, [
    int? chapterIndex,
  ]);

  double? calcBulkAverage(
    String studentClassId,
    String type,
    List<Map<String, dynamic>> assessments,
  );

  // ── Edit description dialog ──────────────────────

  void showEditDeskripsi(String studentClassId, String studentName) {
    final lp = ref.read(languageRiverpod);

    showEditDeskripsiDialog(
      context: context,
      currentDescription: descriptionControllers[studentClassId]?.text ?? '',
      studentName: studentName,
      primaryColor: getPrimaryColor(),
      translations: {
        'editDescTitle': lp.getTranslatedText({
          'en': 'Edit Description - $studentName',
          'id': 'Edit Deskripsi - $studentName',
        }),
        'hint': lp.getTranslatedText({
          'en': 'Enter description...',
          'id': 'Masukkan deskripsi...',
        }),
        'cancel': lp.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
        'save': lp.getTranslatedText({'en': 'Save', 'id': 'Simpan'}),
      },
      onSave: (newDesc) {
        setState(() {
          descriptionControllers[studentClassId]?.text = newDesc;
          final row = findRow(studentClassId);
          if (row != null) {
            row['deskripsi'] = newDesc;
            hasUnsavedChanges = true;
          }
        });
      },
    );
  }

  // ── Chapter management (delegated to mixin) ────

  void addChapter();

  void deleteChapter(int chapterIndex);

  // ── Row recalculation (delegated to mixin) ─────

  void recalculateRowInternal(Map<String, dynamic> row);

  void updateAllDescriptions();

  // ── Save & Export (delegated to mixin) ───────

  Future<bool> saveRecaps();

  Future<void> exportToExcel();
}
