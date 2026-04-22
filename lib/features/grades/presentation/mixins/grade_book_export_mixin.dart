import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_controller.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';

/// Mixin handling export and file operations for the grade book.
/// Extracted to reduce main screen complexity.
mixin GradeBookExportMixin on ConsumerState<GradeBookPage> {
  Map<String, dynamic> get teacher;
  Map<String, dynamic> get subject;
  Map<String, dynamic> get classData;

  void showErrorSnackBar(String message);
  void showSuccessSnackBar(String message);

  /// Exports grades to a file (typically Excel).
  Future<void> exportGrades(LanguageProvider lp) async {
    final ctrl = ref.read(gradeBookControllerProvider);
    final error = await ctrl.exportGrades(teacher, subject, classData);
    if (error != null) {
      showErrorSnackBar(error);
      return;
    }
    showSuccessSnackBar(
      lp.getTranslatedText({
        'en': 'Export successful',
        'id': 'Ekspor berhasil',
      }),
    );
  }
}
