// excel_class_service.dart - Export and import class (kelas) data via Excel.
// Like Laravel's Maatwebsite/Excel ClassExport and ClassImport classes.
// Handles export, template download (xlsx & csv), and data validation.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

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
/// All methods are static and use [dioClient] for auth tokens,
/// like attaching `auth:sanctum` middleware in Laravel routes.
class ExcelClassService {
  static String get baseUrl => '/class';

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
    try {
      // Validate data first
      final validatedData = validateClassData(classes);

      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: {'classes': validatedData},
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory to save the file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/Data_Kelas_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Save the downloaded file
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Open file
      await OpenFile.open(filePath);

      SnackBarUtils.showSuccess(
        // ignore: use_build_context_synchronously
        context,
        languageProvider.getTranslatedText({
          'en': 'Class data exported successfully',
          'id': 'Data kelas berhasil diexport',
        }),
      );
    } catch (e) {
      SnackBarUtils.showError(
        // ignore: use_build_context_synchronously
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to export data: $e',
          'id': 'Gagal mengexport data: $e',
        }),
      );
    }
  }

  /// Download an Excel import template from the backend GET `/class/template`.
  /// Like a Laravel route that returns `Excel::download(new ClassTemplateExport)`.
  /// Provides users with a pre-formatted .xlsx file to fill in and import.
  static Future<void> downloadTemplate(BuildContext context) async {
    try {
      final response = await dioClient.get<List<int>>(
        '$baseUrl/template',
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory to save the file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/Template_Import_Kelas.xlsx';

      // Save the downloaded file
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Open file
      await OpenFile.open(filePath);

      SnackBarUtils.showSuccess(
        // ignore: use_build_context_synchronously
        context,
        languageProvider.getTranslatedText({
          'en': 'Template downloaded successfully',
          'id': 'Template berhasil diunduh',
        }),
      );
    } catch (e) {
      SnackBarUtils.showError(
        // ignore: use_build_context_synchronously
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to download template: $e',
          'id': 'Gagal mengunduh template: $e',
        }),
      );
    }
  }

  /// Download a CSV import template from the backend GET `/class/template/csv`.
  /// Alternative to the Excel template for users who prefer CSV format.
  static Future<void> downloadTemplateCSV(BuildContext context) async {
    try {
      final response = await dioClient.get<List<int>>(
        '$baseUrl/template/csv',
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory to save the file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/Template_Import_Kelas.csv';

      // Save the downloaded file
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Open file
      await OpenFile.open(filePath);

      SnackBarUtils.showSuccess(
        // ignore: use_build_context_synchronously
        context,
        languageProvider.getTranslatedText({
          'en': 'CSV Template downloaded successfully',
          'id': 'Template CSV berhasil diunduh',
        }),
      );
    } catch (e) {
      SnackBarUtils.showError(
        // ignore: use_build_context_synchronously
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to download CSV template: $e',
          'id': 'Gagal mengunduh template CSV: $e',
        }),
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
      final response = await dioClient.post(
        '$baseUrl/validate',
        data: {'classes': classes},
      );

      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['success'] == true) {
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

      // Validate required fields
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
}
