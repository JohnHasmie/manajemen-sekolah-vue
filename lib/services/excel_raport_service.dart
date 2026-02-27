import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ExcelRaportService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<void> exportRaportToExcel({
    required String classId,
    required String academicYearId,
    required String semesterId,
    required String className,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final headers = await ApiService.getHeaders();

      final url = Uri.parse('$baseUrl/raports/export').replace(
        queryParameters: {
          'class_id': classId,
          'academic_year_id': academicYearId,
          'semester_id': semesterId,
        },
      );

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        // Get directory
        final Directory directory = await getApplicationDocumentsDirectory();

        String formattedClass = className.replaceAll(
          RegExp(r'[^a-zA-Z0-9]'),
          '_',
        );
        final String filePath =
            '${directory.path}/Raport_${formattedClass}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Save file
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Open the file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Raport exported successfully',
                'id': 'Raport berhasil diexport',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String errorMessage = 'Failed to export data';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
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
}
