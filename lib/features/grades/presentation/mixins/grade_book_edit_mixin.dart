import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_controller.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';

/// Mixin handling inline edit mode state for grade columns.
mixin GradeBookEditMixin on ConsumerState<GradeBookPage> {
  bool get isEditMode;
  set isEditMode(bool v);

  String? get editGradeType;
  set editGradeType(String? v);

  Map<String, dynamic>? get editHeader;
  set editHeader(Map<String, dynamic>? v);

  Map<String, TextEditingController> get editControllers;
  Map<String, FocusNode> get editFocusNodes;

  List<Student> get filteredStudentList;
  List<Map<String, dynamic>> get gradeList;

  Map<String, dynamic> get subject;
  bool get isLoading;
  set isLoading(bool v);

  void showErrorSnackBar(String message);
  void showSuccessSnackBar(String message);

  Future<void> onInlineSaved();
  Future<void> onAssessmentDeleted();

  void enterEditMode(String type, Map<String, dynamic> header) {
    for (final c in editControllers.values) {
      c.dispose();
    }
    for (final n in editFocusNodes.values) {
      n.dispose();
    }
    editControllers.clear();
    editFocusNodes.clear();

    final result = ref
        .read(gradeBookControllerProvider)
        .enterEditMode(
          type,
          header,
          filteredStudentList,
          gradeList,
          onFocusLost: onCellFocusLost,
        );

    setState(() {
      isEditMode = result.isEditMode;
      editGradeType = result.editGradeType;
      editHeader = result.editHeader;
      editControllers.addAll(result.editControllers);
      editFocusNodes.addAll(result.editFocusNodes);
    });
  }

  Future<void> onCellFocusLost(
    Student student,
    String type,
    Map<String, dynamic> header,
    String field,
    String value,
  );

  void exitEditMode() {
    setState(() {
      isEditMode = false;
      editGradeType = null;
      editHeader = null;
    });
  }

  void disposeEditResources() {
    for (final c in editControllers.values) {
      c.dispose();
    }
    for (final n in editFocusNodes.values) {
      n.dispose();
    }
  }

  /// Deletes an assessment and refreshes the grade list.
  Future<void> deleteAssessment(
    String gradeType,
    Map<String, dynamic> header,
  ) async {
    setState(() => isLoading = true);
    final error = await ref
        .read(gradeBookControllerProvider)
        .deleteAssessment(gradeType, header, subject);
    if (error != null) {
      setState(() => isLoading = false);
      showErrorSnackBar(error);
      return;
    }
    showSuccessSnackBar('Assessment deleted successfully');
    await onAssessmentDeleted();
  }

  /// Finishes inline edit mode, saving all changes for each student.
  Future<void> finishEdit() async {
    setState(() => isLoading = true);
    try {
      for (final student in filteredStudentList) {
        final scoreKey = '${student.id}_score';
        final descKey = '${student.id}_deskripsi';
        if (editControllers.containsKey(scoreKey)) {
          await onCellFocusLost(
            student,
            editGradeType!,
            editHeader!,
            'score',
            editControllers[scoreKey]!.text,
          );
        }
        if (editControllers.containsKey(descKey)) {
          await onCellFocusLost(
            student,
            editGradeType!,
            editHeader!,
            'deskripsi',
            editControllers[descKey]!.text,
          );
        }
      }
      exitEditMode();
      setState(() => isLoading = false);
    } catch (e) {
      AppLogger.error('grades', e);
      setState(() => isLoading = false);
      showErrorSnackBar(e.toString());
    }
  }
}
