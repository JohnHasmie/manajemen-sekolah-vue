// excel_subject_service.dart - Export and import subject (mata pelajaran) data via Excel.
// Like Laravel's Maatwebsite/Excel SubjectExport with template download and validation.
// Handles bilingual field names (name/nama, code/kode, description/deskripsi).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

/// Service for exporting subject (mata pelajaran) data to Excel and downloading
/// import templates via the backend API.
/// Similar to `Excel::download(new SubjectExport($data), 'Mata_Pelajaran.xlsx')` in Laravel.
///
/// Supports bilingual field name mapping (English/Indonesian) for data that may
/// arrive in either format from the API. Like a Laravel Resource that normalizes
/// `name`/`nama` and `code`/`kode` fields into a consistent structure.
class ExcelSubjectService {
  static String get baseUrl => '/subject';

  /// Export subject data to Excel via backend POST to `/subject/export`.
  /// [subjects] - list of subject maps. [context] - for SnackBar and i18n.
  /// Side effects: validates, downloads .xlsx, saves to device, opens file.
  static Future<void> exportSubjectsToExcel({
    required List<dynamic> subjects,
    required BuildContext context,
  }) async {
    try {
      // Validate data first
      final validatedData = validateSubjectData(subjects);

      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: {'subjects': validatedData},
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory to save the file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/Data_Mata_Pelajaran_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Save the downloaded file
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Open file
      await OpenFile.open(filePath);

      SnackBarUtils.showSuccess(
        // ignore: use_build_context_synchronously
        context,
        languageProvider.getTranslatedText({
          'en': 'Subject data exported successfully',
          'id': 'Data mata pelajaran berhasil diexport',
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

  /// Download a subject import template from GET `/subject/template`.
  static Future<void> downloadTemplate(BuildContext context) async {
    try {
      final response = await dioClient.get<List<int>>(
        '$baseUrl/template',
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory to save the file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/Template_Import_Mata_Pelajaran.xlsx';

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

  /// Server-side subject validation via POST to `/subject/validate`.
  static Future<List<Map<String, dynamic>>> validateSubjectDataBackend(
    List<dynamic> subjects,
  ) async {
    try {
      final response = await dioClient.post(
        '$baseUrl/validate',
        data: {'subjects': subjects},
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

  /// Local fallback validation. Checks required fields (code, name) with
  /// bilingual key support ('code'/'kode', 'name'/'nama').
  /// Includes subject ID if available for backend lookups.
  static List<Map<String, dynamic>> validateSubjectData(
    List<dynamic> subjects,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i] as Map<String, dynamic>;
      final model = Subject.fromJson(subject);
      final Map<String, dynamic> validatedSubject = {};

      // Include ID for backend lookup
      if (model.id.isNotEmpty) {
        validatedSubject['id'] = model.id;
      }

      // Validate required fields
      if (model.code == null || model.code!.isEmpty) {
        errors.add('Baris ${i + 1}: Kode mata pelajaran tidak boleh kosong');
      } else {
        validatedSubject['code'] = model.code;
      }

      if (model.name.isEmpty) {
        errors.add('Baris ${i + 1}: Nama mata pelajaran tidak boleh kosong');
      } else {
        validatedSubject['name'] = model.name;
      }

      // Field optional — not in Subject model, read raw
      validatedSubject['description'] =
          subject['description'] ?? subject['deskripsi'] ?? '';
      validatedSubject['class_names'] =
          model.classNames ?? _getClassNames(subject);

      if (errors.isEmpty) {
        validatedData.add(validatedSubject);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  /// Extract class names associated with a subject as a comma-separated string.
  /// Handles multiple data shapes: pre-computed 'class_names' string, or
  /// nested 'class_list'/'classes' arrays. Like a Laravel accessor that
  /// resolves a relationship: `$subject->classes->pluck('name')->join(', ')`.
  static String _getClassNames(Map<String, dynamic> subject) {
    if (subject['class_names'] != null) {
      return subject['class_names'];
    }

    final classList = subject['class_list'] ?? subject['classes'] ?? [];
    if (classList is List) {
      return classList
          .map(
            (classItem) =>
                Classroom.fromJson(classItem as Map<String, dynamic>).name,
          )
          .join(', ');
    }

    return '';
  }
}
