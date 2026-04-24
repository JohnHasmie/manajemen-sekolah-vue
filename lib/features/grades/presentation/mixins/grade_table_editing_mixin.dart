import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_table_widget.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_logic_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_helpers_mixin.dart';

mixin GradeTableEditingMixin
    on State<GradeTableWidget>, GradeTableLogicMixin, GradeTableHelpersMixin {
  String? get editingKey;
  int get editingStudentIdx;
  int get editingColIdx;
  TextEditingController get editController;
  FocusNode get editFocus;
  String? get errorMessage;
  bool get isSaving;

  void setEditingState({
    String? editingKey,
    int? editingStudentIdx,
    int? editingColIdx,
    String? errorMessage,
    bool? isSaving,
  });

  // fmt() and cellKey() inherited from GradeTableHelpersMixin — do not redefine

  /// Starts editing at specific student and column indices
  void startEditingAt(int studentIdx, int colIdx, List<ColDef> cols) {
    if (!widget.canEdit || widget.isReadOnly) return;
    if (studentIdx < 0 || studentIdx >= widget.filteredStudentList.length) {
      return;
    }
    if (colIdx < 0 || colIdx >= cols.length) return;

    final col = cols[colIdx];
    if (col.isPlaceholder) return;

    final student = widget.filteredStudentList[studentIdx];

    if (widget.onInlineSave == null) {
      widget.onCellTap(student, col.type, col.header);
      return;
    }

    final rec = getGrade(student, col.type, col.header);
    final currentValue = rec?.isNotEmpty == true ? fmt(rec!['score']) : '';

    setEditingState(
      editingKey: cellKey(student, col.type, col.index),
      editingStudentIdx: studentIdx,
      editingColIdx: colIdx,
      errorMessage: null,
    );

    editController.text = currentValue;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      editFocus.requestFocus();
      editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: editController.text.length,
      );
    });
  }

  /// Starts editing for a given student and column
  void startEditing(Student student, ColDef col, List<ColDef> cols) {
    final studentIdx = widget.filteredStudentList.indexOf(student);
    final colIdx = cols.indexOf(col);
    startEditingAt(studentIdx, colIdx, cols);
  }

  /// Finishes editing, saves value, and moves to next cell
  Future<void> finishAndMove(
    int nextStudentIdx,
    int nextColIdx,
    List<ColDef> cols,
  ) async {
    if (isSaving) return;
    final value = editController.text.trim();
    final studentIdx = editingStudentIdx;
    final colIdx = editingColIdx;

    if (studentIdx < 0 || colIdx < 0) return;

    final student = widget.filteredStudentList[studentIdx];
    final col = cols[colIdx];

    setEditingState(isSaving: true);

    if (widget.onInlineSave != null && value.isNotEmpty) {
      final error = await widget.onInlineSave!(
        student,
        col.type,
        col.header,
        value,
      );
      if (!mounted) return;
      if (error != null) {
        setEditingState(errorMessage: error, isSaving: false);
        editFocus.requestFocus();
        return;
      }
    }

    setEditingState(isSaving: false, editingKey: null, errorMessage: null);

    if (nextStudentIdx >= 0 && nextColIdx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startEditingAt(nextStudentIdx, nextColIdx, cols);
      });
    }
  }

  /// Cancels current editing operation
  void cancelEditing() {
    setEditingState(
      editingKey: null,
      errorMessage: null,
      editingStudentIdx: -1,
      editingColIdx: -1,
    );
  }
}
