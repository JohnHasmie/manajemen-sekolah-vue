import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_assessment_detail_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_column_options_sheet.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_confirm_delete_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';

/// Mixin handling all dialog/sheet interactions for grade book.
mixin GradeBookDialogsMixin on ConsumerState<GradeBookPage> {
  List<Student> get studentList;
  List<Map<String, dynamic>> get gradeList;

  // Abstract for subclass to implement
  Map<String, dynamic>? getGradeForStudentAndHeader(
    Student student,
    String type,
    Map<String, dynamic> header,
  );

  String formatDateDisplay(String dateStr);
  String getGradeTypeLabel(String type, LanguageProvider languageProvider);
  Color getPrimaryColor(Map<String, dynamic> teacher);
  bool get canEdit;
  bool get isReadOnly;

  void showErrorSnackBar(String message);
  void showSuccessSnackBar(String message);
  void onAssessmentDeleted();

  void showColumnOptions(
    String type,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
    VoidCallback onViewDetails,
    VoidCallback onEditAssessment,
    VoidCallback onDeleteAssessment,
  ) {
    final String date = header['date'];
    final String? title = header['title'];
    final displayTitle = title != null && title.isNotEmpty
        ? '$title (${formatDateDisplay(date)})'
        : formatDateDisplay(date);

    showGradeColumnOptionsSheet(
      context: context,
      gradeTypeLabel: getGradeTypeLabel(type, languageProvider),
      displayTitle: displayTitle,
      primaryColor: getPrimaryColor({}),
      canEdit: canEdit,
      isReadOnly: isReadOnly,
      onViewDetails: onViewDetails,
      onEditAssessment: onEditAssessment,
      onDeleteAssessment: onDeleteAssessment,
      labelViewDetails: languageProvider.getTranslatedText({
        'en': 'View Details',
        'id': 'Lihat Detail',
      }),
      labelEditAssessment: languageProvider.getTranslatedText({
        'en': 'Edit Assessment',
        'id': 'Edit Penilaian',
      }),
      labelDeleteAssessment: languageProvider.getTranslatedText({
        'en': 'Delete Assessment',
        'id': 'Hapus Penilaian',
      }),
      labelDeleteSubtitle: languageProvider.getTranslatedText({
        'en': 'Delete all grades for this assessment',
        'id': 'Hapus semua nilai penilaian ini',
      }),
    );
  }

  void showAssessmentDetail(
    String type,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    final String date = header['date'];
    final String? title = header['title'];
    final int totalSiswa = studentList.length;
    int gradedCount = 0;
    double totalScore = 0;

    for (final student in studentList) {
      final existingGrade = getGradeForStudentAndHeader(student, type, header);
      if (existingGrade != null && existingGrade.isNotEmpty) {
        gradedCount++;
        totalScore +=
            double.tryParse(
              (existingGrade['score'] ?? existingGrade['nilai'] ?? 0)
                  .toString(),
            ) ??
            0.0;
      }
    }
    final double average = gradedCount > 0 ? totalScore / gradedCount : 0;

    showGradeAssessmentDetailDialog(
      context: context,
      primaryColor: getPrimaryColor({}),
      labelTitle: languageProvider.getTranslatedText({
        'en': 'Assessment Details',
        'id': 'Detail Penilaian',
      }),
      labelType: languageProvider.getTranslatedText({
        'en': 'Type',
        'id': 'Jenis',
      }),
      labelDate: languageProvider.getTranslatedText({
        'en': 'Date',
        'id': 'Tanggal',
      }),
      labelAssessmentTitle: languageProvider.getTranslatedText({
        'en': 'Title',
        'id': 'Judul',
      }),
      labelTotalStudents: languageProvider.getTranslatedText({
        'en': 'Total Students',
        'id': 'Total Siswa',
      }),
      labelGraded: languageProvider.getTranslatedText({
        'en': 'Graded',
        'id': 'Sudah Dinilai',
      }),
      labelAverage: languageProvider.getTranslatedText({
        'en': 'Average Score',
        'id': 'Rata-rata Nilai',
      }),
      gradeTypeLabel: getGradeTypeLabel(type, languageProvider),
      formattedDate: formatDateDisplay(date),
      assessmentTitle: (title != null && title.isNotEmpty) ? title : null,
      totalStudents: totalSiswa,
      gradedCount: gradedCount,
      averageScore: average.toStringAsFixed(2),
    );
  }

  void confirmDeleteAssessment(
    String type,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
    VoidCallback onConfirm,
  ) {
    final String date = header['date'];
    final String? title = header['title'];
    final typeLabel = getGradeTypeLabel(type, languageProvider);
    final dateLabel = formatDateDisplay(date);
    final titleSuffix = title != null ? ' ($title)' : '';

    showGradeConfirmDeleteDialog(
      context: context,
      labelHeader: languageProvider.getTranslatedText({
        'en': 'Delete Assessment?',
        'id': 'Hapus Penilaian?',
      }),
      confirmMessage: languageProvider.getTranslatedText({
        'en':
            'Are you sure you want to delete all grades for $typeLabel '
            'on $dateLabel$titleSuffix? This action cannot be undone.',
        'id':
            'Apakah Anda yakin ingin menghapus semua nilai $typeLabel '
            'pada tanggal $dateLabel$titleSuffix? '
            'Tindakan ini tidak dapat dibatalkan.',
      }),
      labelCancel: languageProvider.getTranslatedText({
        'en': 'Cancel',
        'id': 'Batal',
      }),
      labelDelete: languageProvider.getTranslatedText({
        'en': 'Delete',
        'id': 'Hapus',
      }),
      onConfirm: onConfirm,
    );
  }
}
