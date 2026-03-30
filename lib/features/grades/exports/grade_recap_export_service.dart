// excel_rekap_nilai_service.dart - Export grade recapitulation (rekap nilai) to Excel.
// Like Laravel's Maatwebsite/Excel RekapNilaiExport that aggregates scores per chapter.
// "Rekap Nilai" = grade summary/recapitulation across chapters for a class+subject.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Service for exporting grade recapitulation data (rekap nilai) to Excel.
/// Similar to `Excel::download(new RekapNilaiExport($data), 'Rekap_Nilai.xlsx')` in Laravel.
///
/// Sends a structured payload containing:
/// - [tableData]: student rows with scores per chapter
/// - [chapters]: chapter metadata for column headers
/// - [className] and [subjectName]: for the filename and sheet title
///
/// Unlike other Excel services, this one has no local validation since the
/// data is pre-aggregated by the UI/provider before export.
class ExcelGradeRecapService {
  static String get baseUrl => '/grade-recaps';

  /// Export grade recapitulation to Excel via backend POST to `/grade-recaps/export`.
  /// [tableData] - rows of student scores. [chapters] - chapter metadata for headers.
  /// [className], [subjectName] - used for filename (sanitized with regex).
  /// Side effects: saves .xlsx to device documents dir and opens it.
  static Future<void> exportGradeRecapToExcel({
    required List<Map<String, dynamic>> tableData,
    required List<dynamic> chapters,
    required String className,
    required String subjectName,
    required BuildContext context,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'tableData': tableData,
        'chapters': chapters,
        'className': className,
        'subjectName': subjectName,
      };

      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: payload,
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();

      final String formattedSubject = subjectName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final String formattedClass = className.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final String filePath =
          '${directory.path}/Rekap_Nilai_${formattedClass}_${formattedSubject}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Save file
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Open the file
      await OpenFile.open(filePath);

      SnackBarUtils.showSuccess(
        // ignore: use_build_context_synchronously
        context,
        languageProvider.getTranslatedText({
          'en': 'Grade Rekap exported successfully',
          'id': 'Rekap nilai berhasil diexport',
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
}
