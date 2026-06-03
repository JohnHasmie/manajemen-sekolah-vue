import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/grades/domain/models/grade_book_models.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/grade_lookup_helper.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/grade_format_helper.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Helper for grade inline edit mode setup.
class GradeEditHelper {
  /// Builds edit-mode state for a given grade column.
  /// Returns controllers & focus nodes for all students in the column.
  static EnterEditModeResult enterEditMode(
    String type,
    Map<String, dynamic> header,
    List<Student> filteredStudentList,
    List<Map<String, dynamic>> gradeList, {
    required void Function(
      Student,
      String,
      Map<String, dynamic>,
      String,
      String,
    )
    onFocusLost,
  }) {
    final editControllers = <String, TextEditingController>{};
    final editFocusNodes = <String, FocusNode>{};

    for (final student in filteredStudentList) {
      final gradeData = GradeLookupHelper.getGradeForStudentAndHeader(
        student,
        type,
        header,
        gradeList,
      );

      _setupScoreField(
        student,
        gradeData,
        type,
        header,
        editControllers,
        editFocusNodes,
        onFocusLost,
      );

      _setupDescriptionField(
        student,
        gradeData,
        type,
        header,
        editControllers,
        editFocusNodes,
        onFocusLost,
      );
    }

    return EnterEditModeResult(
      isEditMode: true,
      editGradeType: type,
      editHeader: header,
      editControllers: editControllers,
      editFocusNodes: editFocusNodes,
    );
  }

  static void _setupScoreField(
    Student student,
    Map<String, dynamic>? gradeData,
    String type,
    Map<String, dynamic> header,
    Map<String, TextEditingController> controllers,
    Map<String, FocusNode> focusNodes,
    void Function(Student, String, Map<String, dynamic>, String, String)
    onFocusLost,
  ) {
    final scoreKey = '${student.id}_score';
    controllers[scoreKey] = TextEditingController(
      text: GradeFormatHelper.formatGradeValue(gradeData?['score']),
    );
    focusNodes[scoreKey] = FocusNode();
    focusNodes[scoreKey]!.addListener(() {
      if (!focusNodes[scoreKey]!.hasFocus) {
        onFocusLost(
          student,
          type,
          header,
          'score',
          controllers[scoreKey]!.text,
        );
      }
    });
  }

  static void _setupDescriptionField(
    Student student,
    Map<String, dynamic>? gradeData,
    String type,
    Map<String, dynamic> header,
    Map<String, TextEditingController> controllers,
    Map<String, FocusNode> focusNodes,
    void Function(Student, String, Map<String, dynamic>, String, String)
    onFocusLost,
  ) {
    final deskripsiKey = '${student.id}_deskripsi';
    controllers[deskripsiKey] = TextEditingController(
      text: gradeData?['deskripsi']?.toString() ?? '',
    );
    focusNodes[deskripsiKey] = FocusNode();
    focusNodes[deskripsiKey]!.addListener(() {
      if (!focusNodes[deskripsiKey]!.hasFocus) {
        onFocusLost(
          student,
          type,
          header,
          'deskripsi',
          controllers[deskripsiKey]!.text,
        );
      }
    });
  }
}
