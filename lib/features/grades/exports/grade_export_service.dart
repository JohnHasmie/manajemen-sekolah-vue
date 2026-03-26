// excel_nilai_service.dart - Export student grade/score (nilai) data to Excel.
// Like Laravel's Maatwebsite/Excel NilaiExport class with FormRequest validation.
// "Nilai" means grades/scores in Indonesian school context.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Service for exporting student grade data (nilai) to Excel via the backend.
/// Similar to Laravel's `Excel::download(new NilaiExport($data), 'Data_Nilai.xlsx')`.
///
/// Supports optional [filters] for narrowing the export (class, subject, etc.),
/// like query parameters on a Laravel export route: `/grade/export?class_id=1`.
///
/// Grade types supported: UH (daily quiz), Tugas (assignment), UTS/PTS (midterm),
/// UAS/PAS (final exam).
class ExcelNilaiService {
  static String get baseUrl => '/grade';

  /// Export grade data to Excel via backend POST to `/grade/export`.
  /// [gradeData] - list of grade records. [filters] - optional filter map
  /// (e.g., class_id, subject_id). [context] - for SnackBar and i18n.
  /// Side effects: validates, downloads .xlsx, saves to device, opens file.
  static Future<void> exportGradesToExcel({
    required List<dynamic> gradeData,
    required BuildContext context,
    Map<String, dynamic> filters = const {},
  }) async {
    

    try {
      // Validate data first
      final validatedData = validateGradeData(gradeData);

      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: {'gradeData': validatedData, 'filters': filters},
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory to save the file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/Data_Nilai_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Save the downloaded file
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Open file
      await OpenFile.open(filePath);

            SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
              'en': 'Grade data exported successfully',
              'id': 'Data nilai berhasil diexport',
            }));
    } catch (e) {
            SnackBarUtils.showError(context, languageProvider.getTranslatedText({
              'en': 'Failed to export grade data: $e',
              'id': 'Gagal mengexport data nilai: $e',
            }));
    }
  }

  /// Local validation for grade data before export.
  /// Like a Laravel FormRequest: checks required fields (nis, student_name,
  /// class_name, subject_name, type, grade) and ensures grade is 0-100.
  /// Throws with accumulated error messages if any row fails validation.
  static List<Map<String, dynamic>> validateGradeData(List<dynamic> gradeData) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < gradeData.length; i++) {
      final gradeItem = gradeData[i];
      final Map<String, dynamic> validatedGrade = {};

      // Validate required fields
      if (gradeItem['nis'] == null || gradeItem['nis'].toString().isEmpty) {
        errors.add('Row ${i + 1}: NIS must not be empty');
      } else {
        validatedGrade['nis'] = gradeItem['nis'];
      }

      if (gradeItem['student_name'] == null ||
          gradeItem['student_name'].toString().isEmpty) {
        errors.add('Row ${i + 1}: Student name must not be empty');
      } else {
        validatedGrade['student_name'] = gradeItem['student_name'];
      }

      if (gradeItem['class_name'] == null ||
          gradeItem['class_name'].toString().isEmpty) {
        errors.add('Row ${i + 1}: Class name must not be empty');
      } else {
        validatedGrade['class_name'] = gradeItem['class_name'];
      }

      if (gradeItem['subject_name'] == null ||
          gradeItem['subject_name'].toString().isEmpty) {
        errors.add('Row ${i + 1}: Subject name must not be empty');
      } else {
        validatedGrade['subject_name'] = gradeItem['subject_name'];
      }

      if (gradeItem['type'] == null || gradeItem['type'].toString().isEmpty) {
        errors.add('Row ${i + 1}: Grade type must not be empty');
      } else {
        validatedGrade['type'] = gradeItem['type'];
      }

      if (gradeItem['grade'] == null) {
        errors.add('Row ${i + 1}: Grade must not be empty');
      } else {
        final gradeValue = double.tryParse(gradeItem['grade'].toString());
        if (gradeValue == null || gradeValue < 0 || gradeValue > 100) {
          errors.add('Row ${i + 1}: Grade must be between 0-100');
        } else {
          validatedGrade['grade'] = gradeValue;
        }
      }

      // Field optional
      validatedGrade['description'] = gradeItem['description'] ?? '';
      validatedGrade['date'] = gradeItem['date'] ?? '';
      validatedGrade['teacher_name'] = gradeItem['teacher_name'] ?? '';

      if (errors.isEmpty) {
        validatedData.add(validatedGrade);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  /// Get a localized label for grade type codes (uh, tugas, uts, uas, pts, pas).
  /// Like a Laravel accessor that maps enum values to display strings.
  /// Uses [LanguageProvider] for i18n (en/id), similar to Laravel's `__()` helper.
  static String getGradeTypeLabel(
    String gradeType,
    LanguageProvider languageProvider,
  ) {
    switch (gradeType) {
      case 'uh':
        return languageProvider.getTranslatedText({
          'en': 'Daily/Quiz',
          'id': 'UH/Ulangan',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      case 'pts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm Exam',
          'id': 'PTS',
        });
      case 'pas':
        return languageProvider.getTranslatedText({
          'en': 'Final Exam',
          'id': 'PAS',
        });
      default:
        return gradeType.toUpperCase();
    }
  }
}
