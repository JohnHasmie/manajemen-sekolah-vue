import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Result of [GradeBookController.loadData].
/// The screen destructures this and applies every field via setState.
///
/// [error] is non-null when the load failed — the screen should show a
/// snackbar with the message. This avoids passing BuildContext across async
/// gaps inside the controller.
class LoadDataResult {
  final List<Student> studentList;
  final List<Student> filteredStudentList;
  final List<Map<String, dynamic>> gradeList;
  final Map<String, List<Map<String, dynamic>>> assessmentHeaders;
  final bool isLoading;

  /// Non-null means something went wrong. Show this to the user.
  final String? error;

  const LoadDataResult({
    required this.studentList,
    required this.filteredStudentList,
    required this.gradeList,
    required this.assessmentHeaders,
    required this.isLoading,
    this.error,
  });

  /// Convenience constructor for error-only results.
  LoadDataResult.failure(String message)
    : studentList = const [],
      filteredStudentList = const [],
      gradeList = const [],
      assessmentHeaders = const {},
      isLoading = false,
      error = message;
}

/// Result of [GradeBookController.enterEditMode].
/// The screen applies this via setState and wires up the returned
/// controllers.
class EnterEditModeResult {
  final bool isEditMode;
  final String editGradeType;
  final Map<String, dynamic> editHeader;
  final Map<String, TextEditingController> editControllers;
  final Map<String, FocusNode> editFocusNodes;

  const EnterEditModeResult({
    required this.isEditMode,
    required this.editGradeType,
    required this.editHeader,
    required this.editControllers,
    required this.editFocusNodes,
  });
}
