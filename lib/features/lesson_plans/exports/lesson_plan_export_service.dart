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
class ExcelLessonPlanService {
  static String get baseUrl => '/rpp';

  /// Export RPP data to Excel via backend POST to `/rpp/export`.
  /// [lessonPlanList] - list of RPP records. [context] - for SnackBar and i18n.
  /// Side effects: validates locally, sends to backend, saves .xlsx, opens file.
  static Future<void> exportLessonPlansToExcel({
    required List<dynamic> lessonPlanList,
    required BuildContext context,
  }) async {
    try {
      // Validate data first
      final validatedData = validateLessonPlanData(lessonPlanList);

      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: {'lessonPlanList': validatedData},
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

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'RPP data exported successfully',
          'id': 'Data RPP berhasil diexport',
        }),
      );
    } catch (e) {
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to export RPP data: $e',
          'id': 'Gagal mengexport data RPP: $e',
        }),
      );
    }
  }

  /// Server-side RPP validation via POST to `/rpp/validate`.
  /// Like a Laravel FormRequest for RPP data.
  static Future<List<Map<String, dynamic>>> validateLessonPlanDataBackend(
    List<dynamic> lessonPlanData,
  ) async {
    try {
      final response = await dioClient.post(
        '$baseUrl/validate',
        data: {'rppData': lessonPlanData},
      );

      final responseData = response.data;

      if (responseData is Map<String, dynamic> &&
          responseData['success'] == true) {
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
  static List<Map<String, dynamic>> validateLessonPlanData(
    List<dynamic> lessonPlanList,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < lessonPlanList.length; i++) {
      final lessonPlan = lessonPlanList[i];
      final Map<String, dynamic> validatedLessonPlan = {};

      // Validate required fields for export
      if (lessonPlan['title'] == null ||
          lessonPlan['title'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Judul RPP tidak boleh kosong');
      } else {
        validatedLessonPlan['title'] = lessonPlan['title'];
      }

      if (lessonPlan['subject_name'] == null ||
          lessonPlan['subject_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedLessonPlan['subject_name'] = lessonPlan['subject_name'];
      }

      if (lessonPlan['class_name'] == null ||
          lessonPlan['class_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedLessonPlan['class_name'] = lessonPlan['class_name'];
      }

      // Field lainnya
      validatedLessonPlan['teacher_name'] = lessonPlan['teacher_name'] ?? '';
      validatedLessonPlan['semester'] = lessonPlan['semester'] ?? '';
      validatedLessonPlan['academic_year'] = lessonPlan['academic_year'] ?? '';
      validatedLessonPlan['status'] = lessonPlan['status'] ?? '';
      validatedLessonPlan['created_at'] = lessonPlan['created_at'] ?? '';

      // Map keys to match backend expectation
      validatedLessonPlan['note_admin'] =
          lessonPlan['catatan_admin'] ?? lessonPlan['note_admin'] ?? '';
      validatedLessonPlan['basic_competence'] =
          lessonPlan['basic_competence'] ??
          lessonPlan['basic_competency'] ??
          '';
      validatedLessonPlan['learning_objective'] =
          lessonPlan['learning_objective'] ??
          lessonPlan['learning_objectives'] ??
          '';
      validatedLessonPlan['main_material'] =
          lessonPlan['main_material'] ?? lessonPlan['learning_materials'] ?? '';
      validatedLessonPlan['learning_method'] =
          lessonPlan['learning_method'] ?? lessonPlan['learning_methods'] ?? '';
      validatedLessonPlan['media_tools'] =
          lessonPlan['media_tools'] ?? lessonPlan['learning_media'] ?? '';
      validatedLessonPlan['learning_source'] =
          lessonPlan['learning_source'] ?? lessonPlan['learning_sources'] ?? '';
      validatedLessonPlan['learning_activities'] =
          lessonPlan['learning_activities'] ??
          lessonPlan['learning_steps'] ??
          '';
      validatedLessonPlan['assessment'] = lessonPlan['assessment'] ?? '';

      if (errors.isEmpty) {
        validatedData.add(validatedLessonPlan);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('RPP data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }
}
