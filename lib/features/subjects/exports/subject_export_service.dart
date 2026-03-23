// excel_subject_service.dart - Export and import subject (mata pelajaran) data via Excel.
// Like Laravel's Maatwebsite/Excel SubjectExport with template download and validation.
// Handles bilingual field names (name/nama, code/kode, description/deskripsi).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// Service for exporting subject (mata pelajaran) data to Excel and downloading
/// import templates via the backend API.
/// Similar to `Excel::download(new SubjectExport($data), 'Mata_Pelajaran.xlsx')` in Laravel.
///
/// Supports bilingual field name mapping (English/Indonesian) for data that may
/// arrive in either format from the API. Like a Laravel Resource that normalizes
/// `name`/`nama` and `code`/`kode` fields into a consistent structure.
class ExcelSubjectService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  /// Export subject data to Excel via backend POST to `/subject/export`.
  /// [subjects] - list of subject maps. [context] - for SnackBar and i18n.
  /// Side effects: validates, downloads .xlsx, saves to device, opens file.
  static Future<void> exportSubjectsToExcel({
    required List<dynamic> subjects,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateSubjectData(subjects);

      final headers = await ApiService.getHeaders();
      // Kirim request ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/subject/export'),
        headers: headers,
        body: jsonEncode({'subjects': validatedData}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Data_Mata_Pelajaran_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Subject data exported successfully',
                'id': 'Data mata pelajaran berhasil diexport',
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

  /// Download a subject import template from GET `/subject/template`.
  static Future<void> downloadTemplate(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final headers = await ApiService.getHeaders();
      // Kirim request ke backend
      final response = await http.get(
        Uri.parse('$baseUrl/subject/template'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Template_Import_Mata_Pelajaran.xlsx';

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
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to download template');
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

  /// Server-side subject validation via POST to `/subject/validate`.
  static Future<List<Map<String, dynamic>>> validateSubjectDataBackend(
    List<dynamic> subjects,
  ) async {
    try {
      final headers = await ApiService.getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/subject/validate'),
        headers: headers,
        body: jsonEncode({'subjects': subjects}),
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

  /// Local fallback validation. Checks required fields (code, name) with
  /// bilingual key support ('code'/'kode', 'name'/'nama').
  /// Includes subject ID if available for backend lookups.
  static List<Map<String, dynamic>> validateSubjectData(
    List<dynamic> subjects,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final Map<String, dynamic> validatedSubject = {};

      // Include ID for backend lookup
      if (subject['id'] != null) {
        validatedSubject['id'] = subject['id'];
      }

      // Validasi field required
      final code = subject['code'] ?? subject['kode'];
      if (code == null || code.toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kode mata pelajaran tidak boleh kosong');
      } else {
        validatedSubject['code'] = code;
      }

      final name = subject['name'] ?? subject['nama'];
      if (name == null || name.toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama mata pelajaran tidak boleh kosong');
      } else {
        validatedSubject['name'] = name;
      }

      // Field optional
      validatedSubject['description'] =
          subject['description'] ?? subject['deskripsi'] ?? '';
      validatedSubject['class_names'] = _getClassNames(subject);

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

    final kelasList = subject['class_list'] ?? subject['classes'] ?? [];
    if (kelasList is List) {
      return kelasList.map((kelas) => kelas['name'] ?? '').join(', ');
    }

    return '';
  }
}
