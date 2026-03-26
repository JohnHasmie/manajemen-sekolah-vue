// excel_rpp_service.dart - Export lesson plan (RPP) data to Excel via backend.
// Like Laravel's Maatwebsite/Excel RppExport class with FormRequest validation.
// RPP = Rencana Pelaksanaan Pembelajaran (Lesson Plan).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Service for exporting RPP (Rencana Pelaksanaan Pembelajaran / Lesson Plan) to Excel.
/// Similar to `Excel::download(new RppExport($data), 'Data_RPP.xlsx')` in Laravel.
///
/// Handles field name mapping between frontend and backend conventions
/// (e.g., 'catatan_admin' -> 'note_admin', 'learning_objectives' -> 'learning_objective').
/// This is like defining `$appends` or custom attribute mappings on a Laravel Resource.
///
/// Provides both server-side and local validation for RPP data, with status
/// translation (Disetujui/Menunggu/Ditolak -> Approved/Pending/Rejected).
class ExcelRppService {
  static String get baseUrl => '/rpp';

  /// Export RPP data to Excel via backend POST to `/rpp/export`.
  /// [rppList] - list of RPP records. [context] - for SnackBar and i18n.
  /// Side effects: validates locally, sends to backend, saves .xlsx, opens file.
  static Future<void> exportRppToExcel({
    required List<dynamic> rppList,
    required BuildContext context,
  }) async {
    

    try {
      // Validate data first
      final validatedData = validateRppData(rppList);

      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: {'rppList': validatedData},
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory to save the file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/Data_RPP_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Save the downloaded file
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Open file
      await OpenFile.open(filePath);

            SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
              'en': 'RPP data exported successfully',
              'id': 'Data RPP berhasil diexport',
            }));
    } catch (e) {
            SnackBarUtils.showError(context, languageProvider.getTranslatedText({
              'en': 'Failed to export RPP data: $e',
              'id': 'Gagal mengexport data RPP: $e',
            }));
    }
  }

  /// Server-side RPP validation via POST to `/rpp/validate`.
  /// Like a Laravel FormRequest for RPP data.
  static Future<List<Map<String, dynamic>>> validateRppDataBackend(
    List<dynamic> rppData,
  ) async {
    try {
      final response = await dioClient.post(
        '$baseUrl/validate',
        data: {'rppData': rppData},
      );

      final responseData = response.data;

      if (responseData is Map<String, dynamic> && responseData['success'] == true) {
        return List<Map<String, dynamic>>.from(responseData['validatedData']);
      } else {
        throw Exception(responseData['message'] ?? 'RPP validation failed');
      }
    } catch (e) {
      throw Exception('RPP validation error: $e');
    }
  }

  /// Local fallback validation for RPP data before export.
  /// Validates required fields (title, subject_name, class_name) and maps
  /// alternative field names to the backend's expected keys.
  /// Like a Laravel FormRequest with field aliasing (`$request->input('catatan_admin', $request->input('note_admin'))`).
  static List<Map<String, dynamic>> validateRppData(List<dynamic> rppList) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < rppList.length; i++) {
      final rpp = rppList[i];
      final Map<String, dynamic> validatedRpp = {};

      // Validate required fields for export
      if (rpp['title'] == null || rpp['title'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Judul RPP tidak boleh kosong');
      } else {
        validatedRpp['title'] = rpp['title'];
      }

      if (rpp['subject_name'] == null ||
          rpp['subject_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedRpp['subject_name'] = rpp['subject_name'];
      }

      if (rpp['class_name'] == null || rpp['class_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedRpp['class_name'] = rpp['class_name'];
      }

      // Field lainnya
      validatedRpp['teacher_name'] = rpp['teacher_name'] ?? '';
      validatedRpp['semester'] = rpp['semester'] ?? '';
      validatedRpp['academic_year'] = rpp['academic_year'] ?? '';
      validatedRpp['status'] = rpp['status'] ?? '';
      validatedRpp['created_at'] = rpp['created_at'] ?? '';

      // Map keys to match backend expectation
      validatedRpp['note_admin'] =
          rpp['catatan_admin'] ?? rpp['note_admin'] ?? '';
      validatedRpp['basic_competence'] =
          rpp['basic_competence'] ?? rpp['basic_competency'] ?? '';
      validatedRpp['learning_objective'] =
          rpp['learning_objective'] ?? rpp['learning_objectives'] ?? '';
      validatedRpp['main_material'] =
          rpp['main_material'] ?? rpp['learning_materials'] ?? '';
      validatedRpp['learning_method'] =
          rpp['learning_method'] ?? rpp['learning_methods'] ?? '';
      validatedRpp['media_tools'] =
          rpp['media_tools'] ?? rpp['learning_media'] ?? '';
      validatedRpp['learning_source'] =
          rpp['learning_source'] ?? rpp['learning_sources'] ?? '';
      validatedRpp['learning_activities'] =
          rpp['learning_activities'] ?? rpp['learning_steps'] ?? '';
      validatedRpp['assessment'] = rpp['assessment'] ?? '';

      if (errors.isEmpty) {
        validatedData.add(validatedRpp);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('RPP data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

}
