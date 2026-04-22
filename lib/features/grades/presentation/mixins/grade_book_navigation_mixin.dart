import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_input_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/modern_grade_editor_sheet.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';

/// Mixin handling navigation and form opening for the grade book.
/// Extracted to reduce main screen complexity.
mixin GradeBookNavigationMixin on ConsumerState<GradeBookPage> {
  Map<String, dynamic> get teacher;
  Map<String, dynamic> get subject;
  Map<String, dynamic> get classData;

  List<Student> get filteredStudentList;
  List<Map<String, dynamic>> get gradeList;

  Color getPrimaryColor(Map<String, dynamic> _);
  Map<String, dynamic>? getGradeForStudentAndHeader(
    Student s,
    String t,
    Map<String, dynamic> h,
  );

  Future<void> loadData({
    required Map<String, dynamic> teacher,
    required Map<String, dynamic> subject,
    required Map<String, dynamic> classData,
    bool showLoading = true,
    bool useCache = true,
  });

  /// Opens the modern single-grade editor as a bottom sheet.
  ///
  /// Only refreshes the grade book when the sheet reports `saved=true` —
  /// pre-redesign we refetched unconditionally on every pop, which produced
  /// a flicker each time a teacher dismissed the sheet without changes.
  Future<void> openInputForm(
    Student student,
    String gradeType,
    LanguageProvider lp, {
    Map<String, dynamic>? header,
  }) async {
    final existingGrade = header != null
        ? getGradeForStudentAndHeader(student, gradeType, header)
        : null;
    final headerDate = header?['date'];
    DateTime? parsedDate;
    if (headerDate is String && headerDate.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(headerDate);
      } catch (_) {
        parsedDate = null;
      }
    }

    final result = await ModernGradeEditorSheet.show(
      context: context,
      teacher: teacher,
      subject: subject,
      student: student,
      gradeType: gradeType,
      existingGrade: existingGrade,
      assessmentId: header?['id'],
      initialDate: parsedDate,
      initialTitle: header?['title'],
    );

    if (result?.saved == true) {
      await loadData(
        teacher: teacher,
        subject: subject,
        classData: classData,
        showLoading: true,
        useCache: false,
      );
    }
  }

  /// Opens a modal bottom sheet dialog to create new grades.
  void openNewInputForm(LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GradeInputDialog(
        teacher: teacher,
        subject: subject,
        studentList: filteredStudentList,
        primaryColor: getPrimaryColor(teacher),
        languageProvider: lp,
        onSaved: () => loadData(
          teacher: teacher,
          subject: subject,
          classData: classData,
          showLoading: true,
          useCache: false,
        ),
      ),
    );
  }
}
