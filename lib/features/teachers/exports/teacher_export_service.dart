// excel_teacher_service.dart - Export and import teacher (guru) data via Excel.
// Like Laravel's Maatwebsite/Excel TeacherExport with template download.
// Simpler than other Excel services -- no local validation, delegates entirely to backend.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// Service for exporting teacher data to Excel and downloading import templates.
/// Similar to `Excel::download(new TeacherExport($teachers), 'Data_Guru.xlsx')` in Laravel.
///
/// This is one of the simpler Excel services -- it sends raw teacher data to
/// the backend without local validation. The backend handles both file generation
/// and data validation. Uses `context.mounted` checks before showing SnackBars
/// (best practice for async BuildContext usage in Flutter).
class ExcelTeacherService {
  static String get baseUrl => '/teacher';

  /// Export teacher data to Excel via backend POST to `/teacher/export`.
  /// [teachers] - list of teacher maps. [context] - for SnackBar and i18n.
  /// Side effects: saves .xlsx to device, opens it. Uses `context.mounted`
  /// guard before SnackBar (Flutter best practice for async context).
  static Future<void> exportTeachersToExcel({
    required List<dynamic> teachers,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: {'teachers': teachers},
        options: Options(responseType: ResponseType.bytes),
      );

      // Save file locally
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/Data_Guru_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(response.data ?? []);

      // Open the file
      await OpenFile.open(filePath);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Teacher data exported successfully',
              'id': 'Data guru berhasil diexport',
            }),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
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

  /// Download teacher import template from GET `/teacher/template/download`.
  /// Like a Laravel route returning `Excel::download(new TeacherTemplateExport)`.
  static Future<void> downloadTemplate(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final response = await dioClient.get<List<int>>(
        '$baseUrl/template/download',
        options: Options(responseType: ResponseType.bytes),
      );

      // Save file locally
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/Template_Import_Guru.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(response.data ?? []);

      // Open the file
      await OpenFile.open(filePath);

      if (!context.mounted) return;
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
    } catch (e) {
      if (!context.mounted) return;
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
}
