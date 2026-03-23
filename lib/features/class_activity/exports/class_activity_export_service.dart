// excel_class_activity_service.dart - Export class activity data to Excel via backend API.
// Like Laravel's Maatwebsite/Excel export (`ClassActivityExport`) triggered from a controller.
// The Flutter side sends data to the Laravel backend which generates the .xlsx file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/class_activity/services/class_activity_service.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// Service responsible for exporting class activity data (kegiatan kelas) to Excel.
/// Similar to a Laravel Maatwebsite/Excel export class that implements `FromCollection`.
///
/// The export flow:
/// 1. Format & validate data locally (like Laravel FormRequest validation)
/// 2. POST data to the backend `/class-activity/export` endpoint
/// 3. Backend generates the .xlsx using Maatwebsite/Excel
/// 4. Save the returned binary file to device storage and open it
///
/// All methods are static -- no instance state needed (like a Laravel helper class).
class ExcelClassActivityService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  /// Export class activities to an Excel file via the backend API.
  /// Like calling a Laravel controller action that returns a file download.
  ///
  /// [activities] - raw list of activity maps from the API/state.
  /// [context] - BuildContext used for SnackBar feedback and i18n.
  ///
  /// Side effects: saves .xlsx to device documents dir and opens it.
  /// Shows a success/error SnackBar (like Laravel's `return back()->with('message', ...)`).
  static Future<void> exportClassActivitiesToExcel({
    required List<dynamic> activities,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Format data terlebih dahulu
      final formattedData = formatActivitiesForExport(activities);

      // Validasi data (dengan handling error yang lebih baik)
      final validatedData = await _validateAndPrepareData(formattedData);

      // Gunakan ApiService yang sudah ada
      final response = await ApiClassActivityService.exportClassActivities(
        validatedData,
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Data_Kegiatan_Kelas_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Class activities data exported successfully',
                'id': 'Data kegiatan kelas berhasil diexport',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ??
              'Failed to export data. Status: ${response.statusCode}',
        );
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
      rethrow;
    }
  }

  /// Validate and prepare activity data with tolerant defaults for missing fields.
  /// Like a Laravel FormRequest that fills default values instead of rejecting.
  /// Handles date type conversion (DateTime -> ISO string).
  /// Returns a cleaned list ready for the backend export endpoint.
  static Future<List<Map<String, dynamic>>> _validateAndPrepareData(
    List<Map<String, dynamic>> activities,
  ) async {
    final List<Map<String, dynamic>> preparedData = [];

    for (final activity in activities) {
      final Map<String, dynamic> preparedActivity = {};

      // Field required dengan default value jika kosong
      preparedActivity['title'] =
          activity['title']?.toString() ?? 'Tidak Ada Judul';
      preparedActivity['subject_name'] =
          activity['subject_name']?.toString() ?? 'Tidak Ada Mata Pelajaran';
      preparedActivity['class_name'] =
          activity['class_name']?.toString() ?? 'Tidak Ada Kelas';
      preparedActivity['teacher_name'] =
          activity['teacher_name']?.toString() ?? 'Tidak Ada Guru';
      preparedActivity['type'] = activity['type']?.toString() ?? 'tugas';
      preparedActivity['target'] = activity['target']?.toString() ?? 'umum';

      // Handle tanggal - convert ke format string jika perlu
      if (activity['date'] != null) {
        if (activity['date'] is DateTime) {
          preparedActivity['date'] = (activity['date'] as DateTime)
              .toIso8601String();
        } else {
          preparedActivity['date'] = activity['date'].toString();
        }
      } else {
        preparedActivity['date'] = DateTime.now().toIso8601String();
      }

      // Field optional
      preparedActivity['description'] = activity['description'] ?? '';
      preparedActivity['day'] = activity['day'] ?? '';
      preparedActivity['deadline'] = activity['deadline'] ?? '';
      preparedActivity['chapter_title'] = activity['chapter_title'] ?? '';
      preparedActivity['sub_chapter_title'] =
          activity['sub_chapter_title'] ?? '';

      preparedData.add(preparedActivity);
    }

    return preparedData;
  }

  /// Format raw activity data into a consistent map structure before export.
  /// Like a Laravel Resource/Transformer that normalizes API data.
  /// Ensures all expected keys exist with empty-string fallbacks.
  static List<Map<String, dynamic>> formatActivitiesForExport(
    List<dynamic> rawActivities,
  ) {
    return rawActivities.map((activity) {
      return {
        'title': activity['title'] ?? '',
        'subject_name': activity['subject_name'] ?? '',
        'class_name': activity['class_name'] ?? '',
        'teacher_name': activity['teacher_name'] ?? '',
        'type': activity['type'] ?? '',
        'target': activity['target'] ?? '',
        'description': activity['description'] ?? '',
        'date': activity['date'] ?? '',
        'day': activity['day'] ?? '',
        'deadline': activity['deadline'] ?? '',
        'chapter_title': activity['chapter_title'] ?? '',
        'sub_chapter_title': activity['sub_chapter_title'] ?? '',
      };
    }).toList();
  }
}
