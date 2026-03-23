// excel_class_service.dart - Export and import class (kelas) data via Excel.
// Like Laravel's Maatwebsite/Excel ClassExport and ClassImport classes.
// Handles export, template download (xlsx & csv), and data validation.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// Service for exporting class data to Excel and downloading import templates.
/// Similar to a Laravel controller that uses Maatwebsite/Excel:
/// `return Excel::download(new ClassExport($classes), 'Data_Kelas.xlsx');`
///
/// Provides three main capabilities:
/// 1. Export existing class data to .xlsx
/// 2. Download .xlsx import template (with headers + example rows)
/// 3. Download .csv import template (alternative format)
/// 4. Validate class data both locally and via backend API
///
/// All methods are static and use [ApiService.getHeaders()] for auth tokens,
/// like attaching `auth:sanctum` middleware in Laravel routes.
class ExcelClassService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  /// Export class data to an Excel file via backend POST to `/class/export`.
  /// Like `Excel::download(new ClassExport($data), 'file.xlsx')` in Laravel.
  ///
  /// [classes] - list of class data maps from state/API.
  /// [context] - BuildContext for SnackBar and i18n access.
  /// Side effects: validates data, saves .xlsx locally, opens the file.
  static Future<void> exportClassesToExcel({
    required List<dynamic> classes,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateClassData(classes);

      // Kirim request ke backend
      final headers = await ApiService.getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/class/export'),
        headers: headers,
        body: jsonEncode({'classes': validatedData}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Data_Kelas_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Class data exported successfully',
                'id': 'Data kelas berhasil diexport',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to export data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to export data: $e',
              'id': 'Gagal mengexport data: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Download an Excel import template from the backend GET `/class/template`.
  /// Like a Laravel route that returns `Excel::download(new ClassTemplateExport)`.
  /// Provides users with a pre-formatted .xlsx file to fill in and import.
  static Future<void> downloadTemplate(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Kirim request ke backend
      final headers = await ApiService.getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/class/template'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/Template_Import_Kelas.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Template downloaded successfully',
                'id': 'Template berhasil diunduh',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Download failed. Status: ${response.statusCode}');
        print('Response body: ${response.body}');

        String errorMessage;
        try {
          final errorData = jsonDecode(response.body);
          errorMessage =
              errorData['message'] ??
              errorData['error'] ??
              'Failed to download template';
        } catch (e) {
          errorMessage =
              'Failed to download template (Status: ${response.statusCode})';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to download template: $e',
              'id': 'Gagal mengunduh template: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Download a CSV import template from the backend GET `/class/template/csv`.
  /// Alternative to the Excel template for users who prefer CSV format.
  static Future<void> downloadTemplateCSV(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Kirim request ke backend
      final headers = await ApiService.getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/class/template/csv'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/Template_Import_Kelas.csv';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'CSV Template downloaded successfully',
                'id': 'Template CSV berhasil diunduh',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to download CSV template',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to download CSV template: $e',
              'id': 'Gagal mengunduh template CSV: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Validate class data via backend POST to `/class/validate`.
  /// Like submitting data to a Laravel FormRequest for server-side validation.
  /// Returns the validated/cleaned data if successful, throws on failure.
  static Future<List<Map<String, dynamic>>> validateClassDataBackend(
    List<dynamic> classes,
  ) async {
    try {
      final headers = await ApiService.getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/class/validate'),
        headers: headers,
        body: jsonEncode({'classes': classes}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return List<Map<String, dynamic>>.from(responseData['validatedData']);
      } else {
        throw Exception(responseData['message'] ?? 'Validation failed');
      }
    } catch (e) {
      throw Exception('Validation error: $e');
    }
  }

  /// Local fallback validation for class data before export.
  /// Like a Laravel FormRequest but running client-side when the backend
  /// validation endpoint is not used. Checks required fields (name, grade_level)
  /// and handles polymorphic homeroom_teacher data (List from pivot vs Map legacy).
  /// Throws an Exception with all accumulated errors if validation fails.
  static List<Map<String, dynamic>> validateClassData(List<dynamic> classes) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < classes.length; i++) {
      final classItem = classes[i];
      final Map<String, dynamic> validatedClass = {};

      // Validasi field required
      if (classItem['name'] == null || classItem['name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama kelas tidak boleh kosong');
      } else {
        validatedClass['name'] = classItem['name'];
      }

      if (classItem['grade_level'] == null) {
        errors.add('Baris ${i + 1}: Grade level tidak boleh kosong');
      } else {
        final gradeLevel = int.tryParse(classItem['grade_level'].toString());
        if (gradeLevel == null || gradeLevel < 1 || gradeLevel > 12) {
          errors.add('Baris ${i + 1}: Grade level harus antara 1-12');
        } else {
          validatedClass['grade_level'] = gradeLevel;
        }
      }

      // Field optional
      // Handle homeroom_teacher which can be List (from pivot) or Map (legacy)
      String homeroomName = '';
      final homeroomData = classItem['homeroom_teacher'];

      if (homeroomData is List) {
        if (homeroomData.isNotEmpty) {
          homeroomName = homeroomData[0]['name'] ?? '';
        }
      } else if (homeroomData is Map) {
        homeroomName = homeroomData['name'] ?? '';
      } else {
        homeroomName = classItem['homeroom_teacher_name'] ?? '';
      }

      validatedClass['homeroom_teacher_name'] = homeroomName;
      validatedClass['student_count'] = classItem['student_count'] ?? 0;

      if (errors.isEmpty) {
        validatedData.add(validatedClass);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  /// Convert a numeric grade level (1-12) to a human-readable Indonesian label.
  /// E.g., 7 -> "Kelas 7 SMP". Like a Laravel accessor/mutator on a model.
  static String _getGradeLevelText(int? gradeLevel) {
    if (gradeLevel == null) return '';

    switch (gradeLevel) {
      case 1:
        return 'Kelas 1 SD';
      case 2:
        return 'Kelas 2 SD';
      case 3:
        return 'Kelas 3 SD';
      case 4:
        return 'Kelas 4 SD';
      case 5:
        return 'Kelas 5 SD';
      case 6:
        return 'Kelas 6 SD';
      case 7:
        return 'Kelas 7 SMP';
      case 8:
        return 'Kelas 8 SMP';
      case 9:
        return 'Kelas 9 SMP';
      case 10:
        return 'Kelas 10 SMA';
      case 11:
        return 'Kelas 11 SMA';
      case 12:
        return 'Kelas 12 SMA';
      default:
        return 'Grade $gradeLevel';
    }
  }

  /// Parse a grade level string to int (1-12). Returns null if invalid.
  static int? _parseGradeLevel(String? gradeLevelText) {
    if (gradeLevelText == null || gradeLevelText.isEmpty) return null;

    try {
      final level = int.tryParse(gradeLevelText);
      if (level != null && level >= 1 && level <= 12) {
        return level;
      }
    } catch (e) {
      print('Error parsing grade level: $e');
    }

    return null;
  }
}
